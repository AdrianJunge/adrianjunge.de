# Optional MathJax dependencies

`package.json` is the source of the exact CDN versions for MathJax and its New
Computer Modern font. `MathjaxDependencies` reads it directly; article markup
supplies the URLs to the existing lazy loader. Pages without equations make no
MathJax CDN requests. Loading or font failures retain the readable TeX source and
reload control.

Dependabot tracks this directory as npm and groups the renderer/font updates.
The lockfile records the same resolved packages for auditing; these packages are
not added to the main browser bundle or installed by the Rails application.

For a manual update, change the exact release versions and run:

```sh
npm install --package-lock-only --ignore-scripts --prefix config/mathjax
npm audit --prefix config/mathjax --audit-level=high
bin/rails test test/services/mathjax_dependencies_test.rb test/controllers/mathjax_configuration_test.rb
node --test test/javascript/mathjax_loader_test.mjs
```

Restart a running development server after changing this inventory. Validate
successful typesetting and CDN failure recovery in the browser suite before
merging renderer/font updates. Serving the packages locally remains optional;
this change retains the existing CDN and failure behavior.
