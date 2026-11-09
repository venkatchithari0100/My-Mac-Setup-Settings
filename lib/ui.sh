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
  local title="$1" counter=""
  if [ -n "${STEP_NUM:-}" ] && [ -n "${STEP_TOTAL:-}" ]; then
    counter="$(mini_bar "$STEP_NUM" "$STEP_TOTAL") ${DIM}step $STEP_NUM of $STEP_TOTAL${RESET}  "
  fi
  printf '\n%s╭──%s %s%s%s\n' "$MAGENTA" "$RESET" "$BOLD" "$title" "$RESET"
  [ -n "$counter" ] && printf '%s│%s  %s\n' "$MAGENTA" "$RESET" "$counter"
  printf '%s╰─────────────────────────────────────────────────────%s\n' "$MAGENTA" "$RESET"
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


# ─────────────────────────────────────────────────────────────────────────
# Animation & progress helpers
# Set NO_ANIM=1 to turn animations off (also off automatically when not a terminal).

SPIN_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
LOG_DIR="$HOME/.config/mac-setup/logs"
LAST_LOG=""
SUDO_KEEPALIVE_PID=""

animated() { [ -t 1 ] && [ "${NO_ANIM:-0}" != "1" ]; }
cursor_hide() { animated && printf '\033[?25l'; return 0; }
cursor_show() { [ -t 1 ] && printf '\033[?25h'; return 0; }
fmt_secs() { printf '%d:%02d' $(( $1 / 60 )) $(( $1 % 60 )); }
repeat_char() { local c="$1" n="$2" out="" i=0; while [ $i -lt "$n" ]; do out="$out$c"; i=$((i+1)); done; printf '%s' "$out"; }

# progress_bar cur total [width]  ->  ▕██████░░░░▏ 60%
progress_bar() {
  local cur="$1" total="$2" w="${3:-24}" f pct
  [ "$total" -le 0 ] && total=1
  f=$(( cur * w / total )); [ $f -gt "$w" ] && f=$w
  pct=$(( cur * 100 / total ))
  printf '%s▕%s%s%s%s%s▏%s %3d%%' "$DIM" "$RESET$MAGENTA" "$(repeat_char '█' "$f")" "$RESET$DIM" "$(repeat_char '░' $((w - f)))" "$DIM" "$RESET" "$pct"
}

# mini_bar cur total  ->  ▰▰▰▱▱▱▱
mini_bar() {
  printf '%s%s%s%s%s' "$GREEN" "$(repeat_char '▰' "$1")" "$DIM" "$(repeat_char '▱' $(( $2 - $1 )))" "$RESET"
}

new_log() {
  mkdir -p "$LOG_DIR"
  LAST_LOG="$LOG_DIR/$(date +%Y%m%d-%H%M%S)-$RANDOM.log"
  : > "$LAST_LOG"
}

# Live log window: after LOG_WINDOW_AFTER seconds (default 180) a Terminal window opens and
# follows the log, so you can see what's happening. Set LOG_WINDOW_AFTER=0 to turn it off.
LOG_WINDOW_AFTER="${LOG_WINDOW_AFTER:-180}"
# Timeouts: stop a task that prints nothing new for STALL_TIMEOUT seconds, or runs longer than TASK_TIMEOUT.
STALL_TIMEOUT="${STALL_TIMEOUT:-300}"
TASK_TIMEOUT="${TASK_TIMEOUT:-1800}"
TIMED_OUT=""   # set to "stall" or "max" when spin_while kills a task

