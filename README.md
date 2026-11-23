# 🍎 My Mac Setup Settings

An interactive wizard that sets up a new Mac the way I like it: apps, shell, theme, dotfiles, Git/SSH/GPG keys, Claude Code with a usage meter, and macOS preferences. It also keeps itself up to date: `setup sync` finds software installed since your last sync and saves it back to this repo.

```
╭── Apps & packages
│  ▰▰▰▱▱▱▱▱▱▱▱ step 3 of 13
╰─────────────────────────────────────────────
  ✔ zoom                           installed in 0:12
  · git                            already installed
  ⠹ ▕████████████░░░░░░░░▏  62% 34/54  docker-desktop 0:41
```

## 🚀 New Mac: one line

Open **Terminal** and paste:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/venkatchithari0100/My-Mac-Setup-Settings/main/bootstrap.sh)"
```

This installs Homebrew (plus Xcode Command Line Tools and git), clones this repo to `~/My-Projects/My-Mac-Setup-Settings`, and opens the wizard. Then:

1. Choose **`a`** (Run ALL steps).
2. Press **Enter** once to accept the recommended choices.
3. Enter your **Mac password** once when asked.
4. When GitHub opens in your browser, paste your **SSH** and **GPG** keys (they're already on your clipboard) and press Enter.

Everything else runs on its own.

## 🧙 Using the wizard

```bash
setup              # menu (✔ marks finished steps)
setup all          # run every step: one question at the start, then automatic
setup sync         # find newly installed software and save it to this repo
setup apps         # run one step: xcode, homebrew, apps, dotfiles, theme,
                   #   git, ssh, gpg, claude, ai, android, macos, projects
setup all --yes    # no questions at all (except pasting keys on GitHub)
```

`setup` is a shell function added by the dotfiles. Before the dotfiles are linked, run `./setup.sh` from the repo folder instead.

| # | Step | What it does |
|---|---|---|
| 1 | Xcode CLT | Installs Apple's command line tools |
| 2 | Homebrew | Installs and updates Homebrew, and adds it to your PATH |
| 3 | Apps | Installs each app from `brew/*.Brewfile`, one at a time, with a live progress bar. Apps you already installed by hand are left as they are |
| 4 | Dotfiles | Symlinks `dotfiles/*` into `~`. Existing files are backed up to `~/.dotfiles-backup/` |
| 5 | Theme | Starship prompt preset and Ghostty colors (default: Catppuccin) |
| 6 | Git | Name and email, saved in `~/.gitconfig.local` (kept out of the repo) |
| 7 | SSH | Creates an ed25519 key, stores it in macOS Keychain, checks GitHub's host key fingerprint, then helps you add the key on GitHub |
| 8 | GPG | Reuses or creates your signing key, sets up the macOS password prompt, turns on signed commits |
| 9 | Claude Code | Installs Claude Code and the usage meter status line |
| 10 | AI tools | Global CLIs and AI plugins from `config/global-packages.txt`, installed with npm, uv or pipx (for example `ui-ux-pro-max-cli`) |
| 11 | Android | Java 25 LTS, Android SDK (platform, build tools, emulator, system image), accepts Google's SDK licences after asking, and creates a `dev_pixel` emulator. Change the API level with `ANDROID_API=37` |
| 12 | macOS | Dark mode, Finder, Dock, keyboard, screenshots, and other preferences |
| 13 | Projects | Clones the repos listed in `config/repos.txt` |

Every step is safe to run again: it checks what's already done first.

### What you'll see

- **Step progress**: `▰▰▰▱▱▱▱ step 3 of 13` at the top of each step
- **Parallel downloads**: missing apps download 4 at a time (`PARALLEL_DOWNLOADS=6 setup apps` to change it), then install one by one from the local copies
- **Spinners with timers** for anything slow, plus a live `↳` line showing what brew is doing (for example, download %)
- **Live log window**: if anything takes more than 3 minutes, a Terminal window opens and shows its log live. It stops when the step finishes. Change the delay with `LOG_WINDOW_AFTER=120`, or set `LOG_WINDOW_AFTER=0` to turn it off
- **Timeouts**: a task that prints nothing new for 5 minutes, or runs longer than 30 minutes, is stopped and reported as ✖ "timed out", and the wizard moves on. Change these with `STALL_TIMEOUT=600` and `TASK_TIMEOUT=3600` (`0` turns a timeout off). After 1 minute without output, the spinner shows a yellow countdown
- **Ctrl+C skips** the app that's installing right now. Skipped apps are listed at the end
- **Per-app results**: ✔ installed · already installed · ✖ failed, with the reason
- **Summary boxes**: counts and total time for apps, plus a recap of all steps showing what to re-run
- **Logs** for every install in `~/.config/mac-setup/logs/`

Set `NO_ANIM=1` (for example `NO_ANIM=1 setup all`) to turn animations off.

## 📊 Claude Code usage meter

Step 9 adds this status line to Claude Code:

```
🤖 Opus 5.5 │ 5h ██░░░░░░░░ 24% ↻22:00 │ week ████████░░ 82% │ ctx 31%
```

- **5h**: how much of your 5-hour session limit you've used, and when it resets (↻)
- **week**: how much of your weekly limit you've used
- **ctx**: how full the current conversation's context is

Bars are green below 50%, yellow from 50%, and red from 80%. The usage bars appear after Claude's first reply in a session. The script lives in `dotfiles/.claude/statusline.sh`.

## 🔄 Keeping the repo up to date

Run `setup sync` after you install things. It checks:

1. **Homebrew**: formulae and casks that aren't in any Brewfile
2. **/Applications**: apps you installed by hand. It offers a Homebrew cask when one exists. App Store apps become `mas` entries, and anything else goes into `config/manual-apps.txt`
3. **VS Code extensions**
4. **Global packages**: `npm -g`, `uv tool` and `pipx` installs, saved to `config/global-packages.txt`
5. **Shell history**: `cargo install`, `go install`, `curl … | sh` and similar installs, saved to `config/extra-installs.sh`

