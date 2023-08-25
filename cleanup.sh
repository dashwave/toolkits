#!/bin/bash

set -e

RESET="\\033[0m"
RED="\\033[31;1m"
GREEN="\\033[32;1m"
YELLOW="\\033[33;1m"
BLUE="\\033[34;1m"
WHITE="\\033[37;1m"

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
        >&2 say_red "If you need help, feel free to react out to us on hello@dashwave.io"
    fi
}

trap at_exit EXIT

OS=""
case $(uname) in
    "Linux") OS="linux";;
    "Darwin") OS="darwin";;
    *)
        print_unsupported_platform
        exit 1
        ;;
esac

clean_existing_dw() {
    if [ $OS = "darwin" ]; then
        if command -v dw >/dev/null; then
            dw_location=$(which dw)

            echo $dw_location

            if [[ $dw_location == */usr/local/* ]]; then
                >&2 say_red "Non brew dw installation found in system, cleaning it up"
                >&2 say_white "We will need root access for the following command"
                >&2 say_white "sudo rm $(which dw)"
                sudo rm $(which dw)
                >&2 say_white "dw-cli cleaned up"
            fi
        fi
    fi
}

clean_legacy_config() {
    >&2 say_blue "Cleaning up legacy ~/.dw-cli/config.json in favour of newer config"
    rm -f ~/.dw-cli/config.json
}

outro_commands_message() {
    if [ $OS = "darwin" ]; then
        >&2 say_white "Please do run 'brew update' before installing newer dw"
        if command -v dw >/dev/null; then
            dw_location=$(which dw)

            if [[ $dw_location == */brew/* ]]; then
                >&2 say_white "Your system already has a brew dw-cli installation"
                >&2 say_white "Please run 'brew upgrade dw'"
            fi
        fi
    fi

    >&2 say_white "When everything is installed, please run 'dw config' and you are good to go!"
}

clean_existing_dw
clean_legacy_config
outro_commands_message
