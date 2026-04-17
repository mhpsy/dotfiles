# 🐧 mhpsy's Dotfiles

My personal configuration files for Neovim, Kitty, Hyprland, and Rime. Managed by OpenClaw.

## 📂 Included Configurations

- **Neovim**: LazyVim based IDE-like configuration.
- **Kitty**: GPU-accelerated terminal with custom color schemes.
- **Hyprland**: Tiling Wayland compositor setup including wallpapers and scripts.
- **Rime (fcitx5)**: Rime Ice (雾凇拼音) configuration for a smooth Chinese typing experience.

## 🚀 Installation & Deployment

This repository uses **Symbolic Links** to manage configurations. This allows you to keep the repository anywhere while the system sees the files in their expected locations.

### 1. Clone the repository
```bash
git clone https://github.com/mhpsy/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

### 2. Set up Symbolic Links
Run the following commands to link the configurations to your `~/.config` and local share directories. 

**⚠️ WARNING: This will overwrite existing configurations at these paths.**

```bash
# Backup your existing configs first!
mkdir -p ~/dotfiles_backup
cp -r ~/.config/nvim ~/.config/kitty ~/.config/hypr ~/.local/share/fcitx5/rime ~/dotfiles_backup/

# Create Symbolic Links
ln -sf ~/dotfiles/nvim ~/.config/nvim
ln -sf ~/dotfiles/kitty ~/.config/kitty
ln -sf ~/dotfiles/hypr ~/.config/hypr

# Rime setup (fcitx5)
mkdir -p ~/.local/share/fcitx5
ln -sf ~/dotfiles/rime ~/.local/share/fcitx5/rime
```

### 3. Requirements
- **Terminal**: `kitty`
- **Editor**: `neovim` (>= 0.9.0)
- **WM**: `hyprland`
- **Input Method**: `fcitx5` & `fcitx5-rime`

## 🛠 Maintenance
To update your configurations across machines:
```bash
# On the machine with changes
cd ~/dotfiles
git add .
git commit -m "update: tweaks"
git push

# On other machines
cd ~/dotfiles
git pull
```

---
*Maintained with ❤️ by Shannon & OpenClaw Agent.*
