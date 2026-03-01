#!/usr/bin/env bash

set -e

MARKER_START="# >>> failure-hook START >>>"
MARKER_END="# <<< failure-hook END <<<"

SOUND_FILE="failure.wav"
TARGET_SOUND_PATH="$HOME/$SOUND_FILE"

REPO_RAW_BASE="https://raw.githubusercontent.com/srthk4370-IIITH/SoundExtension/main"

echo "Installing failure-hook..."

OS="$(uname)"

IS_WSL=false
if [[ "$OS" == "Linux" ]] && grep -qi microsoft /proc/version 2>/dev/null; then
    IS_WSL=true
fi

RC_FILE="$HOME/.bashrc"
touch "$RC_FILE"

echo "Downloading sound..."
curl -fsSL "$REPO_RAW_BASE/$SOUND_FILE" -o "$TARGET_SOUND_PATH"

if [[ ! -f "$TARGET_SOUND_PATH" ]]; then
    echo "ERROR: failed to download sound."
    exit 1
fi

# Remove previous install
if grep -q "$MARKER_START" "$RC_FILE"; then
    sed -i "/$MARKER_START/,/$MARKER_END/d" "$RC_FILE"
fi

# Backend selection
if [[ "$IS_WSL" == true ]]; then

SOUND_FUNCTION=$(cat <<'EOF'
play_failure_sound() {
    WIN_USER=$(cmd.exe /c echo %USERNAME% | tr -d "\r")
    WIN_PATH="C:\\Users\\$WIN_USER\\failure.wav"

    (powershell.exe -c "(New-Object Media.SoundPlayer '$WIN_PATH').PlaySync();" \
        >/dev/null 2>&1 & disown)
}
EOF
)

elif [[ "$OS" == "Darwin" ]]; then

SOUND_FUNCTION=$(cat <<'EOF'
play_failure_sound() {
    (afplay "$HOME/failure.wav" >/dev/null 2>&1 & disown)
}
EOF
)

else

SOUND_FUNCTION=$(cat <<'EOF'
play_failure_sound() {
    (paplay "$HOME/failure.wav" >/dev/null 2>&1 & disown)
}
EOF
)

fi

# Inject EXACT working block
{
echo "$MARKER_START"
echo
echo "$SOUND_FUNCTION"
echo

cat <<'HOOK_BLOCK'

__compiler_failure_hook() {

    local status=$?
    local last_cmd=$(history 1)
    last_cmd="${last_cmd#*[0-9]  }"

    # trim leading whitespace
    last_cmd="${last_cmd#"${last_cmd%%[![:space:]]*}"}"
    local raw_word="${last_cmd%% *}"
    local first_word="$(basename "$raw_word")"

    case "$first_word" in
        gcc|g++|clang|clang++|make|cmake|javac|rustc|cargo|go)
            if [ $status -ne 0 ]; then
                play_failure_sound
            fi
            ;;
        ./*)
            if [ -x "$raw_word" ] && [ $status -ne 0 ]; then
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
echo "Restart terminal."