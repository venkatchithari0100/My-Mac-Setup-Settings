#!/usr/bin/env bash
# Claude Code status line: model | 5-hour usage | weekly usage | context
# Managed by My-Mac-Setup-Settings. Needs jq.
in=$(cat)

bar() {  # $1 = percent (0-100)
  local p=${1%.*} f e c
  [ -z "$p" ] && p=0
  f=$((p / 10)); [ $f -gt 10 ] && f=10; e=$((10 - f))
  if   [ "$p" -ge 80 ]; then c='\033[31m'
  elif [ "$p" -ge 50 ]; then c='\033[33m'
  else c='\033[32m'; fi
  printf "${c}%s\033[2m%s\033[0m %s%%" \
    "$(printf '█%.0s' $(seq 1 $f) | head -c $((f * 3)))" \
    "$(printf '░%.0s' $(seq 1 $e) | head -c $((e * 3)))" "$p"
}

fmt_time() {  # epoch seconds or ISO string -> HH:MM
  local t="$1"
  [ -z "$t" ] && return
  if [ "$t" -eq "$t" ] 2>/dev/null; then
    date -r "$t" +%H:%M 2>/dev/null || date -d "@$t" +%H:%M 2>/dev/null
  else
    printf '%s' "$t" | sed -E 's/.*T([0-9]{2}:[0-9]{2}).*/\1/'
  fi
}

j() { jq -r "$1 // empty" <<<"$in" 2>/dev/null; }

model=$(j '.model.display_name')
fh=$(j '.rate_limits.five_hour.used_percentage')
fhr=$(j '.rate_limits.five_hour.resets_at')
wk=$(j '.rate_limits.seven_day.used_percentage')
ctx=$(j '.context_window.used_percentage')

out="🤖 ${model:-Claude}"
if [ -n "$fh" ]; then
  out="$out │ 5h $(bar "$fh")"
  r=$(fmt_time "$fhr"); [ -n "$r" ] && out="$out ↻$r"
fi
[ -n "$wk" ]  && out="$out │ week $(bar "$wk")"
[ -n "$ctx" ] && out="$out │ ctx ${ctx%.*}%"
printf '%b\n' "$out"
exit 0
