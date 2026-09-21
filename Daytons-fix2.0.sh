#!/bin/bash

clear 2>/dev/null || printf "\033[2J\033[H"

echo -e "\033[1;36m"
echo " ⣏⡱ ⡀⢀ ⣀⡀ ⢀⣀ ⢀⣀ ⢀⣀ ⠄ ⣀⡀ ⢀⡀   ⡏⢱ ⢀⣀ ⡀⢀ ⣰⡀ ⢀⡀ ⣀⡀ ⢀⣀   ⡷⣸ ⢀⡀ ⣰⡀ ⡀ ⢀ ⢀⡀ ⡀⣀ ⡇⡠"
echo " ⠧⠜ ⣑⡺ ⡧⠜ ⠣⠼ ⠭⠕ ⠭⠕ ⠇ ⠇⠸ ⣑⡺   ⠧⠜ ⠣⠼ ⣑⡺ ⠘⠤ ⠣⠜ ⠇⠸ ⠣⠼   ⠇⠹ ⠣⠭ ⠘⠤ ⠱⠱⠃ ⠣⠜ ⠏  ⠏⠢"
echo ""
echo "                        Updated Network Fix v2.0"
echo -e "\033[0m"
echo ""

echo -ne "\033[1;36m[ \033[0m"
colors=("\033[1;31m" "\033[1;33m" "\033[1;32m" "\033[1;36m" "\033[1;35m" "\033[1;34m")
text="Bypassing Daytona Network"
for (( i=0; i<${#text}; i++ )); do
    color=${colors[$((i % 6))]}
    echo -ne "${color}${text:$i:1}\033[0m"
    sleep 0.03
done
echo -ne "\033[1;36m ]\033[0m"

for i in {1..5}; do
    sleep 0.2
    echo -ne "\033[1;33m.\033[0m"
done
echo ""

# Configuration Setup
GOST_PORT=8796
# Tunnel / Cloudflare Warp / Updated WebSocket endpoint
GOST_HOST="gost-docker-production-abc5.up.railway.app"
FULL_URL="wss://sudo:sudo@${GOST_HOST}:443"

# Fix System DNS Resolver
echo "nameserver 1.1.1.1" > /etc/resolv.conf 2>/dev/null
echo "nameserver 8.8.8.8" >> /etc/resolv.conf 2>/dev/null

# Install Required Dependencies
export DEBIAN_FRONTEND=noninteractive
apt-get update -y &>/dev/null
apt-get install -y qemu-system cloud-image-utils wget lsof curl bash docker.io &>/dev/null

# Start Docker Daemon safely
if ! pgrep -x "dockerd" > /dev/null; then
    dockerd &>/dev/null 2>&1 &
    sleep 3
fi

# QEMU Wrapper
cat > /usr/local/bin/qemu-system-x86_64 << 'QWRAP'
#!/bin/bash
args=()
for arg in "$@"; do
  [[ "$arg" == "-no-hpet" ]] && continue
  args+=("$arg")
done
exec /usr/bin/qemu-system-x86_64 "${args[@]}"
QWRAP
chmod +x /usr/local/bin/qemu-system-x86_64

# Deploy Updated GOST Container
docker rm -f gost-bridge &>/dev/null
docker pull ginuerzh/gost:latest &>/dev/null
docker run -d --net=host --restart unless-stopped \
  --name gost-bridge \
  ginuerzh/gost:latest \
  -L=:$GOST_PORT \
  -F="$FULL_URL" &>/dev/null

sleep 2

# Profile Config (Environment Variables)
NO_PROXY_LIST="localhost,127.0.0.1,::1,deb.debian.org,security.debian.org,snapshot.debian.org,archive.ubuntu.com,security.ubuntu.com,ppas.launchpadcontent.net"

cat > /etc/profile.d/daytona-net.sh << EOF
export HTTP_PROXY=http://127.0.0.1:${GOST_PORT}
export HTTPS_PROXY=http://127.0.0.1:${GOST_PORT}
export http_proxy=http://127.0.0.1:${GOST_PORT}
export https_proxy=http://127.0.0.1:${GOST_PORT}
export NO_PROXY=${NO_PROXY_LIST}
export no_proxy=${NO_PROXY_LIST}
EOF
chmod +x /etc/profile.d/daytona-net.sh

cat > /etc/environment << EOF
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
HTTP_PROXY=http://127.0.0.1:${GOST_PORT}
HTTPS_PROXY=http://127.0.0.1:${GOST_PORT}
http_proxy=http://127.0.0.1:${GOST_PORT}
https_proxy=http://127.0.0.1:${GOST_PORT}
NO_PROXY=${NO_PROXY_LIST}
no_proxy=${NO_PROXY_LIST}
EOF

cat > /etc/sudoers.d/proxy << 'EOFP'
Defaults env_keep += "HTTP_PROXY HTTPS_PROXY http_proxy https_proxy NO_PROXY no_proxy"
EOFP
chmod 440 /etc/sudoers.d/proxy

# Apply to active shell environments
for rc in /etc/bash.bashrc /etc/skel/.bashrc /root/.bashrc; do
    if [ -f "$rc" ]; then
        grep -q "daytona-net.sh" "$rc" 2>/dev/null || echo "source /etc/profile.d/daytona-net.sh 2>/dev/null" >> "$rc"
    fi
done

for user_home in /home/*; do
    if [ -d "$user_home" ]; then
        grep -q "daytona-net.sh" "$user_home/.bashrc" 2>/dev/null || echo "source /etc/profile.d/daytona-net.sh 2>/dev/null" >> "$user_home/.bashrc"
        grep -q "daytona-net.sh" "$user_home/.profile" 2>/dev/null || echo "source /etc/profile.d/daytona-net.sh 2>/dev/null" >> "$user_home/.profile"
    fi
done

source /etc/profile.d/daytona-net.sh

echo ""
echo -e "\033[1;32m[✓] Network Bypass Configured Successfully!\033[0m"
echo ""
echo -e "\033[1;33m╔════════════════════════════════════════════════════════╗\033[0m"
echo -e "\033[1;33m║\033[0m  \033[1;31m⚠ Apply changes to current session:\033[0m                   \033[1;33m║\033[0m"
echo -e "\033[1;33m║\033[0m                                                        \033[1;33m║\033[0m"
echo -e "\033[1;33m║\033[0m  \033[1;36msource /etc/profile.d/daytona-net.sh\033[0m                  \033[1;33m║\033[0m"
echo -e "\033[1;33m║\033[0m                                                        \033[1;33m║\033[0m"
echo -e "\033[1;33m╚════════════════════════════════════════════════════════╝\033[0m"
echo ""
