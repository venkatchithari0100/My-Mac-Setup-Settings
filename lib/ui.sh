# shellcheck shell=bash
# Small UI helpers for the wizard. Written for macOS's built-in bash 3.2.

if [ -t 1 ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
  BLUE=$'\033[34m'; MAGENTA=$'\033[35m'; CYAN=$'\033[36m'
else
  BOLD=""; DIM=""; RESET=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; MAGENTA=""; CYAN=""
fi

ASSUME_YES="${ASSUME_YES:-0}"

info()  { printf '%s==>%s %s\n' "$BLUE$BOLD" "$RESET" "$*"; }
ok()    { printf '%s ✔%s %s\n'  "$GREEN" "$RESET" "$*"; }
warn()  { printf '%s !%s %s\n'  "$YELLOW" "$RESET" "$*"; }
err()   { printf '%s ✖%s %s\n'  "$RED" "$RESET" "$*" >&2; }
note()  { printf '%s   %s%s\n'  "$DIM" "$*" "$RESET"; }

header() {
  local title="$1"
  printf '\n%s━━━ %s %s%s\n' "$MAGENTA$BOLD" "$title" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$RESET"
}

# confirm "Question" [Y|N]  -> returns 0 for yes, 1 for no
confirm() {
  local q="$1" def="${2:-Y}" ans hint
  if [ "$def" = "Y" ]; then hint="[Y/n]"; else hint="[y/N]"; fi
  if [ "$ASSUME_YES" = "1" ]; then
    printf '%s?%s %s %s %s(auto: %s)%s\n' "$CYAN" "$RESET" "$q" "$hint" "$DIM" "$def" "$RESET"
    [ "$def" = "Y" ]; return
  fi
  while true; do
    printf '%s?%s %s %s ' "$CYAN" "$RESET" "$q" "$hint"
    IFS= read -r ans || ans=""
    [ -z "$ans" ] && ans="$def"
    case "$ans" in
      [Yy]|[Yy][Ee][Ss]) return 0 ;;
      [Nn]|[Nn][Oo]) return 1 ;;
      *) echo "  Please answer y or n." ;;
    esac
  done
}

# ask "Question" "default"  -> prints the answer on stdout
ask() {
  local q="$1" def="${2:-}" ans
  if [ "$ASSUME_YES" = "1" ]; then printf '%s' "$def"; return; fi
  if [ -n "$def" ]; then
    printf '%s?%s %s %s[%s]%s ' "$CYAN" "$RESET" "$q" "$DIM" "$def" "$RESET" >&2
  else
    printf '%s?%s %s ' "$CYAN" "$RESET" "$q" >&2
  fi
  IFS= read -r ans || ans=""
  [ -z "$ans" ] && ans="$def"
  printf '%s' "$ans"
}

pause() {
  [ "$ASSUME_YES" = "1" ] && return 0
  printf '%s   Press Enter to continue…%s' "$DIM" "$RESET"
  IFS= read -r _ || true
}

# Always waits, even with --yes (for steps where you must do something in the browser)
wait_for_user() {
  printf '%s   %s — press Enter when done…%s' "$YELLOW" "$1" "$RESET"
  IFS= read -r _ || true
}

# choose_one "Title" "default" option1 option2 ...  -> prints chosen option
# Uses fzf when available, otherwise a numbered list.
choose_one() {
  local title="$1" def="$2"; shift 2
  local opts=("$@") i choice
  if [ "$ASSUME_YES" = "1" ]; then printf '%s' "$def"; return; fi
  if command -v fzf >/dev/null 2>&1; then
    # put the default first so Enter picks it
    choice=$( { printf '%s\n' "$def"; for i in "${opts[@]}"; do [ "$i" != "$def" ] && printf '%s\n' "$i"; done; } \
      | fzf --height=50% --reverse --border --prompt="$title › " --header="Type to filter, Enter to choose, Esc for default" ) || choice=""
    [ -z "$choice" ] && choice="$def"
    printf '%s' "$choice"; return
  fi
  echo "$title" >&2
  for i in "${!opts[@]}"; do
    if [ "${opts[$i]}" = "$def" ]; then
      printf '  %s%2d) %s  (default)%s\n' "$GREEN" "$((i+1))" "${opts[$i]}" "$RESET" >&2
    else
      printf '  %2d) %s\n' "$((i+1))" "${opts[$i]}" >&2
    fi
  done
  printf '%s?%s Number [Enter = default]: ' "$CYAN" "$RESET" >&2
  IFS= read -r choice || choice=""
  if [ -n "$choice" ] && [ "$choice" -eq "$choice" ] 2>/dev/null && [ "$choice" -ge 1 ] && [ "$choice" -le "${#opts[@]}" ]; then
    printf '%s' "${opts[$((choice-1))]}"
  else
    printf '%s' "$def"
  fi
}

have() { command -v "$1" >/dev/null 2>&1; }

copy_to_clipboard() {
  if have pbcopy; then pbcopy; ok "Copied to clipboard."; else cat >/dev/null; fi
}

open_url() {
  if have open; then open "$1" >/dev/null 2>&1 || true; fi
  note "If no browser opened, go to: $1"
}
