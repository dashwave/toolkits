#!/bin/bash
set -e

RESET="\\033[0m"
RED="\\033[31;1m"
GREEN="\\033[32;1m"
YELLOW="\\033[33;1m"
BLUE="\\033[34;1m"
WHITE="\\033[37;1m"

print_unsupported_platform()
{
    >&2 say_red "error: We're sorry, but it looks like installation of the Dashwave CLI"
    >&2 say_red "       using this script is not supported on your platform. We support"
    >&2 say_red "       debian based Linux and are interested in supporting more"
    >&2 say_red "       platforms. Please reach out to us at hello@dashwave.io"
    >&2 say_yellow
    >&2 say_yellow "If you are using macOS, prefer installing using the brew package manager."
    >&2 say_yellow "Refer to the docs."
}

say_green()
{
    [ -z "${SILENT}" ] && printf "%b%s%b\\n" "${GREEN}" "$1" "${RESET}"
    return 0
}

say_red()
{
    printf "%b%s%b\\n" "${RED}" "$1" "${RESET}"
}

say_yellow()
{
    [ -z "${SILENT}" ] && printf "%b%s%b\\n" "${YELLOW}" "$1" "${RESET}"
    return 0
}

say_blue()
{
    [ -z "${SILENT}" ] && printf "%b%s%b\\n" "${BLUE}" "$1" "${RESET}"
    return 0
}

say_white()
{
    [ -z "${SILENT}" ] && printf "%b%s%b\\n" "${WHITE}" "$1" "${RESET}"
    return 0
}

at_exit()
{
    # shellcheck disable=SC2181
    # https://github.com/koalaman/shellcheck/wiki/SC2181
    # Disable because we don't actually know the command we're running
    # We need the slack/discord workspace URL here for connect
    if [ "$?" -ne 0 ]; then
        >&2 say_red
        >&2 say_red "We're sorry, but it looks like something might have gone wrong during installation."
        >&2 say_red "If you need help, feel free to reach out to us on hello@dashwave.io"
    fi
}

trap at_exit EXIT

SILENT=""

OS=""
case $(uname) in
    "Linux") OS="linux";;
   "Darwin") OS="darwin";;
    *)
        print_unsupported_platform
        exit 1
        ;;
esac

ARCH=""
case $(uname -m) in
    "x86_64") ARCH="amd64";;
    "arm64") ARCH="arm64";;
    "aarch64") ARCH="arm64";;
    *)
        print_unsupported_platform
        exit 1
        ;;
esac

BINARY_NAME="dw"
BINARY_VERSION=$(curl -s https://api.github.com/repos/dashwave/toolkits/releases/latest | grep "tag_name" | cut -d '"' -f 4 | tr -d '[:space:][:cntrl:]')
TRIMMED_BINARY_VERSION=${BINARY_VERSION#v}
TAR_NAME=dw_${OS}_${ARCH}.tar.gz
TAR_URL="https://github.com/dashwave/toolkits/releases/download/${BINARY_VERSION}/${TAR_NAME}"
BINARY_DEST="${HOME}/.dw-cli/bin"
TARGET_FILE="${BINARY_DEST}/${BINARY_NAME}"
# BINLOCATION="/usr/local/bin"
SUCCESS_CMD="${TARGET_FILE}/${BINARY_NAME} version"
CONFIG_CMD="${TARGET_FILE}/${BINARY_NAME} config -v ${TRIMMED_BINARY_VERSION}"

if ! command -v dw >/dev/null; then
    say_blue "=== Installing Dashwave CLI ${BINARY_VERSION} ==="
else
    say_blue "=== Upgrading Dashwave CLI ${BINARY_VERSION} ==="
fi

say_white "Detected OS: ${OS} with Architecture: ${ARCH}"

check_and_install_package_manager() {
    if [ $OS = "darwin" ]; then
        if ! command -v brew >/dev/null; then
            >&2 say_red "Homebrew not found in system"

            >&2 say_white "Installing brew..."
            /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

            >&2 say_white "Installing brew cask..."
            brew tap homebrew/cask
        fi
    fi
}

cleanup_existing_legacy_dw_installation() {
    if [ $OS = "darwin" ]; then
        sudo -u $RUNNER_USERNAME bash -c 'brew remove dw > /dev/null 2>&1 || true'
    fi
}

download_dwcli() {
    # If `~/.dw-cli/bin exists, clear it out
    if [ -e "${HOME}/.dw-cli/bin" ]; then
        rm -rf "${HOME}/.dw-cli/bin"
    fi

    mkdir -p "${HOME}/.dw-cli/bin"

    say_white "+ Downloading ${TAR_URL}..."

    # shellcheck disable=SC2046
    # https://github.com/koalaman/shellcheck/wiki/SC2046
    # Disable to allow the `--silent` option to be omitted.
    if wget --tries=3 -O "${TAR_NAME}" -q "${TAR_URL}"; then
    # if curl -LO https://github.com/dashwave/toolkits/releases/download/v0.0.1-alpha/dw
        tar -xvf $TAR_NAME -C $BINARY_DEST
        rm $TAR_NAME
        chmod +x $TARGET_FILE
    else
        >&2 say_red "error: failed to download ${TAR_URL}"
        >&2 say_red "       check your internet and try again; if the problem persists, file an"
        >&2 say_red "       issue at hello@dashwave.io"
        exit 1
    fi
}

setup_dependencies() {
    # Move the tools from ~/.dw-cli/bin to ~/.dw-cli/tools

    # Check if tools already exist, clear them off
    TOOL_DEST="${HOME}/.dw-cli/tools"
    if [ -e $TOOL_DEST ]; then
        rm -rf $TOOL_DEST
    fi

    # Recreate the tools destination
    mkdir -p $TOOL_DEST

    tools=("rsync" "emux-go")
    for tool in "${tools[@]}"; do
        mv "${BINARY_DEST}/${tool}" "${TOOL_DEST}/${tool}"
    done
}

download_dwcli
setup_dependencies

# say_blue
# say_blue "=== dw-cli is now installed! ==="
