#!/bin/bash

function install_sshpass() {
    echo "[+] Installing sshpass"
    brew install esolitos/ipa/sshpass
}

function install_rsync() {
    echo "[+] Installing rsync"
    brew install rsync
}

function install_dwcli() {
    echo "[+] Installing dw-cli"
    curl -LO https://github.com/dashwave/toolkits/releases/download/v0.0.1-alpha/dw
    chmod 755 ./dw
    mv ./dw /usr/local/bin/
}

install_sshpass
install_rsync
install_dwcli
