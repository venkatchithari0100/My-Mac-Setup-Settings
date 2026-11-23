# The following lines were added by Docker Desktop to add commands to your PATH.
export PATH="$PATH:/Users/neocode0100/.docker/bin"
# End of Docker Desktop section.

# ~/.zprofile — managed by My-Mac-Setup-Settings (edit in the repo)

# Homebrew (Apple Silicon first, then Intel)
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Personal binaries
export PATH="$HOME/.local/bin:$PATH"

# Java 25 LTS + Android SDK (installed by the "android" setup step)
if JAVA_25="$(/usr/libexec/java_home -v 25 2>/dev/null)"; then export JAVA_HOME="$JAVA_25"; fi
unset JAVA_25
if [ -d "$HOME/Library/Android/sdk" ]; then
  export ANDROID_HOME="$HOME/Library/Android/sdk"
  export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
fi
