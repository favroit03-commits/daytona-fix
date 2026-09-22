#!/bin/bash

R="\033[1;31m"; G="\033[1;32m"; Y="\033[1;33m"; B="\033[1;34m"; C="\033[1;36m"; W="\033[1;37m"; N="\033[0m"

clear 2>/dev/null || printf "\033[2J\033[H"

echo -e "${R}M${Y}a${G}d${C}e${B} ${W}B${R}y${Y} ${G}n${C}a${B}f${R}i${Y}g${G}a${C}m${B}e${R}r${N}"
echo ""

echo -e "${C} ⣏⡱ ⡀⢀ ⣀⡀ ⢀⣀ ⢀⣀ ⢀⣀ ⠄ ⣀⡀ ⢀⡀   ⡏⢱ ⢀⣀ ⡀⢀ ⣰⡀ ⢀⡀ ⣀⡀ ⢀⣀   ⡷⣸ ⢀⡀ ⣰⡀ ⡀ ⢀ ⢀⡀ ⡀⣀ ⡇⡠${N}"
echo -e "${C} ⠧⠜ ⣑⡺ ⡧⠜ ⠣⠼ ⠭⠕ ⠭⠕ ⠇ ⠇⠸ ⣑⡺   ⠧⠜ ⠣⠼ ⣑⡺ ⠘⠤ ⠣⠜ ⠇⠸ ⠣⠼   ⠇⠹ ⠣⠭ ⠘⠤ ⠱⠱⠃ ⠣⠜ ⠏  ⠏⠢${N}"
echo ""

if [ "$(id -u)" -ne 0 ]; then
  echo -e "${R}[!] Run as root${N}"; exit 1
fi

echo -ne "${C}[ ${N}"
colors=("$R" "$Y" "$G" "$C" "$B" "$W")
text="Bypassing Daytona Network"
for (( i=0; i<${#text}; i++ )); do
    color=${colors[$((i % 6))]}
    echo -ne "${color}${text:$i:1}${N}"
    sleep 0.05
done
echo -e "${C} ]${N}"

for i in {1..5}; do
    sleep 0.4
    echo -ne "${Y}.${N}"
done
echo ""

cat > /etc/profile.d/daytona-net.sh << 'EOF'
export HTTP_PROXY=http://10.0.2.2:8796
export HTTPS_PROXY=http://10.0.2.2:8796
export http_proxy=http://10.0.2.2:8796
export https_proxy=http://10.0.2.2:8796
export NO_PROXY=localhost,127.0.0.1,::1
export no_proxy=localhost,127.0.0.1,::1
EOF
chmod +x /etc/profile.d/daytona-net.sh
echo -e "  ${G}✓${N} /etc/profile.d/daytona-net.sh"

cat > /etc/environment << 'EOF'
HTTP_PROXY=http://10.0.2.2:8796
HTTPS_PROXY=http://10.0.2.2:8796
http_proxy=http://10.0.2.2:8796
https_proxy=http://10.0.2.2:8796
NO_PROXY=localhost,127.0.0.1,::1
no_proxy=localhost,127.0.0.1,::1
EOF
echo -e "  ${G}✓${N} /etc/environment"

mkdir -p /etc/apt/apt.conf.d
cat > /etc/apt/apt.conf.d/99proxy << 'EOF'
Acquire::http::Proxy "http://10.0.2.2:8796";
Acquire::https::Proxy "http://10.0.2.2:8796";
EOF
echo -e "  ${G}✓${N} /etc/apt/apt.conf.d/99proxy"

cat > /etc/sudoers.d/proxy << 'EOFP'
Defaults env_keep += "HTTP_PROXY HTTPS_PROXY http_proxy https_proxy NO_PROXY no_proxy"
EOFP
chmod 440 /etc/sudoers.d/proxy
echo -e "  ${G}✓${N} sudoers proxy"

export HTTP_PROXY="http://10.0.2.2:8796"
export HTTPS_PROXY="http://10.0.2.2:8796"
export http_proxy="http://10.0.2.2:8796"
export https_proxy="http://10.0.2.2:8796"
export NO_PROXY="localhost,127.0.0.1,::1"
export no_proxy="localhost,127.0.0.1,::1"

source /etc/profile.d/daytona-net.sh

echo ""
echo -e "${C}┌─────────────────────────────────────────────────────────┐${N}"
echo -e "${C}│${N}  ${G}✓ Bypassed${N}                                          ${C}│${N}"
echo -e "${C}│${N}                                                         ${C}│${N}"
echo -e "${C}│${N}  ${W}If not working, run:${N}                                  ${C}│${N}"
echo -e "${C}│${N}  ${Y}source /etc/profile.d/daytona-net.sh${N}                  ${C}│${N}"
echo -e "${C}│${N}                                                         ${C}│${N}"
echo -e "${C}└─────────────────────────────────────────────────────────┘${N}"
echo ""
