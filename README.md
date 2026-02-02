# 44Net Connect WireGuard Installer

Automated installation script for connecting to ARDC's 44Net (Amateur Radio Digital Communications) network using WireGuard VPN.

## What is 44Net Connect?

44Net Connect is ARDC's official service that provides amateur radio operators with IPv4 addresses in the 44.0.0.0/8 range for radio experimentation and digital communications. This installer automates the WireGuard VPN setup required to access the 44Net network.

## Prerequisites

- A valid amateur radio license (required to register with ARDC)
- 44Net Connect account and configuration from https://connect.44net.cloud/
- Linux-based system (Debian, Ubuntu, Raspbian, Fedora, CentOS, Arch)
- Root/sudo access

## Supported Operating Systems

- Debian 10+
- Ubuntu 18.04+
- Raspbian/Raspberry Pi OS
- Fedora
- CentOS/RHEL
- Arch Linux

## Quick Start

Run this single command to install and configure 44Net Connect:

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/44net-connect-installer/main/install-44net.sh | sudo bash
```

Alternatively, download and run manually:

```bash
wget https://raw.githubusercontent.com/YOUR_USERNAME/44net-connect-installer/main/install-44net.sh
chmod +x install-44net.sh
sudo ./install-44net.sh
```

## What the Script Does

1. Detects your operating system
2. Installs WireGuard and required dependencies
3. Prompts you for your 44Net Connect configuration details
4. Creates a secure WireGuard configuration file at `/etc/wireguard/wg0.conf`
5. Sets proper file permissions (600 - root read/write only)
6. Starts the WireGuard service
7. Enables automatic startup on boot
8. Tests connectivity to the 44Net network

## Configuration Information Needed

Before running the script, log into https://connect.44net.cloud/ and gather the following information from your configuration page:

- **Private Key** - Your WireGuard private key (keep this secret)
- **IPv6 Address** - Example: fe80::4ac6:b6a1:3998:2ec1/128
- **IPv4 Address** - Your assigned 44Net address (Example: 44.27.133.79/32)
- **Server Public Key** - The 44Net Connect server's public key
- **Endpoint** - Server address (typically 44.27.228.1:44000)

## Security Notes

### Private Key Handling

Your WireGuard private key is sensitive information. This script handles it securely:

- The private key is only written to `/etc/wireguard/wg0.conf`
- The configuration file is set to permissions 600 (readable/writable only by root)
- Your private key is NOT transmitted over the network by this script
- Your private key is NOT logged or stored anywhere else
- The script does not send your configuration to any external services

### What Gets Transmitted

- During WireGuard operation, only encrypted tunnel traffic is sent to 44Net Connect servers
- The server only sees your public key (which is safe to share)
- All amateur radio traffic through the tunnel uses standard WireGuard encryption

### Verifying Script Integrity

Before running any script with sudo, you should review it:

```bash
# Download the script
wget https://raw.githubusercontent.com/YOUR_USERNAME/44net-connect-installer/main/install-44net.sh

# Review the contents
less install-44net.sh

# Run it after you're satisfied
chmod +x install-44net.sh
sudo ./install-44net.sh
```

## Usage Examples

### Check Tunnel Status

```bash
sudo wg show
```

Expected output shows interface, peer, and recent handshake:
```
interface: wg0
  public key: YOUR_PUBLIC_KEY
  private key: (hidden)
  listening port: XXXXX

peer: SERVER_PUBLIC_KEY
  endpoint: 44.27.228.1:44000
  allowed ips: 0.0.0.0/0, ::/0
  latest handshake: 15 seconds ago
  transfer: 1.23 MiB received, 2.34 MiB sent
  persistent keepalive: every 20 seconds
```

### Test Connectivity

```bash
# Ping the 44Net gateway
ping 44.27.228.1

# Ping your own 44Net address (replace with your IP)
ping 44.27.133.79
```

### Restart the Service

```bash
sudo systemctl restart wg-quick@wg0
```

### View Logs

```bash
# View recent logs
sudo journalctl -u wg-quick@wg0 -n 50

