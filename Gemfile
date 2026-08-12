source "https://rubygems.org"

ruby "3.3.7"

gem "rails", "~> 8.1.3", ">= 8.1.3.1"
gem "propshaft"
gem "sqlite3", ">= 2.5"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "bootsnap", require: false
gem "thruster", require: false

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "brakeman", require: false
  gem "bundler-audit", require: false
  gem "rubocop-rails-omakase", require: false
  gem "overcommit", require: true
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end

gem "redcarpet"
gem "front_matter_parser"
gem "rouge"
gem "sass-rails"

gem "tailwindcss-rails", "~> 4.0"

gem "json_schemer", "~> 2.5"
