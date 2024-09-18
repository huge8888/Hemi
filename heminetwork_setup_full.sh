#!/bin/bash

# Exit on error
set -e

# Capture errors and display a message
trap 'echo "An error occurred, the script has exited.";' ERR

# Function: Prepare environment and install required dependencies
prepare_environment() {
    echo "Updating package list and installing necessary tools..."
    sudo apt update
    sudo apt install -y wget curl jq
    echo "Environment preparation complete."
}

# Function: Automatically install missing dependencies (git and make)
install_dependencies() {
    for cmd in git make; do
        if ! command -v $cmd &> /dev/null; then
            echo "$cmd is not installed, installing..."

            if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                sudo apt install -y $cmd
            elif [[ "$OSTYPE" == "darwin"* ]]; then
                brew install $cmd
            else
                echo "Unsupported OS, please install $cmd manually."
                exit 1
            fi
        fi
    done
    echo "Dependencies installed successfully."
}

# Function: Check if Go version is >= 1.22.2
check_go_version() {
    if command -v go >/dev/null 2>&1; then
        CURRENT_GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
        MINIMUM_GO_VERSION="1.22.2"

        if [ "$(printf '%s\n' "$MINIMUM_GO_VERSION" "$CURRENT_GO_VERSION" | sort -V | head -n1)" = "$MINIMUM_GO_VERSION" ]; then
            echo "Go version is sufficient: $CURRENT_GO_VERSION"
        else
            echo "Current Go version ($CURRENT_GO_VERSION) is below the required version, installing the latest Go."
            install_go
        fi
    else
        echo "Go not found, installing Go."
        install_go
    fi
}

install_go() {
    wget https://go.dev/dl/go1.22.2.linux-amd64.tar.gz
    sudo tar -C /usr/local -xzf go1.22.2.linux-amd64.tar.gz
    export PATH=$PATH:/usr/local/go/bin
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    source ~/.bashrc
    echo "Go installed successfully, version: $(go version)"
}

# Function 1: Download, extract, and generate address information
download_and_setup() {
    wget https://github.com/hemilabs/heminetwork/releases/download/v0.4.3/heminetwork_v0.4.3_linux_amd64.tar.gz -O heminetwork_v0.4.3_linux_amd64.tar.gz

    TARGET_DIR="$HOME/heminetwork"
    mkdir -p "$TARGET_DIR"

    tar -xvf heminetwork_v0.4.3_linux_amd64.tar.gz -C "$TARGET_DIR"

    mv "$TARGET_DIR/heminetwork_v0.4.3_linux_amd64/"* "$TARGET_DIR/"
    rmdir "$TARGET_DIR/heminetwork_v0.4.3_linux_amd64"

    cd "$TARGET_DIR"
    ./keygen -secp256k1 -json -net="testnet" > ~/popm-address.json

    echo "Address file generated successfully."
}

# Function 2: Create Wallet and Fix Environment Variables
setup_environment() {
    if [[ ! -f ~/popm-address.json ]]; then
        echo "Address file not found, please generate the address file first."
        exit 1
    fi

    cd "$HOME/heminetwork"
    cat ~/popm-address.json

    POPM_BTC_PRIVKEY=$(jq -r '.private_key' ~/popm-address.json)
    export POPM_BTC_PRIVKEY=$POPM_BTC_PRIVKEY
    echo "export POPM_BTC_PRIVKEY=$POPM_BTC_PRIVKEY" >> ~/.bashrc

    export POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public
    echo "export POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public" >> ~/.bashrc

    change_static_fee

    echo "Environment variables set."
    source ~/.bashrc
}

# Function to change POPM_STATIC_FEE
change_static_fee() {
    read -p "Enter sats/vB value: " POPM_STATIC_FEE
    export POPM_STATIC_FEE=$POPM_STATIC_FEE
    echo "export POPM_STATIC_FEE=$POPM_STATIC_FEE" >> ~/.bashrc
    source ~/.bashrc
    echo "POPM_STATIC_FEE has been set to $POPM_STATIC_FEE."
}

# Function to edit popm-address.json
edit_popm_address() {
    if [[ -f ~/popm-address.json ]]; then
        echo "Opening popm-address.json for editing..."
        nano ~/popm-address.json
        echo "popm-address.json edited successfully."
        # Re-apply environment variables after editing
        setup_environment
    else
        echo "Address file not found."
    fi
}

# Function 3: Start popmd (using nohup)
start_popmd() {
    cd "$HOME/heminetwork"
    nohup ./popmd > popmd.log 2>&1 &
    echo "popmd started, logs are saved in popmd.log."
}

# Function 4: View logs
view_logs() {
    cd "$HOME/heminetwork"
    tail -f popmd.log
}

# Function 5: Backup address information
backup_address() {
    if [[ -f ~/popm-address.json ]]; then
        echo "Please save the following address file information:"
        cat ~/popm-address.json
    else
        echo "Address file not found."
    fi
}

# Function: Print credits
print_credits() {
    cat << "EOF"
+--------------------------------------------+
|                0 x H U G E                 |
|                                            |
+--------------------------------------------+
EOF
    echo "Script Author: 0xHUGE"
    echo "GitHub: https://github.com/huge8888"
    echo "Follow on Twitter: https://x.com/0xHuge"
    echo "======================================="
}

# Main Menu
main_menu() {
    while true; do
        clear
        print_credits
        echo "===== Heminetwork Management Menu ====="
        echo "1. Prepare Environment and Install Heminetwork"
        echo "2. Create Wallet"
        echo "3. Start popmd"
        echo "4. View Logs"
        echo "5. Backup Address Information"
        echo "6. Change POPM_STATIC_FEE"
        echo "7. Change Wallet"
        echo "8. Exit"
        echo "======================================="
        echo "Select an option:"

        read -p "Enter choice (1-8): " choice

        case $choice in
            1)
                prepare_environment
                install_dependencies
                check_go_version
                download_and_setup
                ;;
            2)
                setup_environment
                ;;
            3)
                start_popmd
                ;;
            4)
                view_logs
                ;;
            5)
                backup_address
                ;;
            6)
                change_static_fee
                ;;
            7)
                edit_popm_address
                ;;
            8)
                echo "Exiting script."
                exit 0
                ;;
            *)
                echo "Invalid option, please try again."
                ;;
        esac
    done
}

# Start Main Menu
echo "Preparing to start the main menu..."
main_menu
