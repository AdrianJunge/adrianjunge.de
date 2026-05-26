#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$APP_ROOT"

SKIP_PULL=0
SKIP_AUDIT=0
REQUIRED_RUBY=""
USE_RBENV=0

usage() {
  cat <<EOF
Usage: scripts/update.sh [--skip-pull] [--skip-audit]

Updates the repository, installs runtime dependencies, refreshes Ruby/npm
dependencies, prepares the database, rebuilds Tailwind assets, and runs
dependency security checks.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --skip-pull)
      SKIP_PULL=1
      ;;
    --skip-audit)
      SKIP_AUDIT=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

section() {
  printf "\n== %s ==\n" "$1"
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

have() {
  command -v "$1" >/dev/null 2>&1
}

ruby_tool() {
  if [ "$USE_RBENV" -eq 1 ]; then
    RBENV_VERSION="$REQUIRED_RUBY" rbenv exec "$@"
  else
    "$@"
  fi
}

ruby_script() {
  if [ "$USE_RBENV" -eq 1 ]; then
    RBENV_VERSION="$REQUIRED_RUBY" rbenv exec ruby "$@"
  else
    ruby "$@"
  fi
}

load_homebrew() {
  if have brew; then
    eval "$(brew shellenv)"
  elif [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  elif [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

ensure_ruby() {
  local actual_ruby bundler_version

  REQUIRED_RUBY="$(tr -d '[:space:]' < .ruby-version)"

  if have rbenv; then
    USE_RBENV=1
    export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH"
    eval "$(rbenv init - bash)"

    if rbenv commands | grep -qx "install"; then
      rbenv install -s "$REQUIRED_RUBY"
    fi

    export RBENV_VERSION="$REQUIRED_RUBY"
    rbenv rehash
  fi

  actual_ruby="$(ruby_tool ruby -e 'print RUBY_VERSION' 2>/dev/null || true)"
  if [ "$actual_ruby" != "$REQUIRED_RUBY" ]; then
    die "Ruby $REQUIRED_RUBY is required, but active Ruby is ${actual_ruby:-missing}. Run scripts/install_necessary.sh or install it with rbenv."
  fi

  bundler_version="$(awk '/BUNDLED WITH/{getline; gsub(/^[ \t]+|[ \t]+$/, ""); print; exit}' Gemfile.lock)"
  ruby_tool gem install bundler -v "$bundler_version" --no-document
  rbenv rehash 2>/dev/null || true
}

ensure_node() {
  local node_major

  node_major="$(node -p 'Number(process.versions.node.split(".")[0])' 2>/dev/null || echo 0)"

  if [ "$node_major" -lt 20 ]; then
    if have brew; then
      section "Installing Node 20+"
      if brew list node >/dev/null 2>&1; then
        brew upgrade node
      else
        brew install node
      fi
      load_homebrew
      node_major="$(node -p 'Number(process.versions.node.split(".")[0])' 2>/dev/null || echo 0)"
    fi
  fi

  if [ "$node_major" -lt 20 ]; then
    die "Node >=20 is required for the current Tailwind dependencies. Install Node 20+ and rerun this script."
  fi

  have npm || die "npm is required but was not found."
}

pull_latest_code() {
  local branch

  if [ "$SKIP_PULL" -eq 1 ]; then
    echo "Skipping git pull."
    return
  fi

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not in a git worktree; skipping git pull."
    return
  fi

  branch="$(git branch --show-current)"
  if [ -n "$branch" ]; then
    git pull --ff-only --autostash origin "$branch"
  else
    git pull --ff-only --autostash
  fi
}

section "Loading toolchains"
load_homebrew
ensure_ruby
ensure_node

section "Updating repository"
pull_latest_code

section "Updating Ruby gems"
ruby_tool bundle install
ruby_tool bundle update

section "Updating npm packages"
npm install
npm update

section "Preparing database"
ruby_script bin/rails db:prepare

section "Rebuilding Tailwind assets"
ruby_script bin/rails tailwindcss:build

if [ "$SKIP_AUDIT" -eq 0 ]; then
  section "Running security checks"
  ruby_tool bundle exec bundler-audit check --update
  ruby_script bin/importmap audit
  npm audit --audit-level=high
fi

section "Done"
