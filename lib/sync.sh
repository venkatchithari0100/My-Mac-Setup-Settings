# shellcheck shell=bash
# `setup sync` — find software installed on this Mac that isn't in the repo yet,
# ask about each one, save the answers to the repo, then offer to commit & push.

SYNC_WORK=""

sync_known_list() {
  # All "<kind> <name>" entries already in Brewfiles + ignore list
  local f line
  for f in "$REPO_DIR"/brew/*.Brewfile; do
    [ -f "$f" ] || continue
    while IFS= read -r line; do
      printf '%s %s\n' "$(item_kind "$line")" "$(item_name "$line")"
    done < <(group_items "$f")
  done
  grep -vE '^\s*(#|$)' "$REPO_DIR/config/ignore.txt" 2>/dev/null || true
  # manual apps already recorded
  sed -nE 's/^app "([^"]+)".*/app \1/p' "$REPO_DIR/config/manual-apps.txt" 2>/dev/null || true
}

is_known() { grep -qxF "$1 $2" "$SYNC_WORK/known"; }

# Ask which group a new item belongs to; prints the Brewfile path, "ignore" or "skip"
pick_group() {
  local label="$1" files=() f i ans
  for f in "$REPO_DIR"/brew/*.Brewfile; do files+=("$f"); done
  printf '\n%s+ New:%s %s\n' "$GREEN$BOLD" "$RESET" "$label" >&2
  for i in "${!files[@]}"; do
    printf '   %d) add to %s\n' "$((i+1))" "$(group_title "${files[$i]}")" >&2
  done
  printf '   i) ignore forever   s) skip for now\n' >&2
  printf '%s?%s Choice [s]: ' "$CYAN" "$RESET" >&2
  IFS= read -r ans || ans=""
  case "$ans" in
    i|I) echo ignore ;;
    ''|s|S) echo skip ;;
    *) if [ "$ans" -eq "$ans" ] 2>/dev/null && [ "$ans" -ge 1 ] && [ "$ans" -le "${#files[@]}" ]; then
         echo "${files[$((ans-1))]}"
       else echo skip; fi ;;
  esac
}

brew_desc() {  # kind name -> one-line description
  if [ "$1" = cask ]; then
    brew info --cask --json=v2 "$2" 2>/dev/null | jq -r '.casks[0].desc // empty' 2>/dev/null
  else
    brew info --json=v2 "$2" 2>/dev/null | jq -r '.formulae[0].desc // empty' 2>/dev/null
  fi
}

add_entry() {  # file kind name desc [extra]
  local f="$1" kind="$2" name="$3" desc="$4" extra="${5:-}"
  printf '%-34s # %s\n' "$kind \"$name\"$extra" "${desc:-added by setup sync}" >> "$f"
  echo "$kind $name" >> "$SYNC_WORK/known"
  ok "Added $kind \"$name\" to $(basename "$f")"
  SYNC_CHANGES=$((SYNC_CHANGES+1))
}

ignore_entry() {
  echo "$1 $2" >> "$REPO_DIR/config/ignore.txt"
  echo "$1 $2" >> "$SYNC_WORK/known"
  note "Will not ask about $1 $2 again."
  SYNC_CHANGES=$((SYNC_CHANGES+1))
}

handle_new() {  # kind name label desc [extra]
  local kind="$1" name="$2" label="$3" desc="$4" extra="${5:-}" dest
  dest="$(pick_group "$label")"
  case "$dest" in
    skip) : ;;
    ignore) ignore_entry "$kind" "$name" ;;
    *) add_entry "$dest" "$kind" "$name" "$desc" "$extra" ;;
  esac
}

# ── 1. Homebrew formulae & casks ────────────────────────────────────────
sync_brew() {
  info "Checking Homebrew packages…"
  local name desc n=0
  while IFS= read -r name <&3; do
    [ -z "$name" ] && continue
    is_known brew "$name" && continue
    n=$((n+1)); desc="$(brew_desc brew "$name")"
    handle_new brew "$name" "brew \"$name\" — ${desc:-command-line tool}" "$desc"
  done 3< <(brew leaves --installed-on-request 2>/dev/null)
  while IFS= read -r name <&3; do
    [ -z "$name" ] && continue
    is_known cask "$name" && continue
    n=$((n+1)); desc="$(brew_desc cask "$name")"
    handle_new cask "$name" "cask \"$name\" — ${desc:-app}" "$desc"
  done 3< <(brew list --cask -1 2>/dev/null)
  [ $n -eq 0 ] && ok "All Homebrew packages are already in the repo."
}

# ── 2. Apps in /Applications not installed by Homebrew ──────────────────
sync_apps() {
  info "Checking /Applications for apps installed outside Homebrew…"
  local app base bid token mas_id n=0 desc
  brew info --cask --installed --json=v2 2>/dev/null \
    | jq -r '.casks[].artifacts[]? | select(type=="object" and has("app")) | .app[] | select(type=="string")' \
    > "$SYNC_WORK/brew-apps" 2>/dev/null || : > "$SYNC_WORK/brew-apps"
  have mas && mas list 2>/dev/null > "$SYNC_WORK/mas-list" || : > "$SYNC_WORK/mas-list"

  for app in /Applications/*.app; do
    [ -d "$app" ] || continue
    base="$(basename "$app")"
    grep -qxF "$base" "$SYNC_WORK/brew-apps" && continue
    bid="$(defaults read "$app/Contents/Info" CFBundleIdentifier 2>/dev/null)"
    case "$bid" in com.apple.*) continue ;; esac
    base="${base%.app}"
    is_known app "$base" && continue

    # App Store app?
    if [ -d "$app/Contents/_MASReceipt" ]; then
      mas_id="$(grep -F " $base " "$SYNC_WORK/mas-list" | awk '{print $1}' | head -1)"
      [ -z "$mas_id" ] && mas_id="$(grep -F "$base" "$SYNC_WORK/mas-list" | awk '{print $1}' | head -1)"
      if [ -n "$mas_id" ] && ! is_known mas "$base"; then
        n=$((n+1))
        handle_new mas "$base" "App Store: $base (id $mas_id)" "Mac App Store" ", id: $mas_id"
        continue
      fi
    fi

    # Is there a Homebrew cask with a matching name?
    token="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g')"
    if [ -n "$token" ] && ! is_known cask "$token" && brew info --cask "$token" >/dev/null 2>&1; then
      n=$((n+1)); desc="$(brew_desc cask "$token")"
      handle_new cask "$token" "$base.app (installed manually; Homebrew has it as cask \"$token\") — $desc" "$desc"
      continue
    fi

    # Not installable automatically → record as a manual app
    n=$((n+1))
    printf '\n%s+ New:%s %s.app %s(%s — no Homebrew cask found)%s\n' "$GREEN$BOLD" "$RESET" "$base" "$DIM" "${bid:-unknown id}" "$RESET"
    local ans; printf '%s?%s Record it in config/manual-apps.txt? [y]es / [i]gnore forever / [s]kip: ' "$CYAN" "$RESET"
    IFS= read -r ans || ans=""
    case "$ans" in
      y|Y) printf 'app "%s"  # %s\n' "$base" "${bid:-}" >> "$REPO_DIR/config/manual-apps.txt"
           echo "app $base" >> "$SYNC_WORK/known"; ok "Recorded $base"; SYNC_CHANGES=$((SYNC_CHANGES+1)) ;;
      i|I) ignore_entry app "$base" ;;
    esac
  done
  [ $n -eq 0 ] && ok "No untracked apps in /Applications."
}

# ── 3. VS Code extensions ───────────────────────────────────────────────
sync_vscode() {
  have code || return 0
  info "Checking VS Code extensions…"
  local ext n=0
  while IFS= read -r ext <&3; do
    [ -z "$ext" ] && continue
    is_known vscode "$ext" && continue
    n=$((n+1)); handle_new vscode "$ext" "VS Code extension: $ext" "VS Code extension"
  done 3< <(code --list-extensions 2>/dev/null)
  [ $n -eq 0 ] && ok "All VS Code extensions are in the repo."
}

# ── 4. Install commands from shell history ──────────────────────────────
sync_history() {
  info "Scanning shell history for other install commands (npm -g, pipx, uv tool, cargo, curl | sh)…"
  local extra="$REPO_DIR/config/extra-installs.sh" cmd ans n=0
  { [ -f "$HOME/.zsh_history" ] && LC_ALL=C sed -E 's/^: [0-9]+:[0-9]+;//' "$HOME/.zsh_history"
    [ -f "$HOME/.bash_history" ] && cat "$HOME/.bash_history"; } 2>/dev/null \
    | LC_ALL=C grep -E '(npm (i|install|add) (-g|--global)|pnpm (add|install) -g|yarn global add|pipx install|uv tool install|cargo install|go install|gem install|curl [^|]*\| *(ba|z)?sh)' \
    | LC_ALL=C grep -vE '(brew|setup) ' \
    | sed -E 's/[[:space:]]+$//' | awk '!seen[$0]++' > "$SYNC_WORK/hist"

  while IFS= read -r cmd <&3; do
    grep -qxF "$cmd" "$extra" 2>/dev/null && continue
    grep -qxF "cmd $cmd" "$REPO_DIR/config/ignore.txt" 2>/dev/null && continue
    n=$((n+1))
    printf '\n%s+ From history:%s %s\n' "$GREEN$BOLD" "$RESET" "$cmd"
    printf '%s?%s Save to config/extra-installs.sh so new Macs run it? [y]es / [i]gnore forever / [s]kip: ' "$CYAN" "$RESET"
    IFS= read -r ans || ans=""
    case "$ans" in
      y|Y) echo "$cmd" >> "$extra"; ok "Saved."; SYNC_CHANGES=$((SYNC_CHANGES+1)) ;;
      i|I) echo "cmd $cmd" >> "$REPO_DIR/config/ignore.txt"; SYNC_CHANGES=$((SYNC_CHANGES+1)) ;;
    esac
  done 3< "$SYNC_WORK/hist"
  [ $n -eq 0 ] && ok "No new install commands in history."
}

# ── 5. Untracked dotfiles hint ──────────────────────────────────────────
sync_dotfiles_hint() {
  local f
  for f in .zshrc .zprofile .gitconfig; do
    if [ -f "$HOME/$f" ] && [ ! -L "$HOME/$f" ]; then
      warn "~/$f is a regular file, not linked to the repo. Run 'setup dotfiles' to link it (your copy is backed up)."
    fi
  done
}

sync_commit() {
  echo
  if [ -z "$(git -C "$REPO_DIR" status --porcelain 2>/dev/null)" ]; then
    ok "Repo is up to date — nothing to commit."; return 0
  fi
  info "Changes in the repo:"
  git -C "$REPO_DIR" status --short
  if confirm "Commit these changes?" Y; then
    local msg; msg="$(ask "Commit message" "sync: update from $(scutil --get ComputerName 2>/dev/null || hostname) on $(date +%Y-%m-%d)")"
    git -C "$REPO_DIR" add -A && git -C "$REPO_DIR" commit -m "$msg" && ok "Committed."
    if confirm "Push to GitHub?" Y; then
      git -C "$REPO_DIR" push && ok "Pushed. Your other Macs can now run 'setup' to get it."
    fi
  fi
}

run_sync() {
  header "Sync this Mac → repo"
  need_brew || return 1
  have jq || brew install jq
  SYNC_WORK="$(mktemp -d)"
  SYNC_CHANGES=0
  git -C "$REPO_DIR" pull --ff-only >/dev/null 2>&1 || true
  sync_known_list > "$SYNC_WORK/known"
  note "For each new item: pick a group number to save it, 'i' to ignore forever, Enter to skip."
  sync_brew
  sync_apps
  sync_vscode
  sync_history
  sync_dotfiles_hint
  rm -rf "$SYNC_WORK"
  mkdir -p "$STATE_DIR"; date +%s > "$STATE_DIR/last-sync"
  echo; ok "Sync finished — $SYNC_CHANGES change(s) saved to the repo."
  sync_commit
}
