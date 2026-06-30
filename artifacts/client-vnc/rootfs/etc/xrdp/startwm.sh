#!/bin/sh
set -eu

unset DBUS_SESSION_BUS_ADDRESS
unset SESSION_MANAGER
unset XDG_RUNTIME_DIR

mkdir -p /tmp/.ICE-unix /tmp/.X11-unix 2>/dev/null || true
chmod 1777 /tmp/.ICE-unix /tmp/.X11-unix 2>/dev/null || true

if command -v dbus-run-session >/dev/null 2>&1; then
  exec dbus-run-session startxfce4
fi

exec startxfce4
