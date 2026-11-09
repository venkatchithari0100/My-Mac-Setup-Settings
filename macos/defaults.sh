# shellcheck shell=bash
# macOS preferences, grouped. Each group is offered separately by the wizard.
# Format: one function per group + a line in MACOS_GROUPS ("function|description").

MACOS_GROUPS=(
  "macos_appearance|Dark mode, always show scroll bars"
  "macos_finder|Finder: show file extensions, hidden files, path & status bar, list view, folders first"
  "macos_dock|Dock: auto-hide, smaller icons, no recent apps"
  "macos_keyboard|Keyboard: fast key repeat, no auto-correct / smart quotes (better for coding)"
  "macos_screenshots|Screenshots: save to ~/Pictures/Screenshots as PNG, no shadow"
  "macos_misc|No .DS_Store on network/USB drives, expand save & print dialogs"
)

macos_appearance() {
  defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"
  defaults write NSGlobalDomain AppleShowScrollBars -string "Always"
}

macos_finder() {
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  defaults write com.apple.finder AppleShowAllFiles -bool true
  defaults write com.apple.finder ShowPathbar -bool true
  defaults write com.apple.finder ShowStatusBar -bool true
  defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
  defaults write com.apple.finder _FXSortFoldersFirst -bool true
  defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
  defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
  defaults write com.apple.finder NewWindowTarget -string "PfHm"
  killall Finder >/dev/null 2>&1 || true
}

macos_dock() {
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock autohide-delay -float 0
  defaults write com.apple.dock tilesize -int 48
  defaults write com.apple.dock show-recents -bool false
  defaults write com.apple.dock minimize-to-application -bool true
  killall Dock >/dev/null 2>&1 || true
}

macos_keyboard() {
  defaults write NSGlobalDomain KeyRepeat -int 2
  defaults write NSGlobalDomain InitialKeyRepeat -int 15
  defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
}

macos_screenshots() {
  mkdir -p "$HOME/Pictures/Screenshots"
  defaults write com.apple.screencapture location -string "$HOME/Pictures/Screenshots"
  defaults write com.apple.screencapture type -string "png"
  defaults write com.apple.screencapture disable-shadow -bool true
  killall SystemUIServer >/dev/null 2>&1 || true
}

macos_misc() {
  defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
  defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
}
