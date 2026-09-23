#!/bin/bash

clear 2>/dev/null || printf "\033[2J\033[H"

# Colors Definition
C_RESET="\033[0m"
C_CYAN="\033[1;36m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_RED="\033[1;31m"
C_MAGENTA="\033[1;35m"
C_BLUE="\033[1;34m"
C_DIM="\033[2m"

# Header UI
echo -e "${C_CYAN}"
cat << "EOF"
  _ _ ______ _______ ______ _____ _ __ ______ _______ __
 | \ | | ____|__ __| \ / / __ \| __ \| |/ / | ____|_ _\ \ / /
 | \| | |__ | | \ \ /\ / / | | | |__) | ' / | |__ | | \ V / 
 | . ` | __| | | \ V V /| | | | _ /| < | __| | | > <  
 | |\ | |____ | | \_/\_/ | |__| | | \ \| . \ | | | | / . \ 
 |_| \_|______| |_| \______/|_| \_\_|\_\ |_| |___|/_/ \_\
EOF
echo -e "${C_RESET}"
echo -e "${C_MAGENTA} ⚡ Made By Real Daddy G ⚡${C_RESET}"
echo ""

# Animated Status Function
print_step() {
    local text="$1"
    echo -ne "${C_CYAN}[✦] ${C_RESET}${text} "
    for i in {1..3}; do
        sleep 0.2
        echo -ne "${C_YELLOW}.${C_RESET}"
    done
    echo -e " ${C_GREEN}DONE${C_RESET}"
}

# Config
GOST_HOST="dfdfdfdfdf-production.up.railway.app"
GOST_PORT=8796
FULL_URL="wss://sudo:sudo@${GOST_HOST}:443"

# Docker Check & Init
print_step "Validating container engine"
command -v docker &>/dev/null || curl -fsSL https://get.docker.com | sh &>/dev/null 2>&1
dockerd &>/dev/null 2>&1 &
sleep 2

# Packages & Kernel Tooling
print_step "Installing core dependencies"
apt update -y &>/dev/null 2>&1
apt install -y qemu-system cloud-image-utils wget lsof curl bash &>/dev/null 2>&1

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

# Gost Bridge Service
print_step "Deploying encrypted bridge tunnel"
docker rm -f gost-bridge &>/dev/null 2>&1
docker pull ginuerzh/gost:latest &>/dev/null 2>&1
docker run -d --net=host --restart unless-stopped \
  --name gost-bridge \
  ginuerzh/gost:latest \
  -L=:$GOST_PORT \
  -F="$FULL_URL" &>/dev/null 2>&1
sleep 2

# Environment & Proxy Setup
print_step "Injecting global network routing profiles"

cat > /etc/profile.d/network-fix.sh << EOF
export HTTP_PROXY=http://127.0.0.1:${GOST_PORT}
export HTTPS_PROXY=http://127.0.0.1:${GOST_PORT}
export http_proxy=http://127.0.0.1:${GOST_PORT}
export https_proxy=http://127.0.0.1:${GOST_PORT}
export NO_PROXY=localhost,127.0.0.1,::1,deb.debian.org,security.debian.org,snapshot.debian.org,archive.ubuntu.com,security.ubuntu.com,ppas.launchpadcontent.net
export no_proxy=localhost,127.0.0.1,::1,deb.debian.org,security.debian.org,snapshot.debian.org,archive.ubuntu.com,security.ubuntu.com,ppas.launchpadcontent.net
EOF
chmod +x /etc/profile.d/network-fix.sh

cat > /etc/environment << 'EOF'
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
HTTP_PROXY=http://127.0.0.1:8796
HTTPS_PROXY=http://127.0.0.1:8796
http_proxy=http://127.0.0.1:8796
https_proxy=http://127.0.0.1:8796
NO_PROXY=localhost,127.0.0.1,::1,deb.debian.org,security.debian.org,snapshot.debian.org,archive.ubuntu.com,security.ubuntu.com,ppas.launchpadcontent.net
no_proxy=localhost,127.0.0.1,::1,deb.debian.org,security.debian.org,snapshot.debian.org,archive.ubuntu.com,security.ubuntu.com,ppas.launchpadcontent.net
EOF

cat > /etc/sudoers.d/proxy << 'EOFP'
Defaults env_keep += "HTTP_PROXY HTTPS_PROXY http_proxy https_proxy NO_PROXY no_proxy"
EOFP
chmod 440 /etc/sudoers.d/proxy

# Shell Hooks (Bash, Zsh, Fish)
for rc in /etc/bash.bashrc /etc/skel/.bashrc /root/.bashrc; do
    if [ -f "$rc" ]; then
        grep -q "network-fix.sh" "$rc" 2>/dev/null || echo "source /etc/profile.d/network-fix.sh 2>/dev/null" >> "$rc"
    fi
done

for user_home in /home/*; do
    if [ -d "$user_home" ]; then
        grep -q "network-fix.sh" "$user_home/.bashrc" 2>/dev/null || echo "source /etc/profile.d/network-fix.sh 2>/dev/null" >> "$user_home/.bashrc"
        grep -q "network-fix.sh" "$user_home/.profile" 2>/dev/null || echo "source /etc/profile.d/network-fix.sh 2>/dev/null" >> "$user_home/.profile"
    fi
done

if [ -f /etc/zsh/zshrc ]; then
    grep -q "network-fix.sh" /etc/zsh/zshrc 2>/dev/null || echo "source /etc/profile.d/network-fix.sh 2>/dev/null" >> /etc/zsh/zshrc
fi

mkdir -p /etc/fish/conf.d 2>/dev/null
cat > /etc/fish/conf.d/network-fix.fish << FISHCONF
set -gx HTTP_PROXY http://127.0.0.1:${GOST_PORT}
set -gx HTTPS_PROXY http://127.0.0.1:${GOST_PORT}
set -gx http_proxy http://127.0.0.1:${GOST_PORT}
set -gx https_proxy http://127.0.0.1:${GOST_PORT}
set -gx NO_PROXY localhost,127.0.0.1,::1,deb.debian.org,security.debian.org,snapshot.debian.org,archive.ubuntu.com,security.ubuntu.com,ppas.launchpadcontent.net
set -gx no_proxy localhost,127.0.0.1,::1,deb.debian.org,security.debian.org,snapshot.debian.org,archive.ubuntu.com,security.ubuntu.com,ppas.launchpadcontent.net
FISHCONF

# Persistence Setup
if [ -f /etc/rc.local ]; then
  sed -i '/gost-bridge/d; /dockerd/d' /etc/rc.local &>/dev/null
else
  echo '#!/bin/sh' > /etc/rc.local
  chmod +x /etc/rc.local
fi
sed -i '/^exit 0/i dockerd &>/dev/null &' /etc/rc.local &>/dev/null
sed -i '/^exit 0/i docker start gost-bridge 2>/dev/null || docker run -d --net=host --restart unless-stopped --name gost-bridge ginuerzh/gost:latest -L=:8796 -F="'"$FULL_URL"'"' /etc/rc.local &>/dev/null

# Apply in Current Environment
export HTTP_PROXY="http://127.0.0.1:${GOST_PORT}"
export HTTPS_PROXY="http://127.0.0.1:${GOST_PORT}"
export http_proxy="http://127.0.0.1:${GOST_PORT}"
export https_proxy="http://127.0.0.1:${GOST_PORT}"
export NO_PROXY="localhost,127.0.0.1,::1,deb.debian.org,security.debian.org,snapshot.debian.org,archive.ubuntu.com,security.ubuntu.com,ppas.launchpadcontent.net"
export no_proxy="localhost,127.0.0.1,::1,deb.debian.org,security.debian.org,snapshot.debian.org,archive.ubuntu.com,security.ubuntu.com,ppas.launchpadcontent.net"

source /etc/profile.d/network-fix.sh

echo ""
echo -e "${C_GREEN}╭──────────────────────────────────────────────────────────╮${C_RESET}"
echo -e "${C_GREEN}│${C_RESET} ${C_CYAN}✔ Network routing & tunnel applied successfully! ${C_RESET}${C_GREEN}│${C_RESET}"
echo -e "${C_GREEN}├──────────────────────────────────────────────────────────┤${C_RESET}"
echo -e "${C_GREEN}│${C_RESET} ${C_YELLOW}⚠ If changes don't take effect immediately, run: ${C_RESET}${C_GREEN}│${C_RESET}"
echo -e "${C_GREEN}│${C_RESET} ${C_CYAN}source /etc/profile.d/network-fix.sh ${C_RESET}${C_GREEN}│${C_RESET}"
echo -e "${C_GREEN}╰──────────────────────────────────────────────────────────╯${C_RESET}"
echo ""
