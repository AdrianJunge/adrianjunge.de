#!/usr/bin/env bash
set -euo pipefail

app_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
printf '%s\n' 'This compatibility entry point uses bin/setup. Install the prerequisites in README.md first.'
exec "$app_root/bin/setup" --skip-server "$@"
