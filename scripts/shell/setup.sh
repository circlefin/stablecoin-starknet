# Copyright 2025 Circle Internet Group, Inc. All rights reserved.
# 
# SPDX-License-Identifier: Apache-2.0
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#!/bin/bash

set -e

OS="$(uname -s)"
ARCH="$(uname -m)"
echo "Detected OS: $OS, Architecture: $ARCH"

log() {
  echo -e "\033[1;32m$1\033[0m"
}

install_rust() {
  log "Installing Rust..."
  if ! command -v rustc &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    log "Rust installed successfully"
  else
    log "Rust already installed: $(rustc --version)"
  fi
}

install_ubuntu_environment() {
  log "Ubuntu environment setup"

  sudo apt-get update
  sudo apt install -y curl git build-essential

  log "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.profile
  source ~/.profile

  if ! command -v asdf &> /dev/null; then
    log "Installing asdf..."
    brew install asdf
    echo '. "$(brew --prefix asdf)/libexec/asdf.sh"' >> ~/.bashrc
    source ~/.bashrc
  fi

  asdf plugin add scarb
  asdf plugin add starknet-foundry
  asdf plugin add starknet-devnet
  asdf install

  curl -L https://raw.githubusercontent.com/software-mansion/universal-sierra-compiler/master/scripts/install.sh | sh
}

install_mac_environment() {
  log "macOS detected — using starkup for setup"
  brew install asdf lcov
  asdf plugin add scarb
  asdf plugin add starknet-devnet
  asdf plugin add starknet-foundry
  asdf install

  curl -L https://raw.githubusercontent.com/software-mansion/universal-sierra-compiler/master/scripts/install.sh | sh
  
  echo "Done! Restart your shell or run: source ~/.zshrc"
}

# Main branching logic
if [[ "$OS" == "Darwin" ]]; then
  install_mac_environment
elif [[ "$OS" == "Linux" ]]; then
  install_ubuntu_environment
else
  echo "Unsupported OS: $OS"
  exit 1
fi

# Install Rust on all platforms
install_rust

log "Starknet environment setup complete!"

