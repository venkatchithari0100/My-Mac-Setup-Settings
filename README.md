# My Mac Setup Settings

An interactive wizard that sets up a new Mac the way I like it: apps, shell, theme, dotfiles, Git/SSH/GPG keys, Claude Code, and macOS preferences. It also keeps itself up to date: `setup sync` finds software you've installed since and adds it to this repo.

## New Mac: one line

Open **Terminal** and paste:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/venkatchithari0100/My-Mac-Setup-Settings/main/bootstrap.sh)"
```

This installs Homebrew (plus Xcode Command Line Tools and git), clones this repo to `~/My-Projects/My-Mac-Setup-Settings`, and opens the wizard. Choose **a) Run ALL steps**.

## The wizard

```
setup            # menu
setup all        # every step, asking before each
setup sync       # save newly installed software to the repo
setup theme      # run a single step (xcode, homebrew, apps, dotfiles, theme,
                 #   git, ssh, gpg, claude, macos, projects)
```

`setup` is a shell function added by the dotfiles. Before the dotfiles are linked, run `./setup.sh` from the repo folder instead.

| Step | What it does |
|---|---|
| Xcode CLT | Installs Apple's command line tools |
| Homebrew | Installs/updates Homebrew and adds it to your PATH |
| Apps | Shows each group in `brew/*.Brewfile` so you can install all of a group, skip some apps, or skip the whole group |
| Dotfiles | Symlinks `dotfiles/*` into `~`. Existing files go to `~/.dotfiles-backup/` |
| Theme | Choose a Starship prompt preset and a Ghostty color theme (default: Catppuccin) |
| Git | Name and email, saved in `~/.gitconfig.local` (not in the repo) |
| SSH | Creates an ed25519 key, stores it in macOS Keychain, verifies GitHub's host key, copies the public key, and opens GitHub so you can add it |
| GPG | Creates or reuses your signing key, sets up the pinentry-mac password prompt, and turns on signed commits |
| Claude Code | Installs Claude Code and its usage meter status line (5-hour, weekly and context usage) |
| macOS | Optional groups: dark mode, Finder, Dock, keyboard, screenshots, misc |
| Projects | Clones the repos listed in `config/repos.txt` |

## Keeping the repo up to date

Run `setup sync` after you install things. It checks:

1. **Homebrew**: formulae and casks you've installed that aren't in any Brewfile
2. **/Applications**: apps you installed by hand. If Homebrew has a cask for one, it offers to add the cask. App Store apps become `mas` entries. Anything else is recorded in `config/manual-apps.txt`.
3. **VS Code extensions**
4. **Shell history**: `npm -g`, `pipx`, `uv tool`, `cargo install`, `curl … | sh` and similar installs, saved to `config/extra-installs.sh`

For each item, choose a group to save it to, **i** to ignore it forever, or Enter to skip it for now. At the end, sync offers to commit and push.

Two reminders help you remember to sync:
- After any `brew install` or `brew uninstall`, the shell suggests running `setup sync`.
- If you haven't synced in 14 days, a new terminal shows a reminder.

## Layout

```
bootstrap.sh            one-line installer for a new Mac
setup.sh                the wizard
lib/                    ui, steps, sync
brew/*.Brewfile         app groups (edit freely; "# comment" = description)
dotfiles/               .zshrc .zprofile .gitconfig .gitignore_global
                        .config/starship.toml .config/ghostty/config .claude/statusline.sh
macos/defaults.sh       macOS preference groups
config/settings.sh      name, email, GitHub user, folders, default theme
config/repos.txt        repos to clone
config/extra-installs.sh  non-Homebrew install commands
config/ignore.txt       things sync should never ask about
config/manual-apps.txt  apps you have to install by hand
```

Private keys are never stored here. `.gitignore` blocks `*.gpg`, `*.asc`, `id_*` and `*.pem`.
