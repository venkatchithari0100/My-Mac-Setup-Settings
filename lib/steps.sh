# shellcheck shell=bash
# Wizard steps. Each step is a function `step_<id>`; STEPS lists them in order.
# Every step is safe to re-run: it checks what's already done first.

STEPS=(
  "xcode|Xcode Command Line Tools"
  "homebrew|Homebrew"
  "apps|Apps & packages (pick groups / apps)"
  "dotfiles|Dotfiles: zsh, git, Ghostty, Starship (symlink into ~)"
  "theme|Theme picker: Starship preset + Ghostty colors"
  "git|Git name & email"
  "ssh|SSH key for GitHub"
  "gpg|GPG key for signed commits"
  "claude|Claude Code + usage meter status line"
  "macos|macOS preferences"
  "projects|Clone my projects"
)

STATE_DIR="$HOME/.config/mac-setup"
GITHUB_ED25519_FP="SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU"  # github.com published host key

mark_done() { mkdir -p "$STATE_DIR"; grep -qx "$1" "$STATE_DIR/done" 2>/dev/null || echo "$1" >> "$STATE_DIR/done"; }
is_done()   { grep -qx "$1" "$STATE_DIR/done" 2>/dev/null; }

brew_env() {
  if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; fi
}

need_brew() {
  brew_env
  if ! have brew; then err "Homebrew isn't installed yet. Run the Homebrew step first."; return 1; fi
}

# ─────────────────────────────────────────────────────────────────────────
step_xcode() {
  header "Xcode Command Line Tools"
  if xcode-select -p >/dev/null 2>&1; then ok "Already installed ($(xcode-select -p))."; mark_done xcode; return 0; fi
  info "Requesting install — a macOS dialog will appear. Click 'Install'."
  xcode-select --install >/dev/null 2>&1 || true
  printf '   Waiting for the install to finish'
  local i=0
  until xcode-select -p >/dev/null 2>&1; do
    sleep 5; printf '.'; i=$((i+1))
    if [ $i -gt 360 ]; then echo; err "Still not installed after 30 min. Re-run this step when done."; return 1; fi
  done
  echo; ok "Command Line Tools installed."; mark_done xcode
}

# ─────────────────────────────────────────────────────────────────────────
step_homebrew() {
  header "Homebrew"
  brew_env
  if ! have brew; then
    info "Installing Homebrew (it will ask for your Mac password)…"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || { err "Homebrew install failed."; return 1; }
    brew_env
  else
    ok "Homebrew $(brew --version | head -1 | awk '{print $2}') is installed."
  fi
  # Make brew available in new terminals even before dotfiles are linked
  if ! grep -q "brew shellenv" "$HOME/.zprofile" 2>/dev/null; then
    printf '\neval "$(%s/bin/brew shellenv)"\n' "$(brew --prefix)" >> "$HOME/.zprofile"
    ok "Added Homebrew to ~/.zprofile"
  fi
  run_task "Updating Homebrew" brew update --quiet || true
  mark_done homebrew
}

# ─────────────────────────────────────────────────────────────────────────
# Brewfile helpers
group_title() { sed -n 's/^# title: //p' "$1" | head -1; }
group_items() { grep -E '^(brew|cask|mas|vscode) ' "$1"; }
item_kind()   { printf '%s' "$1" | awk '{print $1}'; }
item_name()   { printf '%s' "$1" | sed -E 's/^[a-z]+ "([^"]+)".*/\1/'; }
item_desc()   { printf '%s' "$1" | sed -nE 's/.*# *(.*)$/\1/p'; }