# Follow logs in real-time
sudo journalctl -u wg-quick@wg0 -f
```

### Stop the Service

```bash
sudo systemctl stop wg-quick@wg0
```

### Start the Service

```bash
sudo systemctl start wg-quick@wg0
```

## Configuration File Location

The WireGuard configuration is stored at:

```
/etc/wireguard/wg0.conf
```

File permissions are automatically set to 600 (root only).

## Customization Options

### Split Tunnel vs Full Tunnel

By default, the script configures a full tunnel (all traffic through WireGuard). During installation, you can choose:

**Full Tunnel** (default):
```
AllowedIPs = 0.0.0.0/0, ::/0
```

**Split Tunnel** (only 44Net traffic):
```
AllowedIPs = 44.0.0.0/8
```

To change after installation, edit `/etc/wireguard/wg0.conf` and restart the service.

### Adjusting PersistentKeepalive

The keepalive interval prevents the tunnel from timing out. Default is 20 seconds.

For cellular/mobile connections, you may want to reduce this to 15 seconds:

```bash
sudo nano /etc/wireguard/wg0.conf
```

Change:
```
PersistentKeepalive = 20
```

To:
```
PersistentKeepalive = 15
```

Then restart:
```bash
sudo systemctl restart wg-quick@wg0
```

## Troubleshooting

### Connection Times Out

Check the handshake time:

```bash
sudo wg show
```

If "latest handshake" is more than 30-40 seconds ago, the tunnel may be having issues.

Solutions:
- Restart the service: `sudo systemctl restart wg-quick@wg0`
- Check your internet connection
- Verify your configuration details are correct
- Lower PersistentKeepalive to 15 seconds

### Cannot Reach 44Net Gateway

```bash
ping 44.27.228.1
```

If this fails:
- Check if WireGuard is running: `sudo systemctl status wg-quick@wg0`
- Check the tunnel has a recent handshake: `sudo wg show`
- Verify your endpoint is correct in the config
- Check firewall rules: `sudo iptables -L -n`

### Service Fails to Start

View detailed error logs:

```bash
sudo journalctl -u wg-quick@wg0 -xe
```

Common issues:
- Incorrect private key format
- Invalid IP address format
- Port conflicts (rare)
- Missing dependencies

### Firewall Issues

If you have a firewall enabled, you may need to allow UDP traffic:

```bash
# For iptables
sudo iptables -A INPUT -p udp --dport 51820 -j ACCEPT
sudo iptables -A OUTPUT -p udp --dport 44000 -j ACCEPT

# For UFW
sudo ufw allow 51820/udp
sudo ufw allow out 44000/udp
```

## Mobile/Cellular Usage

This setup works great for mobile amateur radio operations (hotspots, nodes in vehicles, portable stations).

The PersistentKeepalive setting ensures the tunnel stays connected even when moving between cell towers or when NAT mappings change.

For best mobile performance:
- Set PersistentKeepalive to 15-20 seconds
- Use split tunnel (AllowedIPs = 44.0.0.0/8) to avoid routing all mobile data through the VPN
- Configure your amateur radio software to bind to your 44Net address

## Uninstalling

To remove the WireGuard configuration:

```bash
# Stop and disable the service
sudo systemctl stop wg-quick@wg0
sudo systemctl disable wg-quick@wg0

# Remove configuration
sudo rm /etc/wireguard/wg0.conf

# Optionally remove WireGuard (Debian/Ubuntu)
sudo apt remove wireguard
```

## Getting Help

- 44Net Connect Portal: https://connect.44net.cloud/
- ARDC Website: https://www.ardc.net/
- Amateur Radio Digital Communications: https://www.ampr.org/

## Common Use Cases

### AllStarLink Nodes

Configure your AllStarLink node to bind to your 44Net address for incoming connections that work even behind NAT.

### DMR Hotspots

Make your DMR hotspot accessible via a persistent 44Net address regardless of your underlying internet connection.

### Repeater Linking

Connect repeaters using stable 44Net addresses instead of dynamic residential IPs.

### Remote Station Access

Access your home station remotely using your 44Net address.

## Contributing

Contributions are welcome! Please submit issues and pull requests on GitHub.

## License

MIT License - See LICENSE file for details

## Disclaimer

This script is provided as-is for amateur radio experimentation. Users are responsible for complying with all applicable amateur radio regulations and ARDC terms of service.

## Author

Created by the amateur radio community for educational and experimental purposes.

73 (Best regards in amateur radio tradition)
