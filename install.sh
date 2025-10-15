#!/usr/bin/env bash

set -e

BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            DISTRO=$ID
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        OS="windows"
        echo -e "Windows is not supported. This script is only tested on Linux systems."
        exit 1
    else
        echo -e "Unsupported operating system: $OSTYPE"
        exit 1
    fi
    echo -e "Detected OS: ${BOLD}${OS}${NC}"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

install_system_deps() {
    echo -e "Checking system dependencies..."

    local deps_needed=()

    for dep in git curl wget jq unzip file; do
        if ! command_exists "$dep"; then
            deps_needed+=("$dep")
        else
            echo -e "${BOLD}${dep}${NC} already installed"
        fi
    done

    if [ ${#deps_needed[@]} -eq 0 ]; then
        echo -e "All system dependencies installed"
        return
    fi

    echo -e "Installing: ${BOLD}${deps_needed[*]}${NC}"

    if [[ "$OS" == "linux" ]]; then
        if command_exists apt-get; then
            sudo apt-get update
            sudo apt-get install -y "${deps_needed[@]}" build-essential
        elif command_exists yum; then
            sudo yum install -y "${deps_needed[@]}" gcc make
        elif command_exists pacman; then
            sudo pacman -Sy --noconfirm "${deps_needed[@]}" base-devel
        else
            echo -e "Unsupported Linux package manager"
            exit 1
        fi
    elif [[ "$OS" == "macos" ]]; then
        if ! command_exists brew; then
            echo -e "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        brew install "${deps_needed[@]}"
    fi

    echo -e "System dependencies installed"
}

install_go() {
    if command_exists go && go version >/dev/null 2>&1; then
        echo -e "Go installed: ${DIM}$(go version)${NC}"
        return
    fi

    if [ -d "/usr/local/go" ] && [ -f "/usr/local/go/bin/go" ]; then
        export PATH=$PATH:/usr/local/go/bin
        if command_exists go && go version >/dev/null 2>&1; then
            echo -e "Go installed: ${DIM}$(go version)${NC}"
            return
        fi
    fi

    echo -e "Installing ${BOLD}Go${NC}..."

    GO_VERSION="1.21.5"
    ARCH=$(uname -m)
    GO_ARCH=""

    echo -e "System architecture: ${BOLD}${ARCH}${NC}"

    if command_exists file && [ -f /bin/bash ]; then
        FILE_ARCH=$(file -b /bin/bash)
        echo -e "Binary check: ${DIM}${FILE_ARCH}${NC}"
    fi

    if [[ "$OS" == "linux" ]]; then
        case "$ARCH" in
            x86_64)
                GO_ARCH="linux-amd64"
                ;;
            aarch64|arm64)
                GO_ARCH="linux-arm64"
                ;;
            armv6l)
                GO_ARCH="linux-armv6l"
                ;;
            armv7l|armv7)
                GO_ARCH="linux-armv6l"
                ;;
            i686|i386)
                GO_ARCH="linux-386"
                ;;
            *)
                echo -e "Unsupported architecture: $ARCH"
                return 1
                ;;
        esac
    elif [[ "$OS" == "macos" ]]; then
        if [[ "$ARCH" == "arm64" ]]; then
            GO_ARCH="darwin-arm64"
        else
            GO_ARCH="darwin-amd64"
        fi
    fi

    echo -e "Target Go package: ${BOLD}${GO_ARCH}${NC}"

    GO_URL="https://go.dev/dl/go${GO_VERSION}.${GO_ARCH}.tar.gz"
    echo -e "Downloading: ${DIM}${GO_URL}${NC}"

    if ! wget -q --show-progress "$GO_URL" -O /tmp/go.tar.gz 2>&1; then
        echo -e "Failed to download Go from $GO_URL"
        echo -e "Verify architecture and Go version availability"
        return 1
    fi

    if [ ! -f /tmp/go.tar.gz ]; then
        echo -e "Downloaded file not found"
        return 1
    fi

    FILE_SIZE=$(stat -c%s /tmp/go.tar.gz 2>/dev/null || stat -f%z /tmp/go.tar.gz 2>/dev/null)
    if [ "$FILE_SIZE" -lt 1000000 ]; then
        echo -e "Downloaded file too small (${FILE_SIZE} bytes)"
        echo -e "This might indicate a 404 or invalid architecture"
        rm /tmp/go.tar.gz
        return 1
    fi

    echo -e "Downloaded ${FILE_SIZE} bytes"

    if ! tar -tzf /tmp/go.tar.gz >/dev/null 2>&1; then
        echo -e "Downloaded file is corrupted"
        rm /tmp/go.tar.gz
        return 1
    fi

    echo -e "Extracting Go to /usr/local..."
    sudo tar -C /usr/local -xzf /tmp/go.tar.gz
    export PATH=$PATH:/usr/local/go/bin

    rm /tmp/go.tar.gz

    if ! grep -q "/usr/local/go/bin" ~/.bashrc 2>/dev/null; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    fi
    if ! grep -q '$HOME/go/bin' ~/.bashrc 2>/dev/null; then
        echo 'export PATH=$PATH:$HOME/go/bin' >> ~/.bashrc
    fi

    export GOPATH=$HOME/go
    export PATH=$PATH:$GOPATH/bin

    if command_exists go && go version >/dev/null 2>&1; then
        echo -e "Go installed: ${DIM}$(go version)${NC}"
    else
        echo -e "Go installation failed - binary not executable"

        if [ -f /usr/local/go/bin/go ]; then
            BINARY_TYPE=$(file /usr/local/go/bin/go 2>&1)
            echo -e "Binary type: ${BINARY_TYPE}"
        fi

        echo -e "Architecture mismatch for: ${ARCH}"
        echo -e "Try manual installation from: ${DIM}https://go.dev/dl/${NC}"
        return 1
    fi
}

