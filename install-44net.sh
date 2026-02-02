#!/bin/bash

#==============================================================================
# 44Net Connect WireGuard Installation Script
# 
# This script automates the installation and configuration of WireGuard
# for use with ARDC's 44Net Connect service.
#
# Security Note: Your private key is only written to the local WireGuard
# configuration file (/etc/wireguard/wg0.conf) which is protected with
# root-only permissions (600). This script does not transmit your private
# key anywhere or store it in any other location.
#
# Author: Amateur Radio Community
# License: MIT
#==============================================================================

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Function to detect OS and install WireGuard
install_wireguard() {
    print_info "Detecting operating system..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        print_error "Cannot detect OS. Please install WireGuard manually."
        exit 1
    fi
    
    print_info "Detected OS: $OS $VERSION"
    
    # Check if WireGuard is already installed
    if command -v wg &> /dev/null; then
        print_success "WireGuard is already installed"
        return 0
    fi
    
    print_info "Installing WireGuard..."
    
    case $OS in
        debian|ubuntu|raspbian)
            apt-get update
            apt-get install -y wireguard wireguard-tools resolvconf
            ;;
        fedora|centos|rhel)
            if [ "$OS" = "fedora" ]; then
                dnf install -y wireguard-tools
            else
                yum install -y epel-release
                yum install -y wireguard-tools
            fi
            ;;
        arch)
            pacman -Sy --noconfirm wireguard-tools
            ;;
        *)
            print_error "Unsupported OS: $OS"
            print_info "Please install WireGuard manually from: https://www.wireguard.com/install/"
            exit 1
            ;;
    esac
    
    # Verify installation
    if command -v wg &> /dev/null; then
        print_success "WireGuard installed successfully"
    else
        print_error "WireGuard installation failed"
        exit 1
    fi
}

# Function to prompt for configuration details
get_configuration() {
    echo ""
    print_info "Please provide your 44Net Connect configuration details"
    print_info "You can find these at: https://connect.44net.cloud/"
    echo ""
    
    # Private Key
    print_warning "SECURITY NOTE: Your private key will only be saved to /etc/wireguard/wg0.conf"
    print_warning "This file will have permissions set to 600 (root read/write only)"
    print_warning "Your key will NOT be transmitted anywhere or logged by this script"
    echo ""
    read -sp "Enter your WireGuard Private Key: " PRIVATE_KEY
    echo ""
    
    if [ -z "$PRIVATE_KEY" ]; then
        print_error "Private key cannot be empty"
        exit 1
    fi
    
    # IPv6 Address
    echo ""
    print_info "Enter your IPv6 address (example: fe80::4ac6:b6a1:3998:2ec1/128)"
    read -p "IPv6 Address: " IPV6_ADDR
    
    # IPv4 Address
    echo ""
    print_info "Enter your 44Net IPv4 address (example: 44.27.133.79/32)"
    read -p "IPv4 Address: " IPV4_ADDR
    
    if [ -z "$IPV4_ADDR" ]; then
        print_error "IPv4 address cannot be empty"
        exit 1
    fi
 
    # MTU (with default)
    echo ""
    print_info "Enter MTU value (default: 1380)"
    read -p "MTU: " MTU
    MTU=${MTU:-1380}
    
    # Peer Public Key
    echo ""
    print_info "Enter the 44Net Connect server public key"
    print_info "(example: PxVe0R15aG7ZraLIXgzkz96/yEzHXFce3rtH8XOCTCc=)"
    read -p "Server Public Key: " PEER_PUBLIC_KEY
    
    if [ -z "$PEER_PUBLIC_KEY" ]; then
        print_error "Server public key cannot be empty"
        exit 1
    fi
    
    # Endpoint
    echo ""
    print_info "Enter the 44Net Connect server endpoint (default: 44.27.228.1:44000)"
    read -p "Endpoint: " ENDPOINT
    ENDPOINT=${ENDPOINT:-44.27.228.1:44000}
    
    # PersistentKeepalive (with default)
    echo ""
    print_info "Enter PersistentKeepalive interval in seconds (default: 20)"
    print_info "This prevents the connection from timing out (recommended: 15-25)"
    read -p "PersistentKeepalive: " KEEPALIVE
    KEEPALIVE=${KEEPALIVE:-20}
    
    # AllowedIPs
    echo ""
    print_info "Enter AllowedIPs (default: 0.0.0.0/0, ::/0 for full tunnel)"
    print_info "Use '44.0.0.0/8' for split tunnel (only 44Net traffic)"
    read -p "AllowedIPs: " ALLOWED_IPS
    ALLOWED_IPS=${ALLOWED_IPS:-0.0.0.0/0, ::/0}
}