step_apps() {
  header "Apps & packages"
  need_brew || return 1
  local f title items i line skip n chosen
  SELECTED=()

  # ── 1. Choose ────────────────────────────────────────────────────────
  for f in "$REPO_DIR"/brew/*.Brewfile; do
    [ -f "$f" ] || continue
    title="$(group_title "$f")"; [ -z "$title" ] && title="$(basename "$f" .Brewfile)"
    items=()
    while IFS= read -r line; do items+=("$line"); done < <(group_items "$f")
    [ ${#items[@]} -eq 0 ] && continue
    if [ "$ASSUME_YES" = "1" ]; then
      skip=""
    else
      echo
      printf '%s%s%s  %s(%s)%s\n' "$BOLD" "$title" "$RESET" "$DIM" "$(basename "$f")" "$RESET"
      for i in "${!items[@]}"; do
        line="${items[$i]}"
        printf '  %2d) %-30s %s%s%s\n' "$((i+1))" "$(item_name "$line")" "$DIM" "$(item_desc "$line")" "$RESET"
      done
      printf '%s?%s Enter = install all · numbers to SKIP (e.g. "3 7") · "n" = skip group: ' "$CYAN" "$RESET"
      IFS= read -r skip || skip=""
    fi
    case "$skip" in [Nn]|[Nn][Oo]|none) note "Skipped $title"; continue ;; esac
    skip=" $(printf '%s' "$skip" | tr ',' ' ') "
    chosen=0
    for i in "${!items[@]}"; do
      n=$((i+1))
      case "$skip" in *" $n "*) continue ;; esac
      SELECTED+=("${items[$i]}"); chosen=$((chosen+1))
    done
    ok "$title ${DIM}($chosen)${RESET}"
  done

  if [ ${#SELECTED[@]} -eq 0 ]; then note "Nothing selected."; run_extra_installs; mark_done apps; return 0; fi

  # ── 2. Install, one by one, with a live progress bar ────────────────
  local rc=0
  install_selected || rc=1
  run_extra_installs
  [ $rc -eq 0 ] && mark_done apps
  return $rc
}

# What's already on this Mac (cached once per run)
snapshot_installed() {   # writes into $INSTALLED_DIR (created by the caller)
  brew list --formula -1 > "$INSTALLED_DIR/brew" 2>/dev/null
  brew list --cask -1    > "$INSTALLED_DIR/cask" 2>/dev/null
  if have code; then code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]' > "$INSTALLED_DIR/vscode"; else : > "$INSTALLED_DIR/vscode"; fi
  if have mas; then mas list 2>/dev/null | awk '{print $1}' > "$INSTALLED_DIR/mas"; else : > "$INSTALLED_DIR/mas"; fi
}

item_mas_id() { printf '%s' "$1" | sed -nE 's/.*id: *([0-9]+).*/\1/p'; }

is_installed() {  # kind name line
  case "$1" in
    brew)   grep -qxF "$2" "$INSTALLED_DIR/brew" || grep -qxF "${2##*/}" "$INSTALLED_DIR/brew" ;;
    cask)   grep -qxF "$2" "$INSTALLED_DIR/cask" || grep -qxF "${2##*/}" "$INSTALLED_DIR/cask" ;;
    vscode) grep -qxF "$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')" "$INSTALLED_DIR/vscode" ;;
    mas)    grep -qxF "$(item_mas_id "$3")" "$INSTALLED_DIR/mas" ;;
    *) return 1 ;;
  esac
}

install_cmd() {  # kind name line [adopt]  -> runs the install
  case "$1" in
    brew)   brew install "$2" ;;
    cask)   if [ "${4:-}" = adopt ]; then brew install --cask --adopt "$2"; else brew install --cask "$2"; fi ;;
    vscode) code --install-extension "$2" --force ;;
    mas)    mas install "$(item_mas_id "$3")" ;;
  esac
}

# Short human reason from a brew log
failure_reason() {
  local r
  r="$(grep -m1 -E '^TIMEOUT:|^Error:|error:|It seems there is already|requires macOS|No available (formula|cask)|Download failed|SHA256 mismatch' "$1" 2>/dev/null | sed -E 's/^Error: //; s/^[[:space:]]+//')"
  [ -z "$r" ] && r="$(grep -v '^\s*$' "$1" | tail -1)"
  printf '%s' "$r" | cut -c1-110
}

