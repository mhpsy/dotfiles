#!/usr/bin/env bash
# Dotfiles install script
# Usage: ./install.sh

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing dotfiles from $DOTFILES_DIR"

# Hyprland
mkdir -p ~/.config
if [ -d ~/.config/hypr ]; then
    echo "Backing up existing ~/.config/hypr to ~/.config/hypr.bak"
    mv ~/.config/hypr ~/.config/hypr.bak
fi
cp -r "$DOTFILES_DIR/hypr" ~/.config/hypr
echo "✓ Hyprland config installed"

# Zsh
if [ -d ~/.config/zshrc ]; then
    echo "Backing up existing ~/.config/zshrc to ~/.config/zshrc.bak"
    mv ~/.config/zshrc ~/.config/zshrc.bak
fi
cp -r "$DOTFILES_DIR/zshrc" ~/.config/zshrc
echo "✓ Zsh config installed"

# p10k
cp "$DOTFILES_DIR/.p10k.zsh" ~/.p10k.zsh
echo "✓ Powerlevel10k config installed"

echo ""
echo "Done! Restart your shell or run: source ~/.zshrc"
