#!/bin/zsh

# Convert AWS session expiration time to Unix timestamp
expiration_epoch=$(date -u -d "$AWS_SESSION_EXPIRATION" +"%s")

# Current Unix timestamp
current_epoch=$(date -u +"%s")

# Calculate the difference in seconds
remaining_seconds=$((expiration_epoch - current_epoch))

# Convert seconds to human-readable format
# Note: This conversion method is simplistic and might need adjustment based on your requirements
hours=$((remaining_seconds / 3600))
minutes=$(( (remaining_seconds % 3600) / 60 ))
seconds=$((remaining_seconds % 60))

# Get AWS profile name
profile_type=${AWS_PROFILE#*/}

if [ $remaining_seconds -le 0 ]; then
    echo "expired"
    exit 1
else
    echo $profile_type
fi