# Function to create WireGuard configuration
create_config() {
    print_info "Creating WireGuard configuration..."
    
    local CONFIG_FILE="/etc/wireguard/wg0.conf"
    
    # Backup existing config if present
    if [ -f "$CONFIG_FILE" ]; then
        print_warning "Existing configuration found, creating backup..."
        cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Build address line
    local ADDRESS_LINE="Address = "
    if [ -n "$IPV6_ADDR" ]; then
        ADDRESS_LINE="${ADDRESS_LINE}${IPV6_ADDR}, ${IPV4_ADDR}"
    else
        ADDRESS_LINE="${ADDRESS_LINE}${IPV4_ADDR}"
    fi
    
    # Create configuration file
    cat > "$CONFIG_FILE" << EOF
[Interface]
PrivateKey = ${PRIVATE_KEY}
${ADDRESS_LINE}
MTU = ${MTU}

[Peer]
PublicKey = ${PEER_PUBLIC_KEY}
Endpoint = ${ENDPOINT}
PersistentKeepalive = ${KEEPALIVE}
AllowedIPs = ${ALLOWED_IPS}
EOF
    
    # Set secure permissions (root read/write only)
    chmod 600 "$CONFIG_FILE"
    
    print_success "Configuration file created at: $CONFIG_FILE"
    print_success "File permissions set to 600 (root only)"
}

# Function to enable and start WireGuard service
start_service() {
    print_info "Starting WireGuard service..."
    
    # Enable IP forwarding (required for routing)
    sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1 || true
    sysctl -w net.ipv6.conf.all.forwarding=1 > /dev/null 2>&1 || true
    
    # Make IP forwarding persistent
    if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null; then
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    fi
    
    # Stop any running instance
    systemctl stop wg-quick@wg0 2>/dev/null || true
    
    # Start the service
    if systemctl start wg-quick@wg0; then
        print_success "WireGuard service started successfully"
    else
        print_error "Failed to start WireGuard service"
        print_info "Check logs with: journalctl -u wg-quick@wg0 -xe"
        exit 1
    fi
    
    # Enable on boot
    if systemctl enable wg-quick@wg0; then
        print_success "WireGuard service enabled to start on boot"
    else
        print_warning "Failed to enable service on boot"
    fi
}

# Function to test the connection
test_connection() {
    print_info "Testing 44Net connectivity..."
    echo ""
    
    sleep 3  # Give the tunnel a moment to establish
    
    # Show interface status
    print_info "WireGuard interface status:"
    wg show
    echo ""
    
    # Test connectivity to 44Net gateway
    print_info "Testing connection to 44Net gateway (44.27.228.1)..."
    if ping -c 4 -W 5 44.27.228.1 > /dev/null 2>&1; then
        print_success "Successfully connected to 44Net!"
        echo ""
        ping -c 4 44.27.228.1
    else
        print_error "Cannot reach 44Net gateway"
        print_info "This may be normal if the gateway is temporarily unreachable"
        print_info "Try: ping 44.27.228.1"
    fi
    
    echo ""
    
    # Extract and display the assigned IP
    local ASSIGNED_IP=$(ip addr show wg0 2>/dev/null | grep "inet " | awk '{print $2}' | grep "^44\.")
    if [ -n "$ASSIGNED_IP" ]; then
        print_success "Your 44Net IP address: $ASSIGNED_IP"
    fi
}

# Function to display final instructions
show_completion_message() {
    echo ""
    echo "========================================================================"
    print_success "44Net Connect Installation Complete!"
    echo "========================================================================"
    echo ""
    print_info "Useful commands:"
    echo "  - Check tunnel status:     sudo wg show"
    echo "  - Restart service:         sudo systemctl restart wg-quick@wg0"
    echo "  - Stop service:            sudo systemctl stop wg-quick@wg0"
    echo "  - View logs:               sudo journalctl -u wg-quick@wg0 -f"
    echo "  - Test connectivity:       ping 44.27.228.1"
    echo ""
    print_info "Configuration file: /etc/wireguard/wg0.conf"
    echo ""
    print_info "Your 44Net services are now accessible via your assigned IP address"
    print_info "Remember to configure your applications to bind to your 44Net address"
    echo ""
    echo "========================================================================"
}

# Main installation flow
main() {
    echo "========================================================================"
    echo "    44Net Connect WireGuard Installation Script"
    echo "========================================================================"
    echo ""
    
    check_root
    install_wireguard
    get_configuration
    create_config
    start_service
    test_connection
    show_completion_message
}

# Run main function
main