install_rust() {
    if command_exists cargo && cargo --version >/dev/null 2>&1; then
        echo -e "Rust installed: ${DIM}$(cargo --version)${NC}"
        return
    fi

    if [ -f "$HOME/.cargo/env" ]; then
        source "$HOME/.cargo/env"
        if command_exists cargo && cargo --version >/dev/null 2>&1; then
            echo -e "Rust installed: ${DIM}$(cargo --version)${NC}"
            return
        fi
    fi

    echo -e "Installing ${BOLD}Rust${NC}..."

    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"

    if ! grep -q ".cargo/env" ~/.bashrc 2>/dev/null; then
        echo 'source "$HOME/.cargo/env"' >> ~/.bashrc
    fi

    echo -e "Rust installed: ${DIM}$(cargo --version)${NC}"
}

install_python() {
    if command_exists python3; then
        echo -e "Python3 installed: ${DIM}$(python3 --version)${NC}"
    else
        echo -e "Installing ${BOLD}Python3${NC}..."

        if [[ "$OS" == "linux" ]]; then
            if command_exists apt-get; then
                sudo apt-get install -y python3 python3-pip python3-venv pipx
            elif command_exists yum; then
                sudo yum install -y python3 python3-pip
            elif command_exists pacman; then
                sudo pacman -S --noconfirm python python-pip
            fi
        elif [[ "$OS" == "macos" ]]; then
            brew install python3
        fi

        echo -e "Python3 installed: ${DIM}$(python3 --version)${NC}"
    fi

    if [[ "$DISTRO" == "kali" ]] || [[ "$DISTRO" == "debian" ]] || [[ "$DISTRO" == "ubuntu" ]]; then
        if ! command_exists pipx; then
            echo -e "Installing pipx for Python tools..."
            sudo apt-get install -y pipx python3-venv
            pipx ensurepath >/dev/null 2>&1
        fi
    fi
}

