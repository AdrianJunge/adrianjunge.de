# About
This is the code for my [website](https://adrianjunge.de).
I used **Ruby on Rails**, not because I love pain, but more to learn something new.
This website is mainly about myself and some ctf stuff.
Have fun exploring :smile:

# Installation
Just use the `install_necessary.sh` to install everything needed.

# Update
`bundle update`
`npm update`

# Dev stuff
`bundle exec overcommit --sign pre-commit`
`bundle exec overcommit --run`

# Starting
`rails server` or `bin/dev`

# Help
When you have installation problems try out
`gem update --system`
`bundle clean --force`

# Stop using precompiled assets
`bundle exec rake assets:clean` and delete all in `public/assets/*` especially `.manifest.json`

# Precompile assets
`rails assets:clobber && rails assets:precompile`

# Rebuilding project
`bundle exec rake db:migrate`

# Brakeman ignore warnings
`brakeman -I config/brakeman.ignore .`
or
exec `bundle exec brakeman -f json -o brakeman-report.json` and add the warnings to be ignored to the `config/brakeman.ignore`

# Adding js
Add entry in `/config/importmap.rb` and `/assets/config/manifest.js`

# Tailwind
## Rebuilding
`rails tailwindcss:build`
## Watchman
To use tailwindcss you need watchman. For installation simply execute:
`brew install watchman`