# open_log_window "title" markerfile log1 [log2 …] — window follows the logs until markerfile is removed
open_log_window() {
  local title="$1" marker="$2" cmd q; shift 2
  [ "$(uname -s)" = Darwin ] || return 0
  have open || return 0
  cmd="$(mktemp "${TMPDIR:-/tmp}/mac-setup-log.XXXXXX")"; rm -f "$cmd"; cmd="$cmd.command"
  q=""; for f in "$@"; do q="$q '$f'"; done
  cat > "$cmd" <<WIN
#!/bin/bash
printf '\033]0;📜 $title\007'
clear
printf '\033[1;35m━━━ Live log: $title ━━━\033[0m\n'
printf '\033[2mThe setup wizard is still working. You can close this window any time.\033[0m\n\n'
tail -n 40 -F $q 2>/dev/null &
T=\$!
while [ -f '$marker' ]; do sleep 1; done
sleep 1; kill \$T 2>/dev/null
printf '\n\033[1;32m✔ Finished — back to the wizard. You can close this window.\033[0m\n'
rm -f "\$0"
WIN
  chmod +x "$cmd"
  open -a Terminal "$cmd" >/dev/null 2>&1 || open "$cmd" >/dev/null 2>&1 || return 0
  printf '\r\033[K  %s↗ Taking a while — opened a live log window for %s%s\n' "$YELLOW" "$title" "$RESET"
}

# spin_while PID "label" ["prefix"] ["logfile"]  — animates until PID exits, returns its exit code.
# If a log file is given, its latest line (e.g. download progress) is shown under the spinner.
spin_while() {
  local pid="$1" label="$2" prefix="${3:-}" log="${4:-}" start=$SECONDS i=0 last="" cols marker="" opened=0
  local size=0 newsize last_change=$SECONDS draw=0
  TIMED_OUT=""
  cols=$(tput cols 2>/dev/null || echo 100)
  if [ -n "$log" ]; then marker="$log.running"; : > "$marker"; fi
  animated && { draw=1; cursor_hide; }
  while kill -0 "$pid" 2>/dev/null; do
    if [ -n "$log" ] && [ $((i % 5)) -eq 0 ]; then
      newsize=$(wc -c < "$log" 2>/dev/null | tr -d ' '); newsize=${newsize:-0}
      if [ "$newsize" != "$size" ]; then size=$newsize; last_change=$SECONDS; fi
      [ $draw -eq 1 ] && last="$(tail -c 400 "$log" 2>/dev/null | tr '\r' '\n' | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' | grep -v '^[[:space:]]*$' | tail -1 | cut -c1-$((cols - 10)))"
    fi
    # timeouts
    if [ -n "$log" ] && [ "$STALL_TIMEOUT" -gt 0 ] && [ $((SECONDS - last_change)) -ge "$STALL_TIMEOUT" ]; then
      TIMED_OUT=stall
    elif [ "$TASK_TIMEOUT" -gt 0 ] && [ $((SECONDS - start)) -ge "$TASK_TIMEOUT" ]; then
      TIMED_OUT=max
    fi
    if [ -n "$TIMED_OUT" ]; then
      pkill -P "$pid" 2>/dev/null; kill "$pid" 2>/dev/null; sleep 1; kill -9 "$pid" 2>/dev/null
      break
    fi
    if [ $draw -eq 1 ]; then
      if [ $opened -eq 0 ] && [ -n "$log" ] && [ "$LOG_WINDOW_AFTER" -gt 0 ] && [ $((SECONDS - start)) -ge "$LOG_WINDOW_AFTER" ]; then
        opened=1; printf '\n\033[K\033[1A'; open_log_window "$label" "$marker" "$log"
      fi
      local idle=$((SECONDS - last_change)) warn_txt=""
      [ -n "$log" ] && [ $idle -ge 60 ] && warn_txt=" ${YELLOW}(no output for $(fmt_secs $idle) — stops at $(fmt_secs "$STALL_TIMEOUT"))${RESET}"
      printf '\r\033[K  %s%s%s %s%s %s%s%s%s' "$CYAN" "${SPIN_FRAMES[$((i % 10))]}" "$RESET" "$prefix" "$label" "$DIM" "$(fmt_secs $((SECONDS - start)))" "$RESET" "$warn_txt"
      [ -n "$log" ] && printf '\n\033[K      %s↳ %s%s\033[1A' "$DIM" "${last:-starting…}" "$RESET"
    fi
    i=$((i+1)); sleep 0.1
  done
  if [ $draw -eq 1 ]; then
    printf '\r\033[K'
    [ -n "$log" ] && printf '\n\033[K\033[1A'
    cursor_show
  fi
  [ -n "$marker" ] && rm -f "$marker"
  if [ -n "$TIMED_OUT" ]; then
    wait "$pid" 2>/dev/null
    if [ -n "$log" ]; then
      if [ "$TIMED_OUT" = stall ]; then
        echo "TIMEOUT: no output for $(fmt_secs "$STALL_TIMEOUT") — stopped. Possibly waiting on a hidden macOS pop-up (App Management / password)." >> "$log"
      else
        echo "TIMEOUT: ran longer than $(fmt_secs "$TASK_TIMEOUT") — stopped." >> "$log"
      fi
    fi
    return 124
  fi
  wait "$pid"
}

