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

trap 'cleanup_ui' EXIT
trap 'cleanup_ui; echo; warn "Stopped. Run ./setup.sh again to continue where you left off."; exit 130' INT

banner() {
  animated_banner
  note "Repo: $REPO_DIR"
}

run_step() {
  local id="$1"
  if ! declare -F "step_$id" >/dev/null; then err "Unknown step: $id"; return 1; fi
  "step_$id" || { warn "Step '$id' didn't finish. You can run it again any time."; return 1; }
}

run_all() {
  local s id label rc t0=$SECONDS recap=() n_ok=0 n_fail=0 n_skip=0
  if [ "$ASSUME_YES" != "1" ]; then
    echo
    note "Recommended choices: install all app groups, Catppuccin theme, your name/email from"
    note "config/settings.sh, and all macOS preferences. You'll only be stopped to paste keys on GitHub."
    if confirm "Use the recommended choices for everything (no more questions)?" Y; then
      ASSUME_YES=1; export ASSUME_YES
    fi
  fi
  STEP_TOTAL=${#STEPS[@]}; STEP_NUM=0
  for s in "${STEPS[@]}"; do
    id="${s%%|*}"; label="${s#*|}"
    STEP_NUM=$((STEP_NUM+1))
    if is_done "$id" && [ "$id" != "apps" ]; then
      printf '  %s✔%s %s%s %s(already done)%s\n' "$GREEN" "$RESET" "$(mini_bar "$STEP_NUM" "$STEP_TOTAL") " "$label" "$DIM" "$RESET"
      recap+=("${DIM}· $label — already done${RESET}"); n_skip=$((n_skip+1)); continue
    fi
    "step_$id"; rc=$?
    if [ $rc -eq 0 ]; then recap+=("${GREEN}✔${RESET} $label"); n_ok=$((n_ok+1))
    else recap+=("${RED}✖${RESET} $label ${DIM}— re-run: ./setup.sh $id${RESET}"); n_fail=$((n_fail+1)); fi
  done
  STEP_NUM=""; STEP_TOTAL=""
  recap+=("")
  recap+=("$(progress_bar 1 1 30)   ${GREEN}$n_ok done${RESET} · ${DIM}$n_skip skipped${RESET} · $( [ $n_fail -gt 0 ] && printf '%s%d need attention%s' "$RED" "$n_fail" "$RESET" || printf '%s0 problems%s' "$DIM" "$RESET")   ${DIM}⏱ $(fmt_secs $((SECONDS - t0)))${RESET}")
  summary_box "Setup complete" "${recap[@]}"
  echo
  if [ $n_fail -eq 0 ]; then
    printf '  🎉 %sYour Mac is ready!%s Open a new Ghostty window to see your new shell.\n' "$BOLD" "$RESET"
  else
    printf '  %sAlmost there!%s Fix the items marked ✖ and run them again.\n' "$BOLD" "$RESET"
  fi
  note "After installing new software later, run:  setup sync"
}

menu() {
  local s id label i choice mark
  while true; do
    banner
    i=1
    for s in "${STEPS[@]}"; do
      id="${s%%|*}"; label="${s#*|}"
      if is_done "$id"; then mark="${GREEN}✔${RESET}"; else mark=" "; fi
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
      a|A) run_all; echo; exit 0 ;;
      s|S) ASSUME_YES=0 run_sync; pause ;;
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
