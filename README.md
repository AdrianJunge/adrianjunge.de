# adrianjunge.de

Source for [my website](https://adrianjunge.de): Rails-rendered pages, repository-authored Markdown/JSON, and small JavaScript modules loaded with importmaps. The asset engine is Propshaft; the standalone Tailwind compiler provided by `tailwindcss-rails` builds all site CSS. Node packages are development/authoring tools and are excluded from production.

## Development

Install the Ruby version in [.ruby-version](.ruby-version) with your preferred version manager, Bundler matching `Gemfile.lock`, and Node 24 LTS/npm. Chrome is required for browser/accessibility/performance checks. Native gems may require a C compiler and standard Ruby development libraries. The scripts do not install global Ruby/Rails/Homebrew tools, edit shell profiles, or change version-manager defaults.

```bash
bin/setup --skip-server
bin/dev
bin/update                 # Upgrade/install all project dependencies, rebuild assets, run checks
```

`bin/setup` verifies the active toolchain, installs **locked** gems/npm packages, and builds CSS. Repeating it must not upgrade dependencies or change lockfiles. Omit `--skip-server` to also start development. `bin/dev` resolves the repository directory, builds CSS once, and starts Rails; Puma's development-only Tailwind plugin manages the watcher. Watchman and Foreman are unnecessary. `PORT=3001 bin/dev` selects another port. Site content is file-backed; no database is required.

`bin/update` upgrades gems within `Gemfile` constraints, npm tools, MathJax pins, and Pillow; installs Playwright browsers; regenerates image exports and CSS; and runs `bin/check`. It updates manifests/lockfiles and uses `.venv-images` for Python tools (requires Python 3.12+ with venv support; `IMAGE_PYTHON` selects its initial interpreter). Ruby, Node, Python, OS libraries, and DejaVu Sans fonts must already be installed (`IMAGE_FONT_DIR` overrides the Linux font directory).

## Checks and assets

```bash
bin/rails content:validate
bin/rails tailwindcss:build
bin/check                  # Ruby lint, whitespace, JavaScript, content and Rails tests
npx playwright install --with-deps chromium firefox webkit
bin/check browser          # Chrome and accessibility checks
bin/check cross-browser    # Firefox and WebKit
bin/check mobile           # Chromium/WebKit touch and viewport checks
bin/check performance      # Production build, budgets and screenshots
bin/check --help           # All modes, including images and dependency audits
RAILS_ENV=test bin/rails runner scripts/profile_content.rb  # Catalog timing
```

Image tooling: [scripts/images](scripts/images/README.md).

## Production

```bash
docker build --build-arg RUBY_VERSION=$(tr -d '\n' < .ruby-version) -t adrian-site:local .
scripts/container-check.sh adrian-site:local
```

## OpenPGP and Web Key Directory

After updating the **public** certificate, use GnuPG 2.2 or later to regenerate both exports, then commit the public certificate and generated files together:

```bash
ruby scripts/update_wkd.rb
ruby scripts/update_wkd.rb --check    # Also required by bin/check and CI
bundle exec ruby scripts/post_deploy_check.rb --base-url https://adrianjunge.de
```

## Useful websites
- https://www.magnific.com/search?format=search&iconType=standard&last_filter=query&last_value=web+security+3d&query=web+security+3d&type=icon#uuid=54ee002c-935c-4814-a015-fc1f2278474c
- https://www.remove.bg/
- https://www.svgrepo.com/

## Latex to Markdown find and replace
- `\\textit\{([^}]+)\}` => `**$1**`
- `\\command\{([^}]+)\}` => `$1`
- `\\href\{([^}]+)\}\{([^}]+)\}` => `[$2]($1)`
- `\` => ``
