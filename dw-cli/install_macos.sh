#!/bin/bash

function install_sshpass() {
    brew install esolitos/ipa/sshpass
}

function install_rsync() {
    brew install rsync
}

function install_dwcli() {
    curl -LO https://github.com/dashwave/toolkits/releases/download/v0.0.1-alpha/dw
    mv ./dw /usr/local/bin/
}

install_sshpass
install_rsync
install_dwcli