install_massdns() {
    if command_exists massdns; then
        echo -e "${BOLD}massdns${NC} already installed"
        return
    fi

    echo -e "Installing ${BOLD}massdns${NC}..."

    CURRENT_DIR=$(pwd)
    TEMP_DIR=$(mktemp -d)

    cd "$TEMP_DIR" || {
        echo -e "Failed to create temp directory"
        return 1
    }

    git clone https://github.com/blechschmidt/massdns.git || {
        echo -e "Failed to clone massdns"
        cd "$CURRENT_DIR"
        rm -rf "$TEMP_DIR"
        return 1
    }

    cd massdns || {
        echo -e "Failed to enter massdns directory"
        cd "$CURRENT_DIR"
        rm -rf "$TEMP_DIR"
        return 1
    }

    if ! make >/dev/null 2>&1; then
        echo -e "Failed to build massdns"
        cd "$CURRENT_DIR"
        rm -rf "$TEMP_DIR"
        return 1
    fi

    sudo make install || sudo cp bin/massdns /usr/local/bin/

    cd "$CURRENT_DIR"
    rm -rf "$TEMP_DIR"

    if command_exists massdns; then
        echo -e "${BOLD}massdns${NC} installed"
    else
        echo -e "massdns installation failed"
        return 1
    fi
}

install_go_tools() {
    echo -e "Installing Go-based tools..."

    export PATH=$PATH:$HOME/go/bin

    if ! command_exists go; then
        echo -e "Go not found in PATH. Skipping Go tools installation."
        return 1
    fi

    declare -A go_tools=(
        ["subfinder"]="github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
        ["httpx"]="github.com/projectdiscovery/httpx/cmd/httpx@latest"
        ["tlsx"]="github.com/projectdiscovery/tlsx/cmd/tlsx@latest"
        ["katana"]="github.com/projectdiscovery/katana/cmd/katana@latest"
        ["chaos"]="github.com/projectdiscovery/chaos-client/cmd/chaos@latest"
        ["dnsx"]="github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
		["naabu"]="github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"
        ["assetfinder"]="github.com/tomnomnom/assetfinder@latest"
        ["getJS"]="github.com/003random/getJS/v2@latest"
        ["hakrawler"]="github.com/hakluke/hakrawler@latest"
        ["gowitness"]="github.com/sensepost/gowitness@latest"
    )

    for tool_name in "${!go_tools[@]}"; do
        if command_exists "$tool_name"; then
            echo -e "${BOLD}${tool_name}${NC} already installed"
        else
            echo -e "Installing ${BOLD}${tool_name}${NC}..."
            if ! go install -v "${go_tools[$tool_name]}" 2>&1; then
                echo -e "Failed to install ${BOLD}${tool_name}${NC}"
            fi
        fi
    done

    if command_exists shuffledns; then
        echo -e "${BOLD}shuffledns${NC} installed"
    else
        echo -e "Installing ${BOLD}shuffledns${NC}..."
        if ! go install -v "github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest" 2>&1; then
            echo -e "Failed to install ${BOLD}shuffledns${NC}"
        fi
    fi

    echo -e "Go-based tools installation complete"
}

ensure_pipx_path() {
    if [ -d "$HOME/.local/bin" ]; then
        export PATH="$HOME/.local/bin:$PATH"

        if ! grep -q '$HOME/.local/bin' ~/.bashrc 2>/dev/null; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
        fi
    fi
}

