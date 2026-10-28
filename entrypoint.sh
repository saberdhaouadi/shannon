#!/bin/bash
set -euo pipefail

TARGET_UID="${SHANNON_HOST_UID:-}"
TARGET_GID="${SHANNON_HOST_GID:-}"
RUN_USER=pentest

if [ "$(id -u)" -eq 0 ]; then
  # Remap only when both IDs are given, numeric, and non-root.
  if [ -n "$TARGET_UID" ] || [ -n "$TARGET_GID" ]; then
    [[ "$TARGET_UID" =~ ^[0-9]+$ && "$TARGET_GID" =~ ^[0-9]+$ ]] || {
      echo "SHANNON_HOST_UID and SHANNON_HOST_GID must both be numeric" >&2; exit 64; }
  fi

  if [ -n "$TARGET_UID" ] && [ "$TARGET_UID" != 0 ] && [ "$TARGET_GID" != 0 ]; then
    if [ "$TARGET_UID" != "$(id -u "$RUN_USER")" ] || [ "$TARGET_GID" != "$(id -g "$RUN_USER")" ]; then
      groupmod -o -g "$TARGET_GID" "$RUN_USER"      # -o tolerates collisions (e.g. GID 20)
      usermod  -o -u "$TARGET_UID" -g "$TARGET_GID" "$RUN_USER"
      mkdir -p /app/sessions /app/workspaces /tmp/.claude /tmp/.pi
      chown -R "$TARGET_UID:$TARGET_GID" /app/sessions /app/workspaces /tmp/.claude /tmp/.pi
    fi
  fi

  [ "$#" -gt 0 ] || { echo "no command given" >&2; exit 64; }

  export HOME=/tmp/pentest-home
  mkdir -p "$HOME" && chown "$RUN_USER" "$HOME"

  # Direct setuid + exec: no shell re-parsing, no PAM, signals reach the app.
  exec setpriv --reuid="$RUN_USER" --regid="$RUN_USER" --init-groups -- "$@"
fi

exec "$@"