For each item, pick a group number to save it, **`i`** to ignore it forever, or **Enter** to skip it for now. At the end, sync offers to commit and push.

Two built-in reminders:
- After any `brew install` or `brew uninstall`, the shell suggests running `setup sync`.
- If you haven't synced in 14 days, a new terminal shows a reminder.

## 🤖 AI tools & global packages

Add one line per tool to `config/global-packages.txt`:

```
npm    ui-ux-pro-max-cli        # npm install -g
uv     some-python-cli          # uv tool install
uv     checkov                  # security scanners: checkov, semgrep, bandit
skills nutlope/hallmark         # npx skills add nutlope/hallmark -g  (agent skills)
skills emilkowalski/skill
```

Then run `setup ai`. You can also just install the tool normally (`npm install -g …`) and run `setup sync`, which offers to add it.

## 📱 Android development

`setup android` gets a Mac ready to build and test native Android apps (Kotlin + Jetpack Compose):

1. Installs **Java 25 LTS** (Temurin), the same version Android Studio ships with. Homebrew asks for your **Mac password** here, in plain view
2. Asks you to **accept Google's Android SDK licences**
3. Installs into `~/Library/Android/sdk`: command-line tools, platform tools (`adb`), the emulator, the API 36 platform and build tools, and a Google APIs system image for your Mac's chip (about 5 GB)
4. Creates an emulator called **`dev_pixel`** (Pixel 7)

New terminals get `JAVA_HOME`, `ANDROID_HOME`, `adb` and `emulator` automatically from `.zprofile`. Android Studio uses the same SDK and emulators.

```bash
emulator -avd dev_pixel            # start the emulator
adb devices                        # list running emulators and phones
ANDROID_API=37 setup android       # use another API level
ANDROID_AVD_NAME=tablet setup android   # create another emulator
```

## 🎨 What's installed

