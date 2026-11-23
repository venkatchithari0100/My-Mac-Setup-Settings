#!/usr/bin/env bash
# Claude Code status line — managed by My-Mac-Setup-Settings (needs jq)
#
#  󰚩 Opus 5.5 │  project-2  main !3 │ 5h ▰▰▱▱▱▱▱▱ 16% ⏳2h05m │ week ▰▱▱▱▱▱▱▱ 7% ↻Mon 09:00 │ ctx ▰▱▱▱▱ 4% │ +120 −30
#
# Colors follow Catppuccin Mocha: green < 50%, yellow 50–79%, red ≥ 80%.

in=$(cat)
j() { jq -r "$1 // empty" <<<"$in" 2>/dev/null; }

# ── Catppuccin Mocha (24-bit) ──────────────────────────────────────────
c() { printf '\033[38;2;%sm' "$1"; }
R=$'\033[0m'; B=$'\033[1m'
MAUVE=$(c "203;166;247"); BLUE=$(c "137;180;250"); PEACH=$(c "250;179;135")
GREEN=$(c "166;227;161"); YELLOW=$(c "249;226;175"); RED=$(c "243;139;168")
TEXT=$(c "205;214;244"); DIM=$(c "108;112;134")
SEP=" ${DIM}│${R} "

level_color() { local p=${1%.*}; [ -z "$p" ] && p=0
  if [ "$p" -ge 80 ]; then printf '%s' "$RED"; elif [ "$p" -ge 50 ]; then printf '%s' "$YELLOW"; else printf '%s' "$GREEN"; fi; }

bar() {  # bar <percent> <width>
  local p=${1%.*} w=${2:-8} f i out=""; [ -z "$p" ] && p=0
  f=$(( (p * w + 50) / 100 )); [ "$p" -gt 0 ] && [ $f -eq 0 ] && f=1; [ $f -gt "$w" ] && f=$w
  for ((i = 0; i < w; i++)); do if [ $i -lt $f ]; then out+="▰"; else out+="▱"; fi; done
  printf '%s%s%s' "$(level_color "$p")" "$out" "$R"
}

to_epoch() {  # epoch seconds or ISO-8601 -> epoch
  local t="$1"; [ -z "$t" ] && return
  if [ "$t" -eq "$t" ] 2>/dev/null; then echo "$t"; return; fi
  t="${t%%.*}"; t="${t%Z}"
  date -j -u -f "%Y-%m-%dT%H:%M:%S" "$t" +%s 2>/dev/null || date -u -d "$t" +%s 2>/dev/null
}

until_text() {  # seconds from now -> 2h05m / 12m
  local s=$(( $1 - $(date +%s) )); [ $s -lt 0 ] && s=0
  local h=$((s / 3600)) m=$(((s % 3600) / 60))
  if [ $h -gt 0 ]; then printf '%dh%02dm' $h $m; else printf '%dm' $m; fi
}

day_time() { date -r "$1" '+%a %H:%M' 2>/dev/null || date -d "@$1" '+%a %H:%M' 2>/dev/null; }

# ── Data ───────────────────────────────────────────────────────────────
model=$(j '.model.display_name')
dir=$(j '.workspace.current_dir'); [ -z "$dir" ] && dir=$(j '.cwd')
fh=$(j '.rate_limits.five_hour.used_percentage')
fhr=$(to_epoch "$(j '.rate_limits.five_hour.resets_at')")
wk=$(j '.rate_limits.seven_day.used_percentage')
wkr=$(to_epoch "$(j '.rate_limits.seven_day.resets_at')")
ctx=$(j '.context_window.used_percentage')
added=$(j '.cost.total_lines_added'); removed=$(j '.cost.total_lines_removed')

out="${MAUVE}${B}󰚩 ${model:-Claude}${R}"

# Folder + git branch with change count
if [ -n "$dir" ]; then
  out+="${SEP}${BLUE} $(basename "$dir")${R}"
  if branch=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || git -C "$dir" rev-parse --short HEAD 2>/dev/null); then
    changes=$(git -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    out+=" ${PEACH} ${branch}${R}"
    [ "${changes:-0}" -gt 0 ] && out+=" ${YELLOW}!${changes}${R}"
  fi
fi

# 5-hour session
if [ -n "$fh" ]; then
  out+="${SEP}${TEXT}5h${R} $(bar "$fh") $(level_color "$fh")${fh%.*}%${R}"
  [ -n "$fhr" ] && out+=" ${DIM}⏳$(until_text "$fhr")${R}"
fi

# Weekly
if [ -n "$wk" ]; then
  out+="${SEP}${TEXT}week${R} $(bar "$wk") $(level_color "$wk")${wk%.*}%${R}"
  [ -n "$wkr" ] && out+=" ${DIM}↻$(day_time "$wkr")${R}"
fi

# Context window (warn when it's getting full)
if [ -n "$ctx" ]; then
  out+="${SEP}${TEXT}ctx${R} $(bar "$ctx" 5) $(level_color "$ctx")${ctx%.*}%${R}"
  [ "${ctx%.*}" -ge 70 ] && out+=" ${YELLOW}⚠ /compact${R}"
fi

# Lines changed by Claude this session
if [ -n "$added$removed" ] && [ "${added:-0}${removed:-0}" != "00" ]; then
  out+="${SEP}${GREEN}+${added:-0}${R} ${RED}−${removed:-0}${R}"
fi

printf '%s\n' "$out"
exit 0
