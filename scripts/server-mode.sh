#!/usr/bin/env bash
#
# server-mode.sh — turn this machine into an always-on server:
#   * never suspend / hibernate (closing the lid does nothing)
#   * the display may still power off when idle
#
# Run this only on server-like machines. Desktops just skip it.
# Idempotent: safe to re-run after an Omarchy update or a fresh checkout.
#
set -euo pipefail

DPMS_TIMEOUT=300   # seconds of idle before the display powers off
CONFDIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"

if [[ $EUID -eq 0 ]]; then
  echo "Run as your normal user, not root — the script uses sudo where it needs to." >&2
  exit 1
fi

echo "==> Masking sleep targets (sudo)"
sudo systemctl mask \
  sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

echo "==> logind: ignore lid + sleep/hibernate keys (sudo)"
sudo install -d /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/10-server-no-sleep.conf >/dev/null <<'EOF'
# Managed by ~/scripts/server-mode.sh
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
IdleAction=ignore
EOF
sudo systemctl restart systemd-logind

echo "==> Ensuring hypridle is installed (Omarchy ships no idle display-off)"
if ! command -v hypridle >/dev/null; then
  sudo pacman -S --needed --noconfirm hypridle
fi

echo "==> Writing $CONFDIR/hypridle.conf (display off after ${DPMS_TIMEOUT}s; no suspend/lock)"
mkdir -p "$CONFDIR"
cat > "$CONFDIR/hypridle.conf" <<EOF
# Managed by ~/scripts/server-mode.sh
# Display power only. No suspend/lock listeners on purpose — this is a server,
# and Omarchy's shell still handles the screensaver and lock timers.
general {
    ignore_dbus_inhibit = false
}

listener {
    timeout    = ${DPMS_TIMEOUT}
    on-timeout = hyprctl dispatch dpms off
    on-resume  = hyprctl dispatch dpms on
}
EOF

echo "==> Enabling hypridle autostart via $CONFDIR/local.lua"
cat > "$CONFDIR/local.lua" <<'EOF'
-- Machine-local Hyprland config (gitignored).
-- Managed by ~/scripts/server-mode.sh
o.launch_on_start("hypridle")
EOF

echo "==> Starting hypridle now"
pkill -x hypridle 2>/dev/null || true
if command -v uwsm-app >/dev/null; then
  setsid uwsm-app -- hypridle >/dev/null 2>&1 &
else
  setsid hypridle >/dev/null 2>&1 &
fi

cat <<'EOF'

Done.
  * Suspend/hibernate are masked — nothing can put the box to sleep.
  * The display powers off on idle and comes back on input.

Verify:
  systemctl is-enabled suspend.target           # -> masked
  systemctl show systemd-logind | grep LidSwitch # -> ignore
  pgrep -a hypridle
EOF
