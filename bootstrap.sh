#!/bin/bash
# One-line setup for a brand-new Mac:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/venkatchithari0100/My-Mac-Setup-Settings/main/bootstrap.sh)"
#
# Installs Homebrew (which also installs Xcode Command Line Tools + git),
# clones this repo over HTTPS, then starts the wizard.

REPO_URL="https://github.com/venkatchithari0100/My-Mac-Setup-Settings.git"
DEST="${MAC_SETUP_DIR:-$HOME/My-Projects/My-Mac-Setup-Settings}"

if [ "$(uname -s)" != "Darwin" ]; then echo "This is for macOS only."; exit 1; fi

echo "==> My Mac Setup — bootstrap"

if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; fi

if ! command -v brew >/dev/null 2>&1; then
  echo "==> Installing Homebrew (asks for your Mac password)…"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || exit 1
  if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"
  else eval "$(/usr/local/bin/brew shellenv)"; fi
fi

if [ -d "$DEST/.git" ]; then
  echo "==> Updating $DEST"
  git -C "$DEST" pull --ff-only || echo "   (couldn't fast-forward; using the local copy)"
elif [ -e "$DEST" ]; then
  echo "!! $DEST exists but isn't a git repo. Move it away and run this again."; exit 1
else
  echo "==> Cloning setup repo to $DEST"
  mkdir -p "$(dirname "$DEST")"
  git clone "$REPO_URL" "$DEST" || exit 1
fi

chmod +x "$DEST/setup.sh"
exec "$DEST/setup.sh" "$@" </dev/tty
