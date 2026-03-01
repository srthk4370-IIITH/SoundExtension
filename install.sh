#!/usr/bin/env bash

set -e

MARKER_START="# >>> failure-hook START >>>"
MARKER_END="# <<< failure-hook END <<<"

HOOK_NAME="failure-hook"
SOUND_FILE="failure.wav"
TARGET_SOUND_PATH="$HOME/$SOUND_FILE"

echo "Installing $HOOK_NAME..."

# Detect OS
OS="$(uname)"

IS_WSL=false
if [[ "$OS" == "Linux" ]] && grep -qi microsoft /proc/version 2>/dev/null; then
    IS_WSL=true
fi

# Detect shell config file
if [[ "$SHELL" == *"bash"* ]]; then
    RC_FILE="$HOME/.bashrc"
elif [[ "$SHELL" == *"zsh"* ]]; then
    RC_FILE="$HOME/.zshrc"
else
    echo "Unsupported shell: $SHELL"
    exit 1
fi

echo "Detected shell config: $RC_FILE"

# Ensure RC file exists
touch "$RC_FILE"

# Copy sound file
if [[ -f "$SOUND_FILE" ]]; then
    cp "$SOUND_FILE" "$TARGET_SOUND_PATH"
    echo "Copied $SOUND_FILE to $TARGET_SOUND_PATH"
else
    echo "ERROR: $SOUND_FILE not found in installer directory."
    exit 1
fi

# Remove existing installation block (idempotent)
if grep -q "$MARKER_START" "$RC_FILE"; then
    echo "Existing installation detected. Updating..."
    sed -i "/$MARKER_START/,/$MARKER_END/d" "$RC_FILE"
fi

# Determine sound backend
if [[ "$OS" == "Darwin" ]]; then
    SOUND_FUNCTION='
play_failure_sound() {
    afplay "$HOME/failure.wav" >/dev/null 2>&1 &
}
'
elif [[ "$IS_WSL" == true ]]; then
    SOUND_FUNCTION='
play_failure_sound() {
    WIN_USER=$(cmd.exe /c echo %USERNAME% | tr -d "\r")
    WIN_PATH="C:\\Users\\$WIN_USER\\failure.wav"

    powershell.exe -c "(New-Object Media.SoundPlayer '\''$WIN_PATH'\'').PlaySync();" \
        >/dev/null 2>&1 &
}
'
else
    SOUND_FUNCTION='
play_failure_sound() {
    paplay "$HOME/failure.wav" >/dev/null 2>&1 &
}
'
fi

# Append hook
cat <<EOF >> "$RC_FILE"

$MARKER_START

$SOUND_FUNCTION

__compiler_failure_hook() {
    local status=\$?
    local last_cmd=\$(fc -ln -1)
    local first_word="\${last_cmd%% *}"

    case "\$first_word" in
        gcc|g++|clang|clang++|make|cmake|javac|rustc|cargo|go)
            if [ \$status -ne 0 ]; then
                play_failure_sound
            fi
            ;;
        ./*)
            if [ -x "\$first_word" ] && [ \$status -ne 0 ]; then
                play_failure_sound
            fi
            ;;
    esac
}

PROMPT_COMMAND="__compiler_failure_hook"

$MARKER_END

EOF

echo "Installation complete."
echo "Restart your terminal or run: source $RC_FILE"