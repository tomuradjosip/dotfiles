#### AWS functions
# Default SSO profile - change this to your SSO profile name
AWS_SSO_PROFILE="default"

# Environment to role ARN mapping
typeset -A AWS_ROLE_ARNS
AWS_ROLE_ARNS=(
  [stage]="arn:aws:iam::617709483204:role/sre-admin"
  [prod]="arn:aws:iam::486705210074:role/sre-admin"
)


# Convert ISO timestamp to epoch
_aws_iso_to_epoch() {
  local iso=$1
  # Normalize: remove milliseconds and replace +00:00 with Z
  local normalized=$(echo "$iso" | sed -E 's/\.[0-9]+//; s/\+00:00$/Z/')
  date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$normalized" +%s 2>/dev/null
}


# Format remaining time from epoch as HH:MM:SS
_aws_format_remaining() {
  local exp_epoch=$1
  local now_epoch=$(date +%s)
  local remaining=$((exp_epoch - now_epoch))

  if [[ $remaining -le 0 ]]; then
    echo "EXPIRED"
  else
    local hours=$((remaining / 3600))
    local minutes=$(((remaining % 3600) / 60))
    local seconds=$((remaining % 60))
    printf "%02d:%02d:%02d" $hours $minutes $seconds
  fi
}


# Get SSO session expiration from cache (returns epoch)
_aws_get_sso_expiration() {
  local cache_dir=~/.aws/sso/cache
  [[ -d "$cache_dir" ]] || return

  # Find cache files with accessToken (actual sessions, not client registrations)
  for f in "$cache_dir"/*.json; do
    [[ -f "$f" ]] || continue
    # Skip files without accessToken (client registration files)
    jq -e '.accessToken' "$f" &>/dev/null || continue
    local exp_iso=$(jq -r '.expiresAt // empty' "$f" 2>/dev/null)
    [[ -n "$exp_iso" ]] || continue
    local exp_epoch=$(_aws_iso_to_epoch "$exp_iso")
    [[ -n "$exp_epoch" ]] && echo $exp_epoch && return
  done
}


# Ensure AWS SSO login is active (run independently or used by other functions)
# Usage: aws_login [profile]
aws_login() {
  local sso_profile=${1:-$AWS_SSO_PROFILE}

  # Check if we already have valid credentials
  if aws sts get-caller-identity &> /dev/null; then
    export AWS_SSO_EXPIRATION=$(_aws_get_sso_expiration)
    if [[ -n "$AWS_SSO_EXPIRATION" ]]; then
      echo "Already logged in. SSO session valid for: $(_aws_format_remaining "$AWS_SSO_EXPIRATION")"
    else
      echo "Already logged in"
    fi
    return 0
  fi

  # Need to login
  echo "Logging in to AWS SSO (profile: $sso_profile)..."
  aws sso login --profile "$sso_profile"

  # Verify login succeeded
  if ! aws sts get-caller-identity --profile "$sso_profile" &> /dev/null; then
    echo "Login failed"
    return 1
  fi

  # Login successful
  export AWS_PROFILE="$sso_profile"
  export AWS_SSO_EXPIRATION=$(_aws_get_sso_expiration)
  if [[ -n "$AWS_SSO_EXPIRATION" ]]; then
    echo "Login successful. Session valid for: $(_aws_format_remaining "$AWS_SSO_EXPIRATION")"
  else
    echo "Login successful"
  fi
}


# Clear all AWS credentials and SSO cache
# Usage: aws_logout
aws_logout() {
  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE AWS_DEFAULT_REGION AWS_CREDENTIAL_EXPIRATION AWS_SSO_EXPIRATION AWS_ASSUMED_ROLE_ARN
  setopt localoptions rmstarsilent
  rm -rf ~/.aws/sso/cache/* 2>/dev/null
  rm -rf ~/.aws/cli/cache/* 2>/dev/null
  echo "AWS credentials cleared"
}


# Assume an AWS role by environment name (idempotent)
# Usage: aws_assume <stage|prod>
aws_assume() {
  local env=$1

  if [[ -z "$env" ]]; then
    echo "Usage: aws_assume <stage|prod>"
    echo "Available environments: ${(k)AWS_ROLE_ARNS}"
    return 1
  fi

  local role_arn=${AWS_ROLE_ARNS[$env]}
  if [[ -z "$role_arn" ]]; then
    echo "Unknown environment: $env"
    echo "Available environments: ${(k)AWS_ROLE_ARNS}"
    return 1
  fi

  # Check if SSO session is valid
  if [[ -n "$AWS_SSO_EXPIRATION" ]]; then
    local now_epoch=$(date +%s)
    if [[ $AWS_SSO_EXPIRATION -gt $now_epoch ]]; then
      echo "Already logged in. SSO session valid for: $(_aws_format_remaining "$AWS_SSO_EXPIRATION")"
    else
      aws_login || return 1
    fi
  else
    aws_login || return 1
  fi

  # Check if already assumed the correct role with valid credentials
  if [[ "$AWS_ASSUMED_ROLE_ARN" == "$role_arn" && -n "$AWS_CREDENTIAL_EXPIRATION" ]]; then
    local now_epoch=$(date +%s)
    if [[ $AWS_CREDENTIAL_EXPIRATION -gt $now_epoch ]]; then
      echo "Assumed role: $AWS_ASSUMED_ROLE_ARN"
      echo "Already assumed role. Credentials valid for: $(_aws_format_remaining "$AWS_CREDENTIAL_EXPIRATION")"
      unset AWS_PROFILE
      return 0
    fi
  fi

  local sso_profile=${AWS_PROFILE:-$AWS_SSO_PROFILE}
  local temp_file=/tmp/assume_role.json

  echo "Assuming role: $role_arn"
  if ! aws sts assume-role --profile "$sso_profile" --role-arn "$role_arn" --role-session-name "iterm-session" > "$temp_file" 2>&1; then
    echo "Failed to assume role"
    cat "$temp_file"
    rm -f "$temp_file"
    return 1
  fi

  export AWS_ACCESS_KEY_ID=$(jq -r .Credentials.AccessKeyId "$temp_file")
  export AWS_SECRET_ACCESS_KEY=$(jq -r .Credentials.SecretAccessKey "$temp_file")
  export AWS_SESSION_TOKEN=$(jq -r .Credentials.SessionToken "$temp_file")
  export AWS_ASSUMED_ROLE_ARN=$role_arn
  unset AWS_PROFILE

  local expiration_iso=$(jq -r .Credentials.Expiration "$temp_file")
  export AWS_CREDENTIAL_EXPIRATION=$(_aws_iso_to_epoch "$expiration_iso")

  echo "Successfully assumed role. Credentials valid for: $(_aws_format_remaining "$AWS_CREDENTIAL_EXPIRATION")"
  rm -f "$temp_file"
}


# Convenience aliases
alias aws_assume_content_stage="aws_assume stage"
alias aws_assume_content_prod="aws_assume prod"
