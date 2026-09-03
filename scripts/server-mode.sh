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

# --- 1. Never suspend: mask every sleep target. Takes effect immediately, and
#        is what actually stops a lid-close from suspending (logind tries, hits
#        the masked target, gives up). ---
echo "==> Masking sleep targets (sudo)"
sudo systemctl mask \
  sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

# --- 2. Make lid-close / power key a clean no-op instead of a failed suspend.
#        Applied on the NEXT REBOOT. We deliberately do NOT restart
#        systemd-logind: that tears down the running graphical session. ---
echo "==> Installing logind drop-in (activates on next reboot)"
sudo install -d /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/10-server-no-sleep.conf >/dev/null <<'EOF'
# Managed by ~/scripts/server-mode.sh
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
EOF

# --- 3. Turn off Omarchy's screensaver + lock on this machine. Its lock
#        surface keeps rendering (clock, cursor) and holds the display awake,
#        which fights hypridle below. "stay-awake" only disables Omarchy's
#        Quickshell idle cycle; hypridle is untouched. Undo: omarchy toggle
#        idle allow-idle. Lock manually any time with the keybind. ---
echo "==> Disabling Omarchy screensaver + lock (omarchy toggle idle stay-awake)"
omarchy toggle idle stay-awake >/dev/null
omarchy restart shell >/dev/null 2>&1 || true

# --- 4. Display power-off on idle. Omarchy ships no idle DPMS at all, so add
#        hypridle with a display-only listener (no suspend, no lock). ---
echo "==> Ensuring hypridle is installed"
if ! command -v hypridle >/dev/null; then
  sudo pacman -S --needed --noconfirm hypridle
fi

echo "==> Writing $CONFDIR/hypridle.conf (display off after ${DPMS_TIMEOUT}s)"
mkdir -p "$CONFDIR"
cat > "$CONFDIR/hypridle.conf" <<EOF
# Managed by ~/scripts/server-mode.sh
# Display power only — no suspend/lock listeners on purpose. Omarchy's own
# screensaver/lock is disabled on this machine (step 3), so hypridle is the
# sole idle manager. Omarchy runs Hyprland in Lua mode, so dpms goes through
# hl.dsp, not the bare "dpms off" string.
general {
    ignore_dbus_inhibit = false
}

listener {
    timeout    = ${DPMS_TIMEOUT}
    on-timeout = hyprctl dispatch 'hl.dsp.dpms("off")'
    on-resume  = hyprctl dispatch 'hl.dsp.dpms("on")'
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
  * Suspend/hibernate are masked — nothing can put the box to sleep,
    lid-close included.
  * Omarchy's screensaver + lock are off; hypridle powers the display
    down after idle and restores it on input.
  * Reboot at your leisure to also silence the lid switch in logind
    (optional — suspend is already blocked either way).

Verify:
  systemctl is-enabled suspend.target             # -> masked
  pgrep -a hypridle                                # -> running
  hyprctl dispatch 'hl.dsp.dpms("off")'            # -> screen off now; move mouse to wake
EOF