# Download everything that's missing, PARALLEL_DOWNLOADS at a time (installs stay one-by-one,
# because Homebrew can't run two installs at once — but downloads are the slow part).
PARALLEL_DOWNLOADS="${PARALLEL_DOWNLOADS:-4}"
prefetch_missing() {
  local queue=("$@") total=$# next=0 done_n=0 fail_n=0 i=0 start=$SECONDS
  local pids=() names=() k alive kind name line active marker opened=0
  [ "$total" -eq 0 ] && return 0
  PREFETCH_STOP=0
  mkdir -p "$LOG_DIR"; rm -f "$LOG_DIR"/fetch-*.log
  marker="$LOG_DIR/.prefetch.running"; : > "$marker"
  trap 'PREFETCH_STOP=1; for k in "${pids[@]}"; do [ -n "$k" ] && kill "$k" 2>/dev/null; done' INT
  mkdir -p "$LOG_DIR"
  cursor_hide
  while [ $done_n -lt "$total" ] && [ $PREFETCH_STOP -eq 0 ]; do
    # fill free slots
    alive=0; for k in "${pids[@]}"; do [ -n "$k" ] && alive=$((alive+1)); done
    while [ $alive -lt "$PARALLEL_DOWNLOADS" ] && [ $next -lt "$total" ]; do
      line="${queue[$next]}"; kind="$(item_kind "$line")"; name="$(item_name "$line")"
      if [ "$kind" = cask ]; then brew fetch --cask "$name" > "$LOG_DIR/fetch-$name.log" 2>&1 < /dev/null &
      else brew fetch --deps "$name" > "$LOG_DIR/fetch-$name.log" 2>&1 < /dev/null & fi
      pids[$next]=$!; names[$next]="$name"; next=$((next+1)); alive=$((alive+1))
    done
    # reap finished ones
    for k in "${!pids[@]}"; do
      [ -z "${pids[$k]}" ] && continue
      if ! kill -0 "${pids[$k]}" 2>/dev/null; then
        if wait "${pids[$k]}"; then
          printf '\r\033[K  %s↓%s %-30s %sdownloaded%s\n' "$GREEN" "$RESET" "${names[$k]}" "$DIM" "$RESET"
        else
          fail_n=$((fail_n+1))
          printf '\r\033[K  %s↓%s %-30s %sdownload failed — will retry during install%s\n' "$YELLOW" "$RESET" "${names[$k]}" "$DIM" "$RESET"
        fi
        pids[$k]=""; done_n=$((done_n+1))
      fi
    done
    # long-running? open a live log window that follows all downloads
    if [ $opened -eq 0 ] && [ "$LOG_WINDOW_AFTER" -gt 0 ] && [ $((SECONDS - start)) -ge "$LOG_WINDOW_AFTER" ]; then
      opened=1; open_log_window "Downloads" "$marker" "$LOG_DIR"/fetch-*.log
    fi
    # status line
    active=""; for k in "${!pids[@]}"; do [ -n "${pids[$k]}" ] && active="$active${names[$k]}, "; done
    if animated; then
      printf '\r\033[K  %s%s%s %s %d/%d  %sdownloading %s%s %s%s%s' "$CYAN" "${SPIN_FRAMES[$((i % 10))]}" "$RESET" \
        "$(progress_bar "$done_n" "$total" 20)" "$done_n" "$total" "$DIM" "${active%, }" "$RESET" "$DIM" "$(fmt_secs $((SECONDS - start)))" "$RESET"
    fi
    i=$((i+1)); sleep 0.1
  done
  printf '\r\033[K'; cursor_show; rm -f "$marker"
  trap 'cleanup_ui; echo; warn "Stopped. Run ./setup.sh again to continue where you left off."; exit 130' INT
  if [ $PREFETCH_STOP -eq 1 ]; then
    warn "Downloads stopped — continuing with installs."
  else
    ok "Downloaded $((total - fail_n))/$total in $(fmt_secs $((SECONDS - start))) ${DIM}($PARALLEL_DOWNLOADS at a time)${RESET}"
  fi
  return 0
}

