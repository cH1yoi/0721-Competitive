#!/bin/bash

clear
function install_dependencies() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        echo "Unsupported operating system!"
    fi

    echo "Installing dependencies..."
    
    if [ "$OS" == "ubuntu" ]; then
        sudo dpkg --add-architecture i386
        sudo apt update
        sudo apt install -y lib32gcc-s1 lib32stdc++6 libsdl2-2.0-0:i386 zlib1g:i386 
    elif [ "$OS" == "debian" ]; then
        sudo dpkg --add-architecture i386
        sudo apt update
        sudo apt install -y lib32gcc-s1 lib32stdc++6 zlib1g
    else
        echo "Unsupported operating system!"
    fi

    sudo apt install -y wget curl screen zip git rsync lib32z1 p7zip-full
}

install_dependencies
