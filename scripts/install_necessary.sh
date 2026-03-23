#!/bin/bash

RUBY_VERSION=3.3.7
CONFIG_FILES=("$HOME/.zshrc" "$HOME/.bashrc")

sudo apt install -y ruby-full
sudo apt install -y ruby-railties
sudo apt install -y rbenv
sudo apt install -y build-essential libssl-dev libreadline-dev zlib1g-dev libyaml-dev
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
rbenv install $RUBY_VERSION
rbenv global $RUBY_VERSION
rbenv rehash

sudo apt install -y build-essential procps curl file git
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

for CONFIG in "${CONFIG_FILES[@]}"; do
    if grep "eval \"\$(rbenv init -)\"" "$CONFIG" > /dev/null; then
        echo "[-] rbenv init already present in $CONFIG."
    else
        echo -e "eval \"\$(rbenv init -)\"" >> "$CONFIG"
        echo "[*] rbenv init has been added to $CONFIG."
    fi
    if grep "eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\"" "$CONFIG" > /dev/null; then
        echo "[-] Brew already present in $CONFIG."
    else
        echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "$CONFIG"
        echo "[*] Brew has been added to $CONFIG."
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
done

exec $SHELL

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