install_python_tools() {
    echo -e "Installing Python-based tools..."

    CURRENT_DIR=$(pwd)

    local USE_PIPX=false
    if [[ "$DISTRO" == "kali" ]] || [[ "$DISTRO" == "debian" ]] || [[ "$DISTRO" == "ubuntu" ]]; then
        if command_exists pipx; then
            USE_PIPX=true
            echo -e "Using pipx for Python tool installation"
            pipx ensurepath >/dev/null 2>&1
            ensure_pipx_path
        fi
    fi

   if command_exists waymore; then
    echo -e "${BOLD}waymore${NC} already installed"
	else
		echo -e "Installing ${BOLD}waymore${NC}..."
		if [ "$USE_PIPX" = true ]; then
			pipx install waymore || echo -e "Failed to install ${BOLD}waymore${NC}"
			ensure_pipx_path
		else
			pip3 install waymore || echo -e "Failed to install ${BOLD}waymore${NC}"
		fi
	fi


    if command_exists paramspider; then
        echo -e "${BOLD}paramspider${NC} already installed"
    elif [ -d "$HOME/paramspider" ]; then
        echo -e "${BOLD}paramspider${NC} directory exists, reinstalling..."
        cd "$HOME/paramspider" || {
            echo -e "Failed to enter paramspider directory"
            cd "$CURRENT_DIR"
            return 1
        }
        if [ "$USE_PIPX" = true ]; then
            pipx install . || echo -e "Failed to install ${BOLD}paramspider${NC}"
            ensure_pipx_path
        else
            pip3 install . || echo -e "Failed to install ${BOLD}paramspider${NC}"
        fi
        cd "$CURRENT_DIR"
    else
        echo -e "Installing ${BOLD}paramspider${NC}..."
        git clone https://github.com/devanshbatham/paramspider "$HOME/paramspider" || {
            echo -e "Failed to clone paramspider"
            return 1
        }
        cd "$HOME/paramspider" || {
            echo -e "Failed to enter paramspider directory"
            cd "$CURRENT_DIR"
            return 1
        }
        if [ "$USE_PIPX" = true ]; then
            pipx install . || echo -e "Failed to install ${BOLD}paramspider${NC}"
            ensure_pipx_path
        else
            pip3 install . || echo -e "Failed to install ${BOLD}paramspider${NC}"
        fi
        cd "$CURRENT_DIR"
    fi

    echo -e "Python-based tools installation complete"
}

install_findomain() {
    if command_exists findomain; then
        echo -e "${BOLD}findomain${NC} already installed"
        return
    fi

    echo -e "Installing ${BOLD}findomain${NC}..."

    if [[ "$OS" == "linux" ]]; then
        if [[ "$DISTRO" == "arch" || "$DISTRO" == "manjaro" || "$DISTRO" == "blackarch" ]] && command_exists pacman; then
            echo -e "Installing via pacman..."
            sudo pacman -S --noconfirm findomain && echo -e "${BOLD}findomain${NC} installed" && return
        elif [[ "$DISTRO" == "gentoo" || "$DISTRO" == "pentoo" ]] && command_exists emerge; then
            echo -e "Installing via emerge..."
            sudo emerge -a findomain && echo -e "${BOLD}findomain${NC} installed" && return
        elif command_exists nix-env; then
            echo -e "Installing via nix-env..."
            nix-env -iA findomain && echo -e "${BOLD}findomain${NC} installed" && return
        elif command_exists brew; then
            echo -e "Installing via Homebrew..."
            brew install findomain && echo -e "${BOLD}findomain${NC} installed" && return
        fi

        ARCH=$(uname -m)
        if [[ "$ARCH" == "x86_64" ]]; then
            echo -e "Installing precompiled binary for x86_64..."
            curl -LO https://github.com/findomain/findomain/releases/latest/download/findomain-linux.zip || {
                echo -e "Failed to download findomain"
                return 1
            }
            unzip -o findomain-linux.zip >/dev/null 2>&1
            chmod +x findomain
            sudo mv findomain /usr/bin/findomain
            rm -f findomain-linux.zip
        elif [[ "$ARCH" == "aarch64" ]]; then
            echo -e "Installing precompiled binary for aarch64..."
            curl -LO https://github.com/findomain/findomain/releases/latest/download/findomain-aarch64.zip || {
                echo -e "Failed to download findomain"
                return 1
            }
            unzip -o findomain-aarch64.zip >/dev/null 2>&1
            chmod +x findomain
            sudo mv findomain /usr/bin/findomain
            rm -f findomain-aarch64.zip
        elif [[ "$ARCH" == "armv7l" || "$ARCH" == "armv7" ]]; then
            echo -e "Installing precompiled binary for armv7..."
            curl -LO https://github.com/findomain/findomain/releases/latest/download/findomain-armv7.zip || {
                echo -e "Failed to download findomain"
                return 1
            }
            unzip -o findomain-armv7.zip >/dev/null 2>&1
            chmod +x findomain
            sudo mv findomain /usr/bin/findomain
            rm -f findomain-armv7.zip
        else
            echo -e "No precompiled binary for architecture: $ARCH"
            echo -e "Attempting to build from source..."

            if ! command_exists cargo; then
                echo -e "Rust/Cargo not installed. Cannot build from source."
                return 1
            fi

            TEMP_DIR=$(mktemp -d)
            cd "$TEMP_DIR" || {
                echo -e "Failed to create temp directory"
                return 1
            }
            git clone https://github.com/findomain/findomain.git || {
                echo -e "Failed to clone findomain"
                rm -rf "$TEMP_DIR"
                return 1
            }
            cd findomain || {
                echo -e "Failed to enter findomain directory"
                rm -rf "$TEMP_DIR"
                return 1
            }
            cargo build --release || {
                echo -e "Failed to build findomain from source"
                rm -rf "$TEMP_DIR"
                return 1
            }
            sudo cp target/release/findomain /usr/bin/
            rm -rf "$TEMP_DIR"
        fi

    elif [[ "$OS" == "macos" ]]; then
        if command_exists brew; then
            echo -e "Installing via Homebrew..."
            brew install findomain && echo -e "${BOLD}findomain${NC} installed" && return
        fi

        echo -e "Installing precompiled binary for macOS..."
        curl -LO https://github.com/findomain/findomain/releases/latest/download/findomain-osx.zip || {
            echo -e "Failed to download findomain"
            return 1
        }
        unzip -o findomain-osx.zip >/dev/null 2>&1
        chmod +x findomain.dms
        sudo mv findomain.dms /usr/local/bin/findomain
        rm -f findomain-osx.zip
    fi

    if command_exists findomain; then
        echo -e "${BOLD}findomain${NC} installed"
    else
        echo -e "findomain installation failed"
        echo -e "Manual installation guide: ${DIM}https://github.com/findomain/findomain${NC}"
        return 1
    fi
}

