#### Content AWS functions

# Environment configuration
typeset -A AWS_CONFIG_PROFILE AWS_KOPS_STATE_STORE AWS_KOPS_CLUSTER_NAME AWS_ROLE_ARNS

AWS_CONFIG_PROFILE=(
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


# Get secret from macOS Keychain
_get_secret() {
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


# Export kops environment variables
_export_kops_vars() {
  local env=$1
  export KOPS_STATE_STORE=${AWS_KOPS_STATE_STORE[$env]}
  export KOPS_CLUSTER_NAME=${AWS_KOPS_CLUSTER_NAME[$env]}
}


# Setup for kops commands: SSO login + assume sre-admin role
content_kops() {
  local env=$1
  local role_arn=${AWS_ROLE_ARNS[$env]}

  _export_kops_vars "$env"
  aws sso login

  local creds=$(aws sts assume-role --role-arn "$role_arn" --role-session-name "kops-session")
  export AWS_ACCESS_KEY_ID=$(echo "$creds" | jq -r .Credentials.AccessKeyId)
  export AWS_SECRET_ACCESS_KEY=$(echo "$creds" | jq -r .Credentials.SecretAccessKey)
  export AWS_SESSION_TOKEN=$(echo "$creds" | jq -r .Credentials.SessionToken)
  unset AWS_PROFILE
}


# Setup for kubectl: SSO login with profile + kops export kubeconfig
content_kubectl() {
  local env=$1
  local profile=${AWS_CONFIG_PROFILE[$env]}

  _export_kops_vars "$env"
  export AWS_PROFILE="$profile"
  aws sso login --profile "$profile"
  kops export kubeconfig --admin=24h
}


# Setup for terraform: SSO login + all env vars
content_terraform() {
  local env=$1

  _export_kops_vars "$env"

  unset AWS_PROFILE
  aws sso login

  export SIGSCI_EMAIL="josip.tomurad@happening.xyz"
  export SIGSCI_CORP="superbet"
  export SIGSCI_TOKEN=$(_get_secret "SIGSCI_TOKEN")
  export FASTLY_API_KEY=$(_get_secret "FASTLY_API_KEY")
  export FASTLY_KEY=$(_get_secret "FASTLY_KEY")
}


# Clear all AWS credentials
content_logout() {
  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE
  unset KOPS_STATE_STORE KOPS_CLUSTER_NAME
  unset SIGSCI_EMAIL SIGSCI_CORP SIGSCI_TOKEN FASTLY_API_KEY FASTLY_KEY
  rm -rf ~/.aws/sso/cache/* 2>/dev/null
  rm -rf ~/.aws/cli/cache/* 2>/dev/null
  echo "AWS credentials cleared"
}


#### Content AWS aliases

# Login to kops on Content Staging or Production
alias ckops="content_kops"
# Login to kubectl on Content Staging or Production
alias ckube="content_kubectl"
# Setup for terraform on Content Staging or Production
alias ctf="content_terraform"
# Clear all AWS credentials
alias cout="content_logout"
