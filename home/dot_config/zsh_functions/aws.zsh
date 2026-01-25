#### AWS functions
# Default SSO profile for assuming roles
AWS_SSO_PROFILE="default"

# Environment configuration
# Each environment has: kops_profile, kops_state_store, kops_cluster_name, role_arn, region
typeset -A AWS_KOPS_PROFILE AWS_KOPS_STATE_STORE AWS_KOPS_CLUSTER_NAME AWS_ROLE_ARNS AWS_ENV_REGION

AWS_KOPS_PROFILE=(
  [stage]="ContentStaging"
  [prod]="ContentProduction"
)

AWS_KOPS_STATE_STORE=(
  [stage]="s3://scorealarm-staging-cluster-state"
  [prod]="s3://scorealarm-stats-production-cluster-state"
)

AWS_KOPS_CLUSTER_NAME=(
  [stage]="staging.stats.superbet.k8s.local"
  [prod]="production.stats.superbet.k8s.local"
)

AWS_ROLE_ARNS=(
  [stage]="arn:aws:iam::617709483204:role/sre-admin"
  [prod]="arn:aws:iam::486705210074:role/sre-admin"
)

AWS_ENV_REGION=(
  [stage]="eu-west-1"
  [prod]="eu-west-1"
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
  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE AWS_DEFAULT_REGION
  unset AWS_CREDENTIAL_EXPIRATION AWS_SSO_EXPIRATION AWS_ASSUMED_ROLE_ARN
  unset KOPS_STATE_STORE KOPS_CLUSTER_NAME
  unset TF_VAR_environment TF_VAR_region
  unset SIGSCI_EMAIL SIGSCI_CORP SIGSCI_TOKEN FASTLY_API_KEY FASTLY_KEY
  setopt localoptions rmstarsilent
  rm -rf ~/.aws/sso/cache/* 2>/dev/null
  rm -rf ~/.aws/cli/cache/* 2>/dev/null
  echo "AWS credentials and environment cleared"
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


# Get secret from macOS Keychain
_aws_get_secret() {
  local key=$1
  local value
  value=$(security find-generic-password -a "$USER" -s "$key" -w 2>/dev/null)
  if [[ -z "$value" ]]; then
    echo "Warning: Secret '$key' not found in Keychain" >&2
    echo "  Add it with: security add-generic-password -a \"\$USER\" -s \"$key\" -w \"your-secret-here\"" >&2
    return 1
  fi
  echo "$value"
}


# Export terraform environment variables
_aws_export_terraform_vars() {
  local env=$1
  local region=${AWS_ENV_REGION[$env]}

  # Static variables
  export TF_VAR_environment="$env"
  export TF_VAR_region="$region"
  export SIGSCI_EMAIL="josip.tomurad@happening.xyz"
  export SIGSCI_CORP="superbet"

  # Secrets from Keychain
  export SIGSCI_TOKEN=$(_aws_get_secret "SIGSCI_TOKEN")
  export FASTLY_API_KEY=$(_aws_get_secret "FASTLY_API_KEY")
  export FASTLY_KEY=$(_aws_get_secret "FASTLY_KEY")
}


# Full environment setup: kops + sre-admin role + terraform vars
# Usage: aws_env <stage|prod>
aws_env() {
  local env=$1

  if [[ -z "$env" ]]; then
    echo "Usage: aws_env <stage|prod>"
    echo "Available environments: ${(k)AWS_ROLE_ARNS}"
    return 1
  fi

  local kops_profile=${AWS_KOPS_PROFILE[$env]}
  if [[ -z "$kops_profile" ]]; then
    echo "Unknown environment: $env"
    echo "Available environments: ${(k)AWS_ROLE_ARNS}"
    return 1
  fi

  local kops_state_store=${AWS_KOPS_STATE_STORE[$env]}
  local kops_cluster_name=${AWS_KOPS_CLUSTER_NAME[$env]}
  local region=${AWS_ENV_REGION[$env]}

  echo "=== Setting up $env environment ==="
  echo ""

  # Step 1: Login with kops profile and export kubeconfig
  echo ">>> Step 1: Kops setup (profile: $kops_profile)"
  export AWS_PROFILE="$kops_profile"
  export KOPS_STATE_STORE="$kops_state_store"
  export KOPS_CLUSTER_NAME="$kops_cluster_name"

  if ! aws sts get-caller-identity &>/dev/null; then
    echo "Logging in to AWS SSO (profile: $kops_profile)..."
    aws sso login --profile "$kops_profile"
    if ! aws sts get-caller-identity --profile "$kops_profile" &>/dev/null; then
      echo "Kops SSO login failed"
      return 1
    fi
  else
    echo "Already logged in to $kops_profile"
  fi

  echo "Exporting kubeconfig..."
  if ! kops export kubeconfig --admin=24h; then
    echo "Kops export failed"
    return 1
  fi
  echo "Kops setup complete"
  echo ""

  # Step 2: Login with default profile and assume sre-admin role
  echo ">>> Step 2: Assume sre-admin role"
  unset AWS_PROFILE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
  aws_assume "$env"
  if [[ $? -ne 0 ]]; then
    return 1
  fi
  echo ""

  # Step 3: Export terraform variables
  echo ">>> Step 3: Export terraform variables"
  _aws_export_terraform_vars "$env"
  echo "TF_VAR_environment=$TF_VAR_environment"
  echo "TF_VAR_region=$TF_VAR_region"
  echo "SIGSCI_EMAIL=$SIGSCI_EMAIL"
  echo "SIGSCI_CORP=$SIGSCI_CORP"
  echo "SIGSCI_TOKEN=${SIGSCI_TOKEN:+[set]}"
  echo "FASTLY_API_KEY=${FASTLY_API_KEY:+[set]}"
  echo "FASTLY_KEY=${FASTLY_KEY:+[set]}"
  echo ""

  # Re-export kops variables (they were cleared during assume)
  export KOPS_STATE_STORE="$kops_state_store"
  export KOPS_CLUSTER_NAME="$kops_cluster_name"

  echo "=== $env environment ready ==="
}


# Convenience aliases
alias aws_assume_content_stage="aws_assume stage"
alias aws_assume_content_prod="aws_assume prod"
alias cstage="aws_env stage"
alias cprod="aws_env prod"
