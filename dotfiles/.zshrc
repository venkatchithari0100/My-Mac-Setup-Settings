# ~/.zshrc — managed by My-Mac-Setup-Settings (edit in the repo, then commit)

MAC_SETUP_DIR="${MAC_SETUP_DIR:-$HOME/My-Projects/My-Mac-Setup-Settings}"
BREW_PREFIX="${HOMEBREW_PREFIX:-/opt/homebrew}"

# ── History ─────────────────────────────────────────────────────────────
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000
setopt EXTENDED_HISTORY INC_APPEND_HISTORY SHARE_HISTORY
setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS

# ── Completion ──────────────────────────────────────────────────────────
FPATH="$BREW_PREFIX/share/zsh/site-functions:$FPATH"
autoload -Uz compinit && compinit -C
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'   # case-insensitive
zstyle ':completion:*' menu select

# ── Environment ─────────────────────────────────────────────────────────
export GPG_TTY="$(tty)"
if command -v code >/dev/null 2>&1; then export EDITOR="code --wait"; else export EDITOR="nano"; fi

# ── Interactive tools ───────────────────────────────────────────────────
[ -f "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ] && \
  source "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
command -v fzf    >/dev/null 2>&1 && source <(fzf --zsh)
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
command -v atuin  >/dev/null 2>&1 && eval "$(atuin init zsh --disable-up-arrow)"   # Ctrl+R

# ── Aliases ─────────────────────────────────────────────────────────────
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -lah --icons --git --group-directories-first'
  alias tree='eza --tree --icons --level=2'
fi
command -v bat >/dev/null 2>&1 && alias cat='bat --paging=never --style=plain'
alias c='claude'
alias gs='git status -sb'
alias gl='git log --oneline --graph --decorate -20'
alias reload='exec zsh'

# `setup` = run the Mac setup wizard; `setup sync` = save new software to the repo
setup() { "$MAC_SETUP_DIR/setup.sh" "$@"; }

# After installing/removing something with brew, remind to sync it to the repo
brew() {
  command brew "$@"; local rc=$?
  if [ $rc -eq 0 ]; then
    case "$1" in
      install|uninstall|remove|rm|reinstall)
        print -P "%F{8}↳ Run 'setup sync' to save this change to your Mac setup repo.%f" ;;
    esac
  fi
  return $rc
}

# Gentle reminder if you haven't synced in 14 days
_ms_last="$HOME/.config/mac-setup/last-sync"
if [ -f "$_ms_last" ] && [ $(( $(date +%s) - $(cat "$_ms_last") )) -gt 1209600 ]; then
  print -P "%F{yellow}💡 It's been 2+ weeks since 'setup sync'. Installed anything new?%f"
fi
unset _ms_last

# ── Machine-specific overrides (not in the repo) ────────────────────────
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"

# ── Prompt (keep near the end) ──────────────────────────────────────────
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"

# Syntax highlighting must be sourced last
[ -f "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] && \
  source "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
