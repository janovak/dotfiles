# dotfiles

Personal config for an [Omarchy](https://omarchy.org/) (Arch + Hyprland) setup, tracked in a bare repo at `~/.dotfiles`.

## New machine

```sh
git clone --bare git@github.com:janovak/dotfiles.git ~/.dotfiles
alias dot='git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
dot checkout
dot config status.showUntrackedFiles no
```

## Everyday use

```sh
dot add ~/.config/hypr/bindings.lua
dot commit -m "message"
dot push
```

The first commit is the untouched Omarchy templates; everything after it is my own changes, so `dot diff <first-commit> HEAD` shows exactly what I've customized.