# run_task "label" command args…  — runs quietly with a spinner, shows ✔/✖, prints the error tail on failure
run_task() {
  local label="$1" start=$SECONDS rc pid; shift
  new_log
  animated || printf '  … %s\n' "$label"
  "$@" > "$LAST_LOG" 2>&1 < /dev/null &
  pid=$!
  spin_while "$pid" "$label" "" "$LAST_LOG"; rc=$?
  if [ $rc -eq 0 ]; then
    printf '  %s✔%s %s %s(%s)%s\n' "$GREEN" "$RESET" "$label" "$DIM" "$(fmt_secs $((SECONDS - start)))" "$RESET"
  else
    printf '  %s✖%s %s\n' "$RED" "$RESET" "$label"
    tail -n 6 "$LAST_LOG" | sed "s/^/      ${DIM}│${RESET} /"
    note "Full log: $LAST_LOG"
  fi
  return $rc
}

# Ask for the Mac password once and keep sudo alive while the wizard runs
sudo_keepalive() {
  [ -n "$SUDO_KEEPALIVE_PID" ] && return 0
  sudo -n true 2>/dev/null || {
    info "Some apps need admin rights. Enter your Mac password once (it won't be asked again):"
    sudo -v || return 1
  }
  ( while kill -0 "$$" 2>/dev/null; do sudo -n true 2>/dev/null; sleep 45; done ) >/dev/null 2>&1 &
  SUDO_KEEPALIVE_PID=$!
}

cleanup_ui() {
  cursor_show
  [ -n "$SUDO_KEEPALIVE_PID" ] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null
  return 0
}

# Gradient banner that draws in line by line
animated_banner() {
  local colors=(213 177 141 105 69 39) lines i=0 line
  lines=(
    "   ╭──────────────────────────────────────────────╮"
    "   │                                              │"
    "   │          🍎  My Mac Setup Wizard             │"
    "   │      apps · shell · theme · keys · sync      │"
    "   │                                              │"
    "   ╰──────────────────────────────────────────────╯"
  )
  echo
  for line in "${lines[@]}"; do
    if [ -t 1 ]; then printf '\033[1;38;5;%sm%s\033[0m\n' "${colors[$i]}" "$line"; else printf '%s\n' "$line"; fi
    i=$((i+1))
    animated && sleep 0.04
  done
}

# summary_box "title" "line" "line" …
summary_box() {
  local title="$1" l; shift
  printf '\n  %s╭─ %s%s%s %s─────────────────────────────────────────%s\n' "$MAGENTA" "$BOLD" "$title" "$RESET" "$MAGENTA" "$RESET"
  for l in "$@"; do printf '  %s│%s  %s\n' "$MAGENTA" "$RESET" "$l"; done
  printf '  %s╰──────────────────────────────────────────────────────%s\n' "$MAGENTA" "$RESET"
}