| Group | Apps |
|---|---|
| Core CLI | git, gh, gnupg, pinentry-mac, jq, starship, zsh-autosuggestions, zsh-syntax-highlighting, fzf, atuin, zoxide, eza, bat, ripgrep, fd, tlrc, mas, JetBrainsMono Nerd Font |
| Dev & AI | Xcode (App Store), Ghostty, iTerm2, Claude Code, VS Code, Sublime Text, Zed, PyCharm, Antigravity, Docker Desktop, Postman, GitHub Desktop, Node, Python, uv, Go |
| Browsers & comms | Firefox, Chrome, Slack, Zoom, WhatsApp, Telegram, Discord |
| Productivity | Raycast, Rectangle, AltTab, Maccy, Stats, Ice, Obsidian, Notion, Bitwarden |
| Media & utils | IINA, VLC, Keka, The Unarchiver, AppCleaner |
| Mobile, cloud & security | Java 25 LTS (Temurin), Android Studio, Android command-line tools, Terraform, pnpm, gitleaks, trivy, plus checkov, semgrep and bandit (via `uv`, in the AI tools step) |

All of these are free of ads. To change the list, edit `brew/*.Brewfile`. The `# comment` on each line is the description the wizard shows.

**Shell shortcuts** (from `.zshrc`): `z <folder>` jumps to a frequently used folder, **Ctrl+R** searches history, **Ctrl+T** finds files, `ll` lists files with git status, `c` starts Claude Code, and `reload` restarts the shell.

## 🛠 Troubleshooting

| Problem | Fix |
|---|---|
| An app shows ✖ | Read the reason in the summary, or open the log path shown. Fix the cause, or remove that line from its Brewfile, then run `setup apps` |
| "already an App at /Applications/…" | Handled automatically. The app is kept as-is and reported as "installed manually" |
| Stuck with no progress | Look for a hidden macOS pop-up asking your terminal to "update or delete other applications" and click **Allow**. To avoid it, turn on your terminal under System Settings → Privacy & Security → **App Management** |
| Xcode fails with "not signed in" | Open the **App Store**, sign in with your Apple ID, then run `setup apps`. Xcode is about 12 GB, so give it time. The App Store tool can't report progress to the terminal, so watch it in **App Store › your profile**. The wizard waits with no timeout. After it installs, the wizard accepts the license and installs Xcode's components |
| A 🔒 shows in the terminal but no password prompt | Something behind a spinner is asking for your password. Press Ctrl+C and run the step again; installs that need `sudo` (like Java) now ask in plain view |
| Android: "Package path is not valid" when creating the emulator | The step uses the command-line tools inside the SDK (`~/Library/Android/sdk/cmdline-tools/latest`), not Homebrew's copy. Run `setup android` again |
| A formula isn't found anymore | It was renamed or removed. Remove or replace it in the Brewfile |
| An install seems stuck | It's stopped automatically after 5 minutes without output. You can also watch the live log window or press Ctrl+C to skip that app |
| A step was interrupted | Run `./setup.sh` again. Finished steps are skipped |
| The prompt shows boxes instead of icons | Set your terminal font to **JetBrainsMono Nerd Font** |
| Redo a step | `./setup.sh <step>`, for example `./setup.sh theme` |

## 📁 Layout

```
bootstrap.sh              one-line installer for a new Mac
setup.sh                  the wizard (menu, run-all, recap)
lib/ui.sh                 colors, prompts, spinners, progress bars, summary boxes
lib/steps.sh              the 13 setup steps
lib/sync.sh               setup sync
brew/*.Brewfile           app groups
dotfiles/                 .zshrc .zprofile .gitconfig .gitignore_global
                          .config/starship.toml .config/ghostty/config
                          .claude/statusline.sh
macos/defaults.sh         macOS preference groups
config/settings.sh        name, email, GitHub user, folders, default theme
config/repos.txt          repos to clone into ~/My-Projects
config/global-packages.txt  global npm / uv / pipx CLIs and AI plugins
config/extra-installs.sh  other install commands (curl | sh, cargo…)
config/ignore.txt         things sync should never ask about
config/manual-apps.txt    apps you have to install by hand
```

## 🔒 Security

- Private keys are **never** stored here. `.gitignore` blocks `*.gpg`, `*.asc`, `*.key`, `*.pem` and `id_*`.
- Your machine-specific Git identity and signing key live in `~/.gitconfig.local`, outside the repo.
- GitHub's SSH host key is trusted only if it matches GitHub's published fingerprint.
- Back up your GPG private key somewhere safe:
  `gpg --export-secret-keys --armor <KEYID> > ~/Desktop/gpg-private.asc`, then move it to a password manager or an encrypted drive.
