#!/usr/bin/env bash

set -e

MARKER_START="# >>> failure-hook START >>>"
MARKER_END="# <<< failure-hook END <<<"

HOOK_NAME="failure-hook"
SOUND_FILE="failure.wav"
TARGET_SOUND_PATH="$HOME/$SOUND_FILE"

# 🔴 Replace only if repo name changes
REPO_RAW_BASE="https://raw.githubusercontent.com/srthk4370-IIITH/SoundExtension/main"

echo "Installing $HOOK_NAME..."

OS="$(uname)"

IS_WSL=false
if [[ "$OS" == "Linux" ]] && grep -qi microsoft /proc/version 2>/dev/null; then
    IS_WSL=true
fi

# Detect shell rc file
if [[ "$SHELL" == *"bash"* ]]; then
    RC_FILE="$HOME/.bashrc"
elif [[ "$SHELL" == *"zsh"* ]]; then
    RC_FILE="$HOME/.zshrc"
else
    echo "Unsupported shell: $SHELL"
    exit 1
fi

touch "$RC_FILE"

echo "Downloading $SOUND_FILE..."
curl -fsSL "$REPO_RAW_BASE/$SOUND_FILE" -o "$TARGET_SOUND_PATH"

if [[ ! -f "$TARGET_SOUND_PATH" ]]; then
    echo "ERROR: Failed to download sound file."
    exit 1
fi

# Remove existing installation block
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

# Write hook block safely
{
echo "$MARKER_START"
echo
echo "$SOUND_FUNCTION"

cat <<'HOOK_BLOCK'

__compiler_failure_hook() {
    local status=$?
    local last_cmd=$(fc -ln -1)
    local first_word="${last_cmd%% *}"

    case "$first_word" in
        gcc|g++|clang|clang++|make|cmake|javac|rustc|cargo|go)
            if [ $status -ne 0 ]; then
                play_failure_sound
            fi
            ;;
        ./*)
            if [ -x "$first_word" ] && [ $status -ne 0 ]; then
                play_failure_sound
            fi
            ;;
    esac
}

PROMPT_COMMAND="__compiler_failure_hook${PROMPT_COMMAND:+;$PROMPT_COMMAND}"

HOOK_BLOCK

echo
echo "$MARKER_END"
} >> "$RC_FILE"

echo "Installation complete."
echo "Restart terminal or run: source $RC_FILE"