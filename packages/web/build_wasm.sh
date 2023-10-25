#!/bin/bash

# Store positional arguments in descriptive variables for clarity
SCRIPT_NAME="$0"
EMSDK_PATH="$1"
THORVG_TAG_OR_BRANCH="${2:-tags/v0.11.2}"

# Ensure we always execute from the directory the script resides in
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

# Ensure the user provides the EMSDK path as an argument to the script
#if [ "$#" -lt 1 ]; then
if [ -z "$EMSDK_PATH" ]; then
  echo "
        Oops! It seems you forgot to provide the emsdk path argument.
    
        Please install emsdk and then specify its path when running this script.
        For emsdk installation guidance, visit: https://emscripten.org/docs/getting_started/downloads.html
    
        Usage: $SCRIPT_NAME <path_to_EMSDK> [optional_thorvg_tag_or_branch]
        ex. -> $SCRIPT_NAME /home/user/emsdk/ tags/v0.11.1
    "
  exit 1
fi

# Function for checking command status and printing an error
check_command_success() {
  if [ $? -ne 0 ]; then
    echo "$1"
    exit 1
  fi
}

# Check if essential tools are available in the system
command -v git > /dev/null 2>&1 || {
  echo "Error: git is not installed. Please ensure you have git installed and try again."
  exit 1
}
command -v meson > /dev/null 2>&1 || {
  echo "Error: meson is not installed. Please install meson and try again."
  exit 1
}
command -v ninja > /dev/null 2>&1 || {
  echo "Error: ninja is not installed. Please install ninja and try again."
  exit 1
}

# Clone the thorvg repository if it's not already present
if [ ! -d "$DIR/thorvg" ]; then
  git clone https://github.com/thorvg/thorvg.git
  check_command_success "Error cloning the repository"
fi

# Remove the build_wasm directory inside thorvg if it exists
if [ -d "$DIR/thorvg/build_wasm" ]; then
  rm -r "$DIR/thorvg/build_wasm"
fi

# Change directory to thorvg to run the wasm_build.sh script
cd "$DIR/thorvg"
git fetch origin
# git checkout $THORVG_TAG_OR_BRANCH
git checkout "$THORVG_TAG_OR_BRANCH"
check_command_success "Error switching to the desired tag/branch: $THORVG_TAG_OR_BRANCH"

# Run the wasm build script with the provided EMSDK path
./wasm_build.sh "$EMSDK_PATH"
check_command_success "Error running wasm_build.sh"

# Change back to the parent directory
cd "$DIR"

# Delete the src/renderer-wasm/bin directory if it exists
if [ -d "$DIR/src/renderer-wasm/bin" ]; then
  rm -r "$DIR/src/renderer-wasm/bin"
fi

# Create a unique temporary file to hold the cross file after substitution
TMPFILE=$(mktemp /tmp/wasm_cross.XXXXXX)

# Ensure the temp file is always cleaned up on exit
trap 'rm -f "$TMPFILE"' EXIT

# Substitute the EMSDK path in the wasm_x86_i686.txt file and save to the temporary file
sed "s|EMSDK:|$EMSDK_PATH|g" "$DIR/wasm_x86_i686.txt" > "$TMPFILE"
check_command_success "Error substituting EMSDK path in wasm_x86_i686.txt"

# Setup meson build with the cross file
meson --cross-file "$TMPFILE" src/renderer-wasm/bin
check_command_success "Error setting up meson"

# Build using ninja
ninja -C src/renderer-wasm/bin/
check_command_success "Error during ninja build"

# Remove all non .js and .wasm files
find "$DIR/src/renderer-wasm/bin" -type f ! \( -name "*.js" -o -name "*.wasm" \) -delete

# Remove unwanted directories
rm -rf "$DIR/src/renderer-wasm/bin/meson-info" "$DIR/src/renderer-wasm/bin/meson-logs" "$DIR/src/renderer-wasm/bin/meson-private" "$DIR/src/renderer-wasm/bin/renderer.js.p"