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
#    "Darwin") OS="darwin";;
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

DISTRO=""
# Check if /etc/os-release file exists
if [ -f /etc/os-release ]; then
    # Source the os-release file to access its variables
    . /etc/os-release

    # Check if the ID field contains "debian"
    if [[ $ID == "debian" || $ID_LIKE == "debian" ]]; then
        DISTRO="debian"
    fi

fi

if [[ $EUID -ne 0 ]]; then
    >&2 say_red "This script was run using a non-sudo user. Please run using sudo to proceed"
    exit 0
else
    RUNNER_USERNAME=$SUDO_USER
fi


BINARY_NAME="dw"
BINARY_VERSION=$(curl -s https://api.github.com/repos/dashwave/toolkits/releases/latest | grep "tag_name" | cut -d '"' -f 4 | tr -d '[:space:][:cntrl:]')
TRIMMED_BINARY_VERSION=${BINARY_VERSION#v}
TAR_NAME=dw_${OS}_${ARCH}.tar.gz
TAR_URL="https://github.com/dashwave/toolkits/releases/download/${BINARY_VERSION}/${TAR_NAME}"
BINARY_DEST="${HOME}/.dw-cli/bin"
TARGET_FILE="${BINARY_DEST}/${BINARY_NAME}"
BINLOCATION="/usr/local/bin"
SUCCESS_CMD="${BINLOCATION}/${BINARY_NAME} version"
CONFIG_CMD="${BINLOCATION}/${BINARY_NAME} config -v ${TRIMMED_BINARY_VERSION}"

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

install_dependencies() {
    if ! command -v rsync >/dev/null; then
        if [ $OS = "darwin" ]; then
            >&2 say_white "Installing rsync"
            sudo -u $RUNNER_USERNAME bash -c 'brew install rsync'

            if ! command -v rsync >/dev/null; then
                >&2 say_red "rsync cannot be installed. Please manually install rsync."
            fi
        elif [ $OS = "linux" -a $DISTRO = "debian" ]; then
            >&2 say_white "Installing rsync"
            sudo apt-get -y -qq install rsync

            if ! command -v rsync >/dev/null; then
                >&2 say_red "rsync cannot be installed. Please manually install rsync."
            fi
        else
            >&2 say_red "rsync is a prerequisite to run dw. Please manually install rsync."
        fi
    else
        >&2 say_yellow "rsync is already installed. Skipping."
    fi

    if ! command -v sshpass >/dev/null; then
        if [ $OS = "darwin" ]; then
            >&2 say_white "Installing sshpass"
            sudo -u $RUNNER_USERNAME bash -c 'brew install esolitos/ipa/sshpass'

            if ! command -v sshpass >/dev/null; then
                >&2 say_red "sshpass cannot be installed. Please manually install sshpass."
            fi
        elif [ $OS = "linux" -a $DISTRO = "debian" ]; then
            >&2 say_white "Installing sshpass"
            sudo apt-get -y -qq install sshpass

            if ! command -v sshpass >/dev/null; then
                >&2 say_red "sshpass cannot be installed. Please manually install sshpass."
            fi
        else
            >&2 say_red "sshpass is a prerequisite to run dw. Please manually install sshpass."
        fi
    else
        >&2 say_yellow "sshpass is already installed. Skipping."
    fi

    if ! command -v wget >/dev/null; then
        if [ $OS = "darwin" ]; then
            >&2 say_white "Installing wget"
            brew install wget

            if ! command -v wget >/dev/null; then
                >&2 say_red "wget cannot be installed. Please manually install wget."
            fi
        elif [ $OS = "linux" -a $DISTRO = "debian" ]; then
            >&2 say_white "Installing wget"
            sudo apt-get -y -qq install wget

            if ! command -v wget >/dev/null; then
                >&2 say_red "wget cannot be installed. Please manually install wget."
            fi
        else
            >&2 say_red "wget is a prerequisite to run dw. Please manually install wget"
        fi
    else
        >&2 say_yellow "wget is already installed. Skipping."
    fi

    if ! command -v adb >/dev/null; then
        if [ $OS = "darwin" ]; then
            >&2 say_white "Installing adb"
            brew install --cask android-platform-tools

            if ! command -v adb >/dev/null; then
                >&2 say_red "adb cannot be installed. Please manually install adb."
            fi
        elif [ $OS = "linux" -a $DISTRO = "debian" ]; then
            >&2 say_white "Installing adb"
            sudo apt-get -y -qq install android-tools-adb

            if ! command -v adb >/dev/null; then
                >&2 say_red "adb cannot be installed. Please manually install adb."
            fi
        else
            >&2 say_red "adb is a prerequisite to run dw. Please manually install adb"
        fi
    else
        >&2 say_yellow "adb is already installed. Skipping."
    fi

    if ! command -v scrcpy >/dev/null; then
        if [ $OS = "darwin" ]; then
            >&2 say_white "Installing scrcpy"
            brew install scrcpy

            if ! command -v scrcpy >/dev/null; then
                >&2 say_red "scrcpy cannot be installed. Please manually install scrcpy."
            fi
        elif [ $OS = "linux" -a $DISTRO = "debian" ]; then
            >&2 say_white "Installing scrcpy"
            sudo apt-get -y -qq install scrcpy

            if ! command -v scrcpy >/dev/null; then
                >&2 say_red "scrcpy cannot be installed. Please manually install scrcpy."
            fi
        else
            >&2 say_red "scrcpy is a prerequisite to run dw. Please manually install scrcpy"
        fi
    else
        >&2 say_yellow "scrcpy is already installed. Skipping."
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

install_dwcli() {
    if [ ! -w "$BINLOCATION" ]; then
        >&2 say_red
        >&2 say_red "============================================================"
        >&2 say_red "  The script was run as a user who is unable to write"
        >&2 say_red "  to $BINLOCATION. To complete the installation the"
        >&2 say_red "  following commands may need to be run manually."
        >&2 say_red "============================================================"
        >&2 say_red
        >&2 say_red "  sudo cp $TARGET_FILE $BINLOCATION/$BINARY_NAME"

        if [ -n "$ALIAS_NAME" ]; then
            >&2 say_red "  sudo ln -sf $TARGET_FILE $BINLOCATION/$ALIAS_NAME"
        fi

        >&2 say_red

    else
        >&2 say_white
        >&2 say_white "Running with sufficient permissions to attempt to move ${BINARY_NAME} to ${BINLOCATION}"

        if [ ! -w "$BINLOCATION/$BINARY_NAME" ] && [ -f "$BINLOCATION/$BINARY_NAME" ]; then

            >&2 say_red
            >&2 say_red "================================================================"
            >&2 say_red "  $BINLOCATION/$BINARY_NAME already exists and is not writeable"
            >&2 say_red "  by the current user.  Please adjust the binary ownership"
            >&2 say_red "  or run sh/bash with sudo."
            >&2 say_red "================================================================"
            >&2 say_red
            exit 1

        fi

        mv $TARGET_FILE $BINLOCATION/$BINARY_NAME

        if [ "$?" = "0" ]; then
            >&2 say_green "New version of ${BINARY_NAME} installed to ${BINLOCATION}"
        fi

        if [ -e "${TARGET_FILE}" ]; then
            rm "${TARGET_FILE}"
        fi

        if [ -n "$ALIAS_NAME" ]; then
            if [ ! -L $BINLOCATION/$ALIAS_NAME ]; then
                ln -s $BINLOCATION/$BINARY_NAME $BINLOCATION/$ALIAS_NAME
                >&2 say_white "Creating alias '$ALIAS_NAME' for '$BINARY_NAME'."
            fi
        fi

        ${CONFIG_CMD}

        chown -R $RUNNER_USERNAME ${HOME}/.dw-cli

        ${SUCCESS_CMD}
    fi
}

setup_dependencies() {
    TOOL_DEST="${HOME}/.dw-cli/tools"
    if [ -e $TOOL_DEST ]; then
        rm -rf $TOOL_DEST
    fi

    mkdir -p $TOOL_DEST

    tools=("adb" "scrcpy" "wget" "sshpass" "rsync")
    for tool in "${tools[@]}"; do
        ln -s $(which ${tool}) "${TOOL_DEST}/${tool}"
    done
}

check_and_install_package_manager
cleanup_existing_legacy_dw_installation
install_dependencies
setup_dependencies
download_dwcli
install_dwcli

# say_blue
# say_blue "=== dw-cli is now installed! ==="
