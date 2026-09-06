# adrianjunge.de

Source for [my website](https://adrianjunge.de): Rails-rendered pages, repository-authored Markdown/JSON, and small JavaScript modules loaded with importmaps. The asset engine is Propshaft; the standalone Tailwind compiler provided by `tailwindcss-rails` builds all site CSS. Node packages are development/authoring tools and are excluded from production.

## Development

Install the Ruby version in [.ruby-version](.ruby-version) with your preferred version manager, Bundler matching `Gemfile.lock`, and Node 24 LTS/npm. Chrome is required for browser/accessibility/performance checks. Native gems may require a C compiler and standard Ruby development libraries. The scripts do not install global Ruby/Rails/Homebrew tools, edit shell profiles, or change version-manager defaults.

```bash
bin/setup --skip-server
bin/dev
```

`bin/setup` verifies the active toolchain, installs **locked** gems/npm packages, prepares the retained SQLite schema, and builds CSS. Repeating it must not upgrade dependencies or change lockfiles. Omit `--skip-server` to also start development. `bin/dev` resolves the repository directory, builds CSS once, and starts Rails; Puma's development-only Tailwind plugin manages the watcher. Watchman and Foreman are unnecessary. `PORT=3001 bin/dev` selects another port.

The old `scripts/install_necessary*.sh` names remain compatibility wrappers for `bin/setup`. `scripts/update.sh` installs the current checkout's locked dependencies. Its optional `--pull` flag explicitly fast-forwards a clean branch from its configured upstream and then checks the updated toolchain requirements. It never autostashes, upgrades dependencies, or deploys.

## Authoring content

Markdown and JSON are trusted, reviewed repository inputs. Markdown permits authored HTML; this renderer is not an untrusted upload interface. Only visible, catalogued content and downloads are public.

- **Posts:** Add Markdown under `app/assets/blog/posts` or the appropriate event in `app/assets/ctf/writeups`. Include `description` and `published` in front matter, plus `title` for writeups. Blog filenames use lowercase letters, digits and hyphens; their stems must match the key and `terminal_path` in `app/assets/blog/blogs.json`. CTF event metadata belongs in `app/assets/ctf/ctfs.json` with `writeups: /ctf/<terminal_path>`.
- **Publication:** Use boolean `hidden: true`, `draft: true` or `wip: true` to withhold Markdown; JSON publication flags must also be booleans. Hidden content is still validated. Add `has_math: true` to articles containing equations.
- **Dates and authors:** Keep `published` stable and use `updated` for edits. Supported dates include `YYYY-MM-DD`, timestamps with explicit offsets, years, and ordered year ranges. `ctf_year`/`event_year` identifies the competition separately. CTF `authors` are challenge creators; use `article_authors` for article writers other than the default Adrian Junge.
- **About records:** Edit the matching `app/assets/aboutme/*.json` collection according to its schema. Keep card/event IDs and published heading fragments stable. Give linked timeline events explicit unique IDs; otherwise IDs derive from the parent, date and title. Duplicate IDs fail validation.
- **Tags and links:** Use typed filter values such as `difficulty:medium` and `severity:medium`; repeated `tag` query parameters combine filters. Metadata links accept same-site absolute paths, fragments, or HTTP(S) URLs, but not network-relative links, credentials, other schemes or unescaped whitespace.
- **Downloads:** Store challenge archives in `content/ctf/files/<event>/<year>/<challengefiles>.zip` and writeup PDFs in `content/ctf/writeups/<event>/<year>/<challengefiles>.pdf`. The writeup's `challengefiles` and event-year metadata select them. Use the article's generated download links; never move these sources into public assets.

Preview with `bin/dev`, check the article and index/timeline entries, verify mobile navigation, and follow image/download links. Validate before publishing and run the relevant regression tests:

```bash
bin/rails content:validate
bin/rails test test/integration/production_content_contract_test.rb
```

Images and their repeatable authoring commands are documented in [scripts/images](scripts/images/README.md). Optimized exports are checked in; image generation, Pillow, and SVGO are not production build dependencies. New interface JavaScript needs an importmap entry in `config/importmap.rb`; optional feature pins should have `preload: false`. There is no Sprockets manifest.

## CSS and asset builds

Edit plain CSS in `app/assets/stylesheets` and shared Tailwind tokens/imports in `app/assets/tailwind/application.css`.

```bash
bin/rails tailwindcss:build
bin/rails 'tailwindcss:build[debug]'
```

Both build and watch generate the locked Rouge theme at `tmp/stylesheets/rouge.css` before compiling a single `app/assets/builds/tailwind.css`. `assets:precompile` invokes that same build before Propshaft fingerprints assets, then produces deterministic gzip variants of CSS, JavaScript, and SVG. Neither Node/PostCSS nor SassC is involved. The layout loads one shared stylesheet; optional terminal styling is loaded with that feature.

Only compiled CSS, published images, application JavaScript, and selected browser-ready vendored JavaScript/CSS enter the asset load path. Markdown, metadata JSON, downloadable challenge archives, CSS build inputs, tests, and authoring scripts must never be copied into public assets. Download controllers retain publication/path checks.

Use `bin/production-check` for production inspection. It creates a disposable copy containing the current tracked/untracked application changes, excludes previous builds/local secrets, builds with production bundle groups, checks eager loading, boots a loopback server, verifies routes/assets/download headers/cache policy, restarts it, and confirms assets did not change. It never replaces the working tree's `public/assets`. Successful snapshots are deleted; failed snapshots and diagnostic logs are retained with their exact paths printed.

## Verification

```bash
bundle check
npm test
bin/rails content:validate
bin/rails test
bin/rails test:system
bin/rubocop
bin/production-check --performance
```

The production check uses the active Ruby and installed locked gems; run it with the project runtime selected. Reports go to `tmp/production-check` and `tmp/performance`. Performance checks use the current standalone Lighthouse library with three fresh-browser mobile runs and resource budgets in [config/performance-budgets.json](config/performance-budgets.json). They measure direct local production HTTP delivery, separately from source size and gzip estimates. CPU-sensitive LCP/CLS values are reported rather than gated across different CI hosts. Use `PERFORMANCE_RUNS=1` for a quick local diagnostic; CI uses three runs. The script accepts only loopback URLs.

axe-core runs through the existing browser driver and remains outside production assets. Automated checks supplement manual keyboard, reduced-motion, focus, and contrast review; review incomplete results rather than calling them a pass. CI retains screenshot, accessibility, production, container, and performance diagnostics. Current automated browser support is Chrome; verify Safari/Firefox manually before claiming those browsers as tested.

Network dependency/static checks run in CI:

```bash
bin/brakeman --no-pager
bundle exec bundler-audit check --update
bin/importmap audit
npm audit --audit-level=high
```

Optional Overcommit hooks run Ruby lint, changed JavaScript tests, whitespace, and file-size checks; full browser suites and network audits stay in CI. Install/sign hooks explicitly with `bundle exec overcommit --install` and `bundle exec overcommit --sign pre-commit`. No `ctags` installation is required.

## Dependency upgrades

Upgrade separately from setup and deployment. Dependabot proposes weekly reviewed updates. For a manual change, choose the affected dependency and inspect its changelog, supported runtimes, license, and resulting lockfile before running the relevant checks:

```bash
bundle update GEM_NAME --conservative
npm install --save-dev --save-exact PACKAGE_NAME@VERSION
```

Replace the uppercase placeholders with the specific package being reviewed. Keep Ruby aligned between `.ruby-version`, the lockfile, and Docker's default build argument; CI derives its Ruby version and Docker build argument from the version file. Node's CI baseline is `.node-version`. Rails 8.1 runs with deliberately retained `load_defaults 8.0`; evaluate new framework defaults separately with behavior tests.

Ruby 3.4.10 was selected as the supported normal-maintenance branch during this refactor. Ruby 4 is a separate major upgrade. SQLite/ActiveRecord and the empty migration history are retained: database removal was evaluated and deferred because no product decision requires dropping that capability. Site content and caches remain file-based; no Redis, search service, or new database is introduced.

## Production

The supported release artifact is the multi-stage Docker image:

```bash
docker build --build-arg RUBY_VERSION=$(tr -d '\n' < .ruby-version) -t adrian-site:local .
scripts/container-check.sh adrian-site:local
```

The smoke script launches only its own temporary container on a loopback port, checks non-root boot and representative pages, and downloads a published ZIP and PDF, comparing their bytes and headers with the packaged sources. It then removes that container and preserves logs. `content/ctf` is required runtime data; only `content/images` contains excluded authoring originals. `SECRET_KEY_BASE_DUMMY=1` is used only by local build/smoke checks. A real deployment must supply a persistent secret using `SECRET_KEY_BASE` or encrypted credentials/`RAILS_MASTER_KEY`; do not deploy with a dummy secret.

The build installs gems without `development:test`, compiles assets once, and omits Node, browsers, lint/test tools, image generators, libvips, and authoring originals from runtime. Rails runs as UID 1000 with writable `db`, `log`, `storage`, and `tmp`. The entrypoint prepares the retained schema; it does not compile assets or install dependencies. Thruster fronts Puma on port 80. `/up` is the container health endpoint. The plain `Procfile` starts Puma for an alternative host whose release step already ran `RAILS_ENV=production bin/rails assets:precompile`.

`PORT`, `RAILS_MAX_THREADS`, `RAILS_LOG_LEVEL`, and `PIDFILE` configure Puma/logging. Production assumes HTTPS is terminated by the trusted front proxy (`assume_ssl`/`force_ssl`); ensure that proxy enforces HTTPS and the intended host. Fingerprinted assets receive one-year immutable caching. Stable public URLs, including robots, PGP keys, and PDFs, require revalidation; feed/sitemap validators follow content changes. Confirm that an actual CDN/proxy preserves these policies during an authorized deployment review.

Workers maintain bounded process-local input snapshot and Markdown render caches. Input snapshots invalidate on source edits, replacements or deletions; deployment/restart starts a new cache. `ContentSnapshot.clear` explicitly clears input snapshots for diagnostics. Do not cache full HTML blindly because it may contain request/session data.

To roll back, rebuild the previous known-good commit with its own lockfiles and matching Ruby version. Keep that release image until the replacement has passed deployment checks. Never reuse stale assets from another checkout.