install_selected() {
  local total=${#SELECTED[@]} idx=0 line kind name pid rc start t0=$SECONDS
  local n_new=0 n_had=0 n_fail=0 n_skip=0 has_cask=0 reason
  FAILED_ITEMS=(); SKIPPED_ITEMS=()

  for line in "${SELECTED[@]}"; do [ "$(item_kind "$line")" = cask ] && has_cask=1; done
  echo
  [ $has_cask -eq 1 ] && sudo_keepalive
  export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 HOMEBREW_NO_INSTALL_CLEANUP=1
  run_task "Updating Homebrew" brew update --quiet
  INSTALLED_DIR="$(mktemp -d)"
  run_task "Checking what's already installed" snapshot_installed
  echo
  # Parallel download phase
  local missing=() l
  for l in "${SELECTED[@]}"; do
    case "$(item_kind "$l")" in brew|cask) is_installed "$(item_kind "$l")" "$(item_name "$l")" "$l" || missing+=("$l") ;; esac
  done
  if [ ${#missing[@]} -gt 1 ]; then
    info "Downloading ${#missing[@]} apps in parallel (${PARALLEL_DOWNLOADS} at a time)…"
    prefetch_missing "${missing[@]}"
    echo
  fi
  info "Installing…"
  note "Tip: press Ctrl+C to skip the app that's installing right now."
  echo
  # Ctrl+C during an install skips just that app
  ITEM_PID=""; ITEM_SKIPPED=0
  trap 'if [ -n "$ITEM_PID" ]; then ITEM_SKIPPED=1; kill "$ITEM_PID" 2>/dev/null; pkill -P "$ITEM_PID" 2>/dev/null; fi' INT

  for line in "${SELECTED[@]}"; do
    idx=$((idx+1))
    kind="$(item_kind "$line")"; name="$(item_name "$line")"
    if is_installed "$kind" "$name" "$line"; then
      n_had=$((n_had+1))
      printf '\r\033[K  %s·%s %-30s %salready installed%s\n' "$DIM" "$RESET" "$name" "$DIM" "$RESET"
      continue
    fi
    new_log; start=$SECONDS; ITEM_SKIPPED=0
    install_cmd "$kind" "$name" "$line" > "$LAST_LOG" 2>&1 < /dev/null &
    pid=$!; ITEM_PID=$pid
    spin_while "$pid" "$name" "$(progress_bar "$idx" "$total" 20) $idx/$total  " "$LAST_LOG"; rc=$?

    # App already in /Applications (installed by hand)? Keep it as-is — adopting can hang on
    # macOS's App Management permission prompt, and the app works fine either way.
    local manual=0
    if [ $ITEM_SKIPPED -eq 0 ] && [ $rc -ne 0 ] && [ "$kind" = cask ] && grep -q "already an App" "$LAST_LOG"; then
      manual=1
    fi
    ITEM_PID=""

    if [ $manual -eq 1 ]; then
      n_had=$((n_had+1))
      printf '\r\033[K  %s·%s %-30s %salready in /Applications (installed manually)%s\n' "$DIM" "$RESET" "$name" "$DIM" "$RESET"
    elif [ $ITEM_SKIPPED -eq 1 ]; then
      n_skip=$((n_skip+1)); SKIPPED_ITEMS+=("$name")
      printf '\r\033[K  %s⏭%s %-30s %sskipped (Ctrl+C)%s\n' "$YELLOW" "$RESET" "$name" "$DIM" "$RESET"
    elif [ $rc -eq 0 ]; then
      n_new=$((n_new+1))
      printf '\r\033[K  %s✔%s %-30s %sinstalled in %s%s\n' "$GREEN" "$RESET" "$name" "$DIM" "$(fmt_secs $((SECONDS - start)))" "$RESET"
    else
      n_fail=$((n_fail+1))
      reason="$(failure_reason "$LAST_LOG")"
      FAILED_ITEMS+=("$name|$reason|$LAST_LOG")
      printf '\r\033[K  %s✖%s %-30s %s%s%s\n' "$RED" "$RESET" "$name" "$YELLOW" "$reason" "$RESET"
    fi
  done
  rm -rf "$INSTALLED_DIR"
  trap 'cleanup_ui; echo; warn "Stopped. Run ./setup.sh again to continue where you left off."; exit 130' INT

  local lines=()
  lines+=("$(progress_bar "$total" "$total" 30)")
  lines+=("${GREEN}✔ $n_new installed${RESET}   ${DIM}· $n_had already installed${RESET}   $( [ $n_fail -gt 0 ] && printf '%s✖ %d failed%s' "$RED" "$n_fail" "$RESET" || printf '%s✖ 0 failed%s' "$DIM" "$RESET")$( [ $n_skip -gt 0 ] && printf '   %s⏭ %d skipped%s' "$YELLOW" "$n_skip" "$RESET")   ${DIM}⏱ $(fmt_secs $((SECONDS - t0)))${RESET}")
  summary_box "Apps" "${lines[@]}"
  if [ $n_fail -gt 0 ]; then
    local fi_ fname freason flog
    echo
    warn "These didn't install:"
    for fi_ in "${FAILED_ITEMS[@]}"; do
      fname="${fi_%%|*}"; freason="${fi_#*|}"; flog="${freason#*|}"; freason="${freason%%|*}"
      printf '    %s✖ %s%s — %s\n' "$RED" "$fname" "$RESET" "$freason"
      note "      log: $flog"
    done
    note "Fix the cause (or remove the line from brew/*.Brewfile), then run: ./setup.sh apps"
    return 1
  fi
  if [ $n_skip -gt 0 ]; then
    note "Skipped: ${SKIPPED_ITEMS[*]} — run ./setup.sh apps later to install them."
  fi
}

run_extra_installs() {
  local f="$REPO_DIR/config/extra-installs.sh" line
  [ -f "$f" ] || return 0
  grep -vE '^\s*(#|$)' "$f" >/dev/null 2>&1 || return 0
  echo
  info "Extra install commands from config/extra-installs.sh"
  while IFS= read -r line <&3; do
    case "$line" in ''|\#*) continue ;; esac
    if confirm "Run: $line" Y; then bash -c "$line" || warn "Command failed: $line"; fi
  done 3< "$f"
}

# ─────────────────────────────────────────────────────────────────────────
step_dotfiles() {
  header "Dotfiles"
  local src rel dst backup="" ts
  ts="$(date +%Y%m%d-%H%M%S)"
  info "Linking files from $REPO_DIR/dotfiles into your home folder."
  note "Existing files are moved to ~/.dotfiles-backup/$ts first. Edits you make later go straight into the repo."
  while IFS= read -r src; do
    rel="${src#"$REPO_DIR"/dotfiles/}"
    dst="$HOME/$rel"
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
      ok "$rel (already linked)"; continue
    fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then
      backup="$HOME/.dotfiles-backup/$ts"
      mkdir -p "$backup/$(dirname "$rel")"
      mv "$dst" "$backup/$rel"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    ok "$rel → linked"
  done < <(find "$REPO_DIR/dotfiles" -type f ! -name '.DS_Store' | sort)
  [ -n "$backup" ] && note "Backups saved in $backup"
  touch "$HOME/.gitconfig.local"
  note "Open a new terminal tab (or run: exec zsh) to load the new shell config."
  mark_done dotfiles
}

# ─────────────────────────────────────────────────────────────────────────
step_theme() {
  header "Theme picker"
  need_brew || return 1
  have starship || run_task "Installing Starship" brew install starship
  brew list --cask font-jetbrains-mono-nerd-font >/dev/null 2>&1 || run_task "Installing JetBrainsMono Nerd Font" brew install --cask font-jetbrains-mono-nerd-font

  # Starship preset
  local presets=() p current_preset preset
  while IFS= read -r p; do presets+=("$p"); done < <(starship preset --list)
  current_preset="${DEFAULT_STARSHIP_PRESET:-catppuccin-powerline}"
  info "Starship prompt presets (preview: https://starship.rs/presets/)"
  preset="$(choose_one "Starship preset" "$current_preset" "${presets[@]}")"
  if starship preset "$preset" --force -o "$REPO_DIR/dotfiles/.config/starship.toml" 2>/dev/null \
     || starship preset "$preset" > "$REPO_DIR/dotfiles/.config/starship.toml"; then
    ok "Starship preset: $preset (saved to the repo)"
  else
    warn "Couldn't write the Starship preset."
  fi

  # Ghostty theme
  local gbin="" themes=() t def theme cfg="$REPO_DIR/dotfiles/.config/ghostty/config" bak
  for gbin in "$(command -v ghostty 2>/dev/null)" /Applications/Ghostty.app/Contents/MacOS/ghostty; do
    [ -n "$gbin" ] && [ -x "$gbin" ] && break; gbin=""
  done
  if [ -z "$gbin" ]; then
    warn "Ghostty isn't installed yet — keeping theme '$(sed -n 's/^theme = //p' "$cfg")'. Re-run this step after installing apps."
  else
    while IFS= read -r t; do themes+=("$t"); done < <("$gbin" +list-themes --plain 2>/dev/null | sed -E 's/ \((resources|user)\)$//' | sort -u)
    case "$preset" in
      *catppuccin*) def="${DEFAULT_GHOSTTY_THEME:-Catppuccin Mocha}" ;;
      *tokyo*)      def="$(printf '%s\n' "${themes[@]}" | grep -i 'tokyo' | grep -iv 'day' | head -1)" ;;
      *gruvbox*)    def="$(printf '%s\n' "${themes[@]}" | grep -i 'gruvbox' | grep -i 'dark' | head -1)" ;;
      *)            def="$(sed -n 's/^theme = //p' "$cfg")" ;;
    esac
    [ -z "$def" ] && def="${DEFAULT_GHOSTTY_THEME:-Catppuccin Mocha}"
    if [ ${#themes[@]} -gt 0 ]; then
      theme="$(choose_one "Ghostty theme" "$def" "${themes[@]}")"
    else
      theme="$(ask "Ghostty theme name" "$def")"
    fi
    bak="$(mktemp)"; cp "$cfg" "$bak"
    sed -i '' -E "s/^theme = .*/theme = $theme/" "$cfg" 2>/dev/null || sed -i -E "s/^theme = .*/theme = $theme/" "$cfg"
    # Names picked from Ghostty's own list are valid; check typed names
    if [ ${#themes[@]} -eq 0 ] && "$gbin" +validate-config --config-file="$cfg" 2>&1 | grep -qi 'theme'; then
      cp "$bak" "$cfg"; warn "Ghostty didn't accept '$theme' — kept the previous theme."
    else
      ok "Ghostty theme: $theme (reload Ghostty with Cmd+Shift+,)"
    fi
    rm -f "$bak"
  fi
  note "Set your terminal font to 'JetBrainsMono Nerd Font' so icons render (already set for Ghostty)."
  mark_done theme
}

# ─────────────────────────────────────────────────────────────────────────
step_git() {
  header "Git identity"
  local name email
  name="$(ask "Git name" "$(git config --file "$HOME/.gitconfig.local" user.name 2>/dev/null || echo "$GIT_NAME")")"
  email="$(ask "Git email" "$(git config --file "$HOME/.gitconfig.local" user.email 2>/dev/null || echo "$GIT_EMAIL")")"
  git config --file "$HOME/.gitconfig.local" user.name "$name"
  git config --file "$HOME/.gitconfig.local" user.email "$email"
  ok "Saved to ~/.gitconfig.local:  $name <$email>"
  mark_done git
}

# ─────────────────────────────────────────────────────────────────────────
step_ssh() {
  header "SSH key for GitHub"
  local key="$HOME/.ssh/id_ed25519" email tmp fp
  mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
  email="$(git config --file "$HOME/.gitconfig.local" user.email 2>/dev/null || echo "$GIT_EMAIL")"

  if [ -f "$key" ]; then
    ok "Using existing key $key"
  else
    info "Creating a new ed25519 key (a passphrase is recommended; macOS Keychain will remember it)."
    ssh-keygen -t ed25519 -C "$email" -f "$key" || return 1
  fi

  if ! grep -q "Host github.com" "$HOME/.ssh/config" 2>/dev/null; then
    cat >> "$HOME/.ssh/config" <<CFG

Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
CFG
    chmod 600 "$HOME/.ssh/config"
    ok "Added github.com to ~/.ssh/config"
  fi
  ssh-add --apple-use-keychain "$key" 2>/dev/null || ssh-add "$key" 2>/dev/null || true

  # Trust github.com's host key only if it matches GitHub's published fingerprint
  if ! ssh-keygen -F github.com >/dev/null 2>&1; then
    tmp="$(mktemp)"
    ssh-keyscan -t ed25519 github.com 2>/dev/null > "$tmp"
    fp="$(ssh-keygen -lf "$tmp" 2>/dev/null | awk '{print $2}')"
    if [ "$fp" = "$GITHUB_ED25519_FP" ]; then
      cat "$tmp" >> "$HOME/.ssh/known_hosts"; ok "github.com host key verified and trusted."
    else
      warn "github.com fingerprint didn't match ($fp). Not trusting it automatically."
    fi
    rm -f "$tmp"
  fi

  if ssh -T -o BatchMode=yes git@github.com 2>&1 | grep -q "successfully authenticated"; then
    ok "GitHub already accepts this key."
  else
    pbcopy < "$key.pub" 2>/dev/null && ok "Public key copied to clipboard."
    info "Add it on GitHub: paste it, give it a title like '$(scutil --get ComputerName 2>/dev/null || hostname)', and Save."
    open_url "https://github.com/settings/ssh/new"
    wait_for_user "Paste the key on GitHub (Cmd+V) and click 'Add SSH key'"
    if ssh -T -o BatchMode=yes git@github.com 2>&1 | grep -q "successfully authenticated"; then
      ok "SSH to GitHub works!"
    else
      warn "GitHub didn't accept the key yet. You can re-run this step later."
      return 1
    fi
  fi

  # Switch this repo to SSH so `setup sync` can push
  if git -C "$REPO_DIR" remote get-url origin 2>/dev/null | grep -q '^https://github.com/'; then
    local url; url="$(git -C "$REPO_DIR" remote get-url origin | sed -E 's#https://github.com/#git@github.com:#')"
    git -C "$REPO_DIR" remote set-url origin "$url" && ok "Repo remote switched to SSH ($url)"
  fi
  mark_done ssh
}

# ─────────────────────────────────────────────────────────────────────────
step_gpg() {
  header "GPG commit signing"
  need_brew || return 1
  have gpg || run_task "Installing GnuPG" brew install gnupg
  have pinentry-mac || run_task "Installing pinentry-mac" brew install pinentry-mac
  local name email keyid conf="$HOME/.gnupg/gpg-agent.conf"
  name="$(git config --file "$HOME/.gitconfig.local" user.name 2>/dev/null || echo "$GIT_NAME")"
  email="$(git config --file "$HOME/.gitconfig.local" user.email 2>/dev/null || echo "$GIT_EMAIL")"

  mkdir -p "$HOME/.gnupg"; chmod 700 "$HOME/.gnupg"
  if ! grep -q "pinentry-program" "$conf" 2>/dev/null; then
    echo "pinentry-program $(brew --prefix)/bin/pinentry-mac" >> "$conf"
    gpgconf --kill gpg-agent 2>/dev/null || true
    ok "GPG will use the macOS password dialog (pinentry-mac)."
  fi

  keyid="$(gpg --list-secret-keys --keyid-format=long --with-colons "$email" 2>/dev/null | awk -F: '/^sec/{print $5; exit}')"
  if [ -n "$keyid" ]; then
    ok "Found existing key $keyid for $email"
  else
    info "Creating an RSA 4096 signing key for $name <$email> (valid 3 years)…"
    gpg --quick-generate-key "$name <$email>" rsa4096 sign 3y || return 1
    keyid="$(gpg --list-secret-keys --keyid-format=long --with-colons "$email" | awk -F: '/^sec/{print $5; exit}')"
  fi

  git config --file "$HOME/.gitconfig.local" user.signingkey "$keyid"
  git config --file "$HOME/.gitconfig.local" commit.gpgsign true
  git config --file "$HOME/.gitconfig.local" tag.gpgSign true
  git config --file "$HOME/.gitconfig.local" gpg.program "$(command -v gpg)"
  ok "Git will sign commits with $keyid"

  if confirm "Add this GPG key to GitHub now? (say n if you already did)" Y; then
    gpg --armor --export "$keyid" | pbcopy 2>/dev/null && ok "Public GPG key copied to clipboard."
    open_url "https://github.com/settings/gpg/new"
    wait_for_user "Paste the key on GitHub (Cmd+V) and click 'Add GPG key'"
  fi
  note "Back up your private key somewhere safe (NOT this repo):"
  note "  gpg --export-secret-keys --armor $keyid > ~/Desktop/gpg-private-$keyid.asc"
  mark_done gpg
}

# ─────────────────────────────────────────────────────────────────────────
step_claude() {
  header "Claude Code + usage meter"
  need_brew || return 1
  have jq || run_task "Installing jq" brew install jq
  if ! have claude; then
    run_task "Installing Claude Code" brew install --cask claude-code || return 1
  else
    ok "Claude Code is installed."
  fi
  local settings="$HOME/.claude/settings.json" tmp
  mkdir -p "$HOME/.claude"
  [ -f "$settings" ] || echo '{}' > "$settings"
  [ -L "$HOME/.claude/statusline.sh" ] || [ -f "$HOME/.claude/statusline.sh" ] || ln -s "$REPO_DIR/dotfiles/.claude/statusline.sh" "$HOME/.claude/statusline.sh"
  chmod +x "$REPO_DIR/dotfiles/.claude/statusline.sh"
  tmp="$(mktemp)"
  jq '.statusLine = {"type":"command","command":"~/.claude/statusline.sh"}' "$settings" > "$tmp" && mv "$tmp" "$settings"
  ok "Status line enabled: model │ 5h usage │ weekly usage │ context"
  note "Run 'claude' and log in with your Pro account. The usage bars appear after your first message."
  mark_done claude
}

# ─────────────────────────────────────────────────────────────────────────
step_macos() {
  header "macOS preferences"
  # shellcheck source=../macos/defaults.sh
  . "$REPO_DIR/macos/defaults.sh"
  local g fn desc mode ans
  for g in "${MACOS_GROUPS[@]}"; do note "• ${g#*|}"; done
  if [ "$ASSUME_YES" = "1" ]; then mode=all; else
    printf '%s?%s Apply all of these? [Y]es / [n]o / [c]hoose one by one: ' "$CYAN" "$RESET"
    IFS= read -r ans || ans=""
    case "$ans" in [Nn]*) mode=none ;; [Cc]*) mode=choose ;; *) mode=all ;; esac
  fi
  [ "$mode" = none ] && { note "Skipped."; mark_done macos; return 0; }
  for g in "${MACOS_GROUPS[@]}"; do
    fn="${g%%|*}"; desc="${g#*|}"
    if [ "$mode" = all ] || confirm "$desc?" Y; then "$fn" && ok "$desc"; fi
  done
  note "Some changes need a logout/restart to fully apply."
  mark_done macos
}

# ─────────────────────────────────────────────────────────────────────────
step_projects() {
  header "Clone my projects"
  local f="$REPO_DIR/config/repos.txt" url dir n=0
  mkdir -p "$PROJECTS_DIR"
  while read -r url dir <&3; do
    case "$url" in ''|\#*) continue ;; esac
    [ -z "$dir" ] && dir="$(basename "$url" .git)"
    n=$((n+1))
    if [ -d "$PROJECTS_DIR/$dir/.git" ]; then ok "$dir (already cloned)"; continue; fi
    if confirm "Clone $url → $PROJECTS_DIR/$dir?" Y; then
      run_task "Cloning $dir" git clone "$url" "$PROJECTS_DIR/$dir"
    fi
  done 3< "$f"
  [ $n -eq 0 ] && note "No repos listed yet. Add them to config/repos.txt."
  mark_done projects
}
