#!/usr/bin/env bash
set -euo pipefail

app_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$app_root"

pull_code=false
for argument in "$@"; do
  case "$argument" in
    --pull) pull_code=true ;;
    --skip-pull) pull_code=false ;;
    -h|--help)
      printf '%s\n' 'Usage: scripts/update.sh [--pull]' \
        'Installs locked dependencies and builds development CSS.' \
        '--pull explicitly fast-forwards a clean branch from its configured upstream.' \
        'Dependency version upgrades are a separate reviewed workflow; see README.md.'
      exit 0 ;;
    *) printf 'Unknown option: %s\n' "$argument" >&2; exit 2 ;;
  esac
done

if "$pull_code"; then
  if [[ -n "$(git status --porcelain)" ]]; then
    printf '%s\n' 'Refusing to pull into a dirty worktree. Commit or preserve changes explicitly first.' >&2
    exit 1
  fi
  git pull --ff-only
fi

# bin/setup checks the versions from the newly updated working tree.
exec "$app_root/bin/setup" --skip-server
