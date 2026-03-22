#!/bin/bash
git pull origin main
bundle update
npm update

bundle exec rake db:migrate
