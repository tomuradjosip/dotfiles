#### Git functions (functions are easier than aliases for commit messages)

# Add all files, commit with message
ac() {
  if [ -f .pre-commit-config.yaml ]; then pre-commit run -a; fi
  git add .
  git commit -m $1
}

# Add all files, commit with message, push
acp() {
  if [ -f .pre-commit-config.yaml ]; then pre-commit run -a; fi
  git add .
  git commit -m $1 && git push
}

# Add all files, commit with message, force push
acpf() {
  if [ -f .pre-commit-config.yaml ]; then pre-commit run -a; fi
  git add .
  git commit -m $1 && git push --force-with-lease --force-if-includes
}

# Add all files, commit with message, push a new branch
acpn() {
  if [ -f .pre-commit-config.yaml ]; then pre-commit run -a; fi
  git add .
  git commit -m $1 && git push --set-upstream origin $(git branch --show-current)
}
