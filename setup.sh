#!/bin/bash
# My Mac Setup Wizard
#   ./setup.sh            interactive menu
#   ./setup.sh all        run every step in order (asks before each)
#   ./setup.sh sync       find newly installed software and save it to this repo
#   ./setup.sh <step>     run one step (xcode, homebrew, apps, dotfiles, theme,
#                         git, ssh, gpg, claude, macos, projects)
#   add --yes to accept all defaults without asking

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_DIR

for a in "$@"; do [ "$a" = "--yes" ] || [ "$a" = "-y" ] && export ASSUME_YES=1; done

# shellcheck source=config/settings.sh
. "$REPO_DIR/config/settings.sh"
# shellcheck source=lib/ui.sh
. "$REPO_DIR/lib/ui.sh"
# shellcheck source=lib/steps.sh
. "$REPO_DIR/lib/steps.sh"
# shellcheck source=lib/sync.sh
. "$REPO_DIR/lib/sync.sh"

if [ "$(uname -s)" != "Darwin" ]; then
  err "This wizard is for macOS."; exit 1
fi
brew_env

banner() {
  printf '%s' "$MAGENTA$BOLD"
  cat <<'ART'

   ╭──────────────────────────────────────────╮
   │        🍎  My Mac Setup Wizard           │
   ╰──────────────────────────────────────────╯
ART
  printf '%s' "$RESET"
  note "Repo: $REPO_DIR"
}

run_step() {
  local id="$1"
  if ! declare -F "step_$id" >/dev/null; then err "Unknown step: $id"; return 1; fi
  "step_$id" || warn "Step '$id' didn't finish. You can run it again any time."
}

run_all() {
  local s id label
  if [ "$ASSUME_YES" != "1" ]; then
    echo
    note "Recommended choices: install all app groups, Catppuccin theme, your name/email from"
    note "config/settings.sh, and all macOS preferences. You'll only be stopped to paste keys on GitHub."
    if confirm "Use the recommended choices for everything (no more questions)?" Y; then
      ASSUME_YES=1; export ASSUME_YES
    fi
  fi
  info "Running every step. Finished steps are skipped. Press Ctrl+C any time to stop."
  for s in "${STEPS[@]}"; do
    id="${s%%|*}"; label="${s#*|}"
    if is_done "$id" && [ "$id" != "apps" ]; then
      ok "$label — already done (run './setup.sh $id' to redo)"; continue
    fi
    run_step "$id"
  done
  echo; ok "All done! Open a new terminal window to see your new shell."
  note "Later, after installing new software, run:  setup sync"
}

menu() {
  local s id label i choice mark
  while true; do
    banner
    i=1
    for s in "${STEPS[@]}"; do
      id="${s%%|*}"; label="${s#*|}"
      if is_done "$id"; then mark="$GREEN✔$RESET"; else mark=" "; fi
      printf '   %s %2d) %s\n' "$mark" "$i" "$label"
      i=$((i+1))
    done
    echo
    printf '      %sa)%s Run ALL steps (one question, then automatic)\n' "$BOLD" "$RESET"
    printf '      %ss)%s Sync: find new software on this Mac & save it to the repo\n' "$BOLD" "$RESET"
    printf '      %sq)%s Quit\n\n' "$BOLD" "$RESET"
    printf '%s?%s Choose: ' "$CYAN" "$RESET"
    IFS= read -r choice || exit 0
    case "$choice" in
      q|Q|"") exit 0 ;;
      a|A) run_all; pause ;;
      s|S) run_sync; pause ;;
      *)
        if [ "$choice" -eq "$choice" ] 2>/dev/null && [ "$choice" -ge 1 ] && [ "$choice" -le "${#STEPS[@]}" ]; then
          run_step "${STEPS[$((choice-1))]%%|*}"; pause
        else
          warn "Unknown choice: $choice"
        fi ;;
    esac
  done
}

cmd="${1:-menu}"
[ "$cmd" = "--yes" ] || [ "$cmd" = "-y" ] && cmd="${2:-menu}"
case "$cmd" in
  menu) menu ;;
  all) banner; run_all ;;
  sync) run_sync ;;
  help|-h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) run_step "$cmd" ;;
esac
