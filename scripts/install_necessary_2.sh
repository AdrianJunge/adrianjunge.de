#!/bin/bash

brew install watchman
brew install foreman

bundle install

gem install overcommit
gem install rails
gem install bundler

bundle exec overcommit --install

./update.sh

echo "[*] All necessary dependencies have been installed and the project is up to date."
echo "[*] Please restart your terminal to apply the changes and then execute bin/dev to start the development server."