configure_api_keys() {
    echo -e "API Configuration..."
    echo -e "Chaos API key: ${DIM}https://chaos.projectdiscovery.io${NC}"
    read -p "Configure Chaos API key? (y/n): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter Chaos API key: " chaos_key

        if ! grep -q "CHAOS_API_KEY" ~/.bashrc 2>/dev/null; then
            echo "export CHAOS_API_KEY=\"$chaos_key\"" >> ~/.bashrc
        else
            sed -i.bak "s/export CHAOS_API_KEY=.*/export CHAOS_API_KEY=\"$chaos_key\"/" ~/.bashrc
        fi

        export CHAOS_API_KEY="$chaos_key"
        echo -e "Chaos API key configured"
    else
        echo -e "Skipped API configuration"
        echo -e "Configure later: ${DIM}export CHAOS_API_KEY=\"YOUR_API_KEY\" in ~/.bashrc${NC}"
    fi
}

verify_installation() {
    echo -e "Verifying installation..."

    declare -a required_tools=(
        "go" "git" "curl" "jq" "python3"
        "subfinder" "httpx" "tlsx" "katana" "chaos"
        "dnsx" "shuffledns" "massdns" "assetfinder" "getJS" "hakrawler"
        "gowitness" "findomain"
    )

    missing_tools=()

    for tool in "${required_tools[@]}"; do
        if ! command_exists "$tool"; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -eq 0 ]; then
        echo -e "All tools installed successfully"
    else
        echo -e "Missing tools:"
        for tool in "${missing_tools[@]}"; do
            echo -e "  ${BOLD}${tool}${NC}"
        done
    fi
}

finalize_installation() {
    echo -e "Finalizing installation..."

    ensure_pipx_path

    if [ -f ~/.bashrc ]; then
        source ~/.bashrc 2>/dev/null || true
    fi

    echo -e "Environment configured"
}

main() {
    detect_os

    read -p "Continue with installation? (y/n): " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "Installation cancelled"
        exit 0
    fi

    install_system_deps
    install_go
    install_rust
    install_python
    install_massdns
    install_go_tools
    install_python_tools
    install_findomain
    configure_api_keys
    verify_installation
    finalize_installation

    echo ""
    echo -e "Installation complete!"
    echo ""
    echo -e "Next steps:"
    echo -e "  ${DIM}./main.sh <domain> [options]${NC}"
    echo ""
}

main "$@"
