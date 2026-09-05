# dotfiles

Personal config for an [Omarchy](https://omarchy.org/) (Arch + Hyprland) setup,
tracked in a bare repo at `~/.dotfiles` (the working tree is `$HOME`).

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

The first commit is the untouched Omarchy templates; everything after it is my
own changes, so `dot diff <first-commit> HEAD` shows exactly what I've customized.

## Server-like machines

Two scripts (on PATH via `~/.local/bin`), run independently, both idempotent:

- `never-sleep` — masks all systemd sleep targets and tells logind to ignore
  the lid, so the box can never suspend/hibernate.
- `display-idle-off` — disables Omarchy's screensaver/lock (its relaunch cycle
  fights hypridle otherwise) and installs `hypridle` so the display still
  powers off after idle.

Desktops just skip both. The machine-local files `display-idle-off` writes
(`~/.config/hypr/local.lua`, `hypridle.conf`) are gitignored.
