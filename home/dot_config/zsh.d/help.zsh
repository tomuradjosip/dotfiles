help() {
  # Display all custom aliases and functions (only those prefixed with 'function') from sourced zsh.d files
  local zshrc="$HOME/.zshrc"
  local zshd_dir="$HOME/.config/zsh.d"

  # Colors
  local cyan='\033[36m'
  local yellow='\033[33m'
  local dim='\033[2m'
  local reset='\033[0m'

  # Find all sourced zsh.d files from .zshrc
  local sourced_files=()
  while IFS= read -r line; do
    # Match: source ~/.config/zsh.d/filename or source $HOME/.config/zsh.d/filename
    if [[ $line =~ 'source[[:space:]]+(~|\$HOME)/.config/zsh.d/([^[:space:]]+)' ]]; then
      sourced_files+=("$zshd_dir/${match[2]}")
    fi
  done < "$zshrc"

  echo ""
  echo "${cyan}Custom Aliases & Functions${reset}"
  echo "${cyan}──────────────────────────${reset}"

  for file in "${sourced_files[@]}"; do
    [[ -f "$file" ]] || continue

    # Use filename (without .zsh) as category, prettify it
    local category="${file:t:r}"
    category="${category//_/ }"                        # Replace underscores with spaces
    category="${(C)category}"                          # Capitalize words
    category="${category/Aws/AWS}"                     # Fix AWS acronym
    local prev_comment=""
    local -A items=()
    local max_name_len=0

    while IFS= read -r line; do
      # Capture comment lines (potential descriptions)
      if [[ $line =~ '^#[[:space:]]*(.*)' ]]; then
        prev_comment="${match[1]}"
        continue
      fi

      # Match function definitions with 'function' keyword only
      if [[ $line =~ '^function[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)' ]]; then
        local name="${match[1]}"
        items[$name]="$prev_comment"
        (( ${#name} > max_name_len )) && max_name_len=${#name}
        prev_comment=""
        continue
      fi

      # Match alias definitions
      if [[ $line =~ '^alias[[:space:]]+([^=]+)=' ]]; then
        local name="${match[1]}"
        items[$name]="$prev_comment"
        (( ${#name} > max_name_len )) && max_name_len=${#name}
        prev_comment=""
        continue
      fi

      # Reset comment if line is not a comment, function, or alias
      prev_comment=""
    done < "$file"

    # Print category if it has items
    if (( ${#items} > 0 )); then
      echo ""
      echo "${cyan}▸ ${category}${reset}"
      local padding=$((max_name_len + 2))
      for key in $(printf '%s\n' "${(k)items[@]}" | sort); do
        printf "  ${yellow}%-${padding}s${reset} ${dim}%s${reset}\n" "$key" "${items[$key]}"
      done
    fi
  done
  echo ""
}
