#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

HOST="gost-production-2fc2.up.railway.app"
PORT=8796
NAME="gost-proxy-bridge"
IMAGE="${GOST_IMAGE:-ginuerzh/gost:latest}"
PROXY="http://127.0.0.1:${PORT}"

# Official Ubuntu/Debian domains and their subdomains bypass the proxy.
BYPASS="localhost,127.0.0.1,::1,ubuntu.com,.ubuntu.com,debian.org,.debian.org,github.com,raw.githubusercontent.com"

CA_FILE="/etc/ssl/certs/ca-certificates.crt"
ENV_FILE="/etc/environment"
PROFILE_FILE="/etc/profile.d/gost-proxy.sh"
SUDO_FILE="/etc/sudoers.d/90-gost-proxy"
SOCKET="/var/run/docker.sock"

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ $EUID -eq 0 ]] || die "Run with: sudo bash setup-gost.sh"

for cmd in docker curl python3 visudo flock timeout pgrep \
           awk cp cat chmod install mktemp sleep nohup; do
    command -v "$cmd" >/dev/null || die "Required command missing: $cmd"
done

[[ -r "$CA_FILE" ]] || die "Install ca-certificates first."
[[ -f /etc/sudoers ]] || die "/etc/sudoers missing."

exec 9>/run/lock/gost-proxy-setup.lock
flock -n 9 || die "Another setup is already running."

# Explicitly use a local Unix socket, not a remote Docker context.
unset DOCKER_HOST DOCKER_CONTEXT DOCKER_TLS_VERIFY DOCKER_CERT_PATH
d() {
    docker --host "unix://${SOCKET}" "$@"
}
docker_ready() {
    timeout 5 docker --host "unix://${SOCKET}" info >/dev/null 2>&1
}

# Start Docker without exposing its API over TCP or weakening isolation.
if ! docker_ready; then
    if command -v systemctl >/dev/null &&
       [[ -d /run/systemd/system ]]; then
        timeout 60 systemctl start docker ||
            die "Docker service did not start; inspect journalctl -u docker."
    else
        # Do not race an existing daemon or delete its PID/socket files.
        if ! pgrep -x dockerd >/dev/null; then
            command -v dockerd >/dev/null ||
                die "dockerd missing; install Docker through your workspace image."

install -d -m 0700 /var/log/gost-proxy
            nohup dockerd \
                --host="unix://${SOCKET}" \
                </dev/null >/var/log/gost-proxy/dockerd.log 2>&1 9>&- &
        fi
    fi

ready=0
    for ((i = 0; i < 30; i++)); do
        if docker_ready; then
            ready=1
            break
        fi
        sleep 2
    done
    [[ $ready -eq 1 ]] ||
        die "Docker unavailable. Check daemon logs and workspace capabilities."
fi

# Never overwrite or remove a pre-existing container.
if d container inspect "$NAME" >/dev/null 2>&1; then
    die "Container '$NAME' already exists. Inspect it before reconfiguring."
fi

[[ -r /dev/tty ]] || die "Run from an interactive terminal."
read -r -p "Railway GOST username: " GOST_USER </dev/tty
read -r -s -p "Railway GOST password: " GOST_PASS </dev/tty
printf '\n' >/dev/tty
[[ -n "$GOST_USER" && -n "$GOST_PASS" ]] ||
    die "Username and password must not be empty."

# Encode reserved URL characters without putting the password in Python argv.
encode_component() {
    python3 -c \
        'import sys; from urllib.parse import quote; print(quote(sys.stdin.read(), safe=""))'
}
USER_ENC="$(printf '%s' "$GOST_USER" | encode_component)"
PASS_ENC="$(printf '%s' "$GOST_PASS" | encode_component)"
unset GOST_USER GOST_PASS

FORWARD="mwss://${USER_ENC}:${PASS_ENC}@${HOST}:443?secure=true&path=/ws"
unset USER_ENC PASS_ENC

install -d -m 0700 /var/backups/gost-proxy
BACKUP="$(mktemp -d /var/backups/gost-proxy/setup.XXXXXXXX)"
FILES=(
    "/etc/resolv.conf"
    "$ENV_FILE"
    "$PROFILE_FILE"
    "$SUDO_FILE"
)

# Snapshot contents; resolv.conf may be a bind mount or managed symlink.
for i in "${!FILES[@]}"; do
    f="${FILES[$i]}"
    [[ ! -L "$f" || -e "$f" ]] || die "Dangling symlink: $f"
    if [[ -e "$f" ]]; then
        [[ -f "$f" ]] || die "Not a regular file: $f"
        cp -pL -- "$f" "$BACKUP/$i"
    else
        : >"$BACKUP/$i.absent"
    fi
done

changed=0
created=0
rollback() {
    local rc=$?
    trap - EXIT
    if ((rc != 0)); then
        printf 'Setup failed; restoring configuration.\n' >&2
        if ((created)); then
            d rm -f "$NAME" >/dev/null 2>&1 || true
        fi
        if ((changed)); then
            for i in "${!FILES[@]}"; do
                f="${FILES[$i]}"
                if [[ -e "$BACKUP/$i.absent" ]]; then
                    rm -f -- "$f" || true
                else
                    # Write through symlinks and bind mounts; no rename.
                    cat "$BACKUP/$i" >"$f" || true
                    chmod --reference="$BACKUP/$i" "$f" || true
                fi
            done
        fi
        printf 'Backup directory: %s\n' "$BACKUP" >&2
        printf 'Docker daemon/image, if started/pulled, are left in place.\n' >&2
    fi
    exit "$rc"
}
trap rollback EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Stage /etc/environment: assignments only, not shell "export" commands.
if [[ -e "$ENV_FILE" ]]; then
    awk '
        !/^[[:space:]]*(export[[:space:]]+)?(HTTP_PROXY|HTTPS_PROXY|NO_PROXY|http_proxy|https_proxy|no_proxy)[[:space:]]*=/
    ' "$ENV_FILE" >"$BACKUP/environment.new"
else
    : >"$BACKUP/environment.new"
fi

for key in HTTP_PROXY HTTPS_PROXY http_proxy https_proxy; do
    printf '%s="%s"\n' "$key" "$PROXY" >>"$BACKUP/environment.new"
done
for key in NO_PROXY no_proxy; do
    printf '%s="%s"\n' "$key" "$BYPASS" >>"$BACKUP/environment.new"
done

cat >"$BACKUP/profile.new" <<EOF
# Managed by setup-gost.sh
export HTTP_PROXY="$PROXY"
export HTTPS_PROXY="$PROXY"
export http_proxy="$PROXY"
export https_proxy="$PROXY"
export NO_PROXY="$BYPASS"
export no_proxy="$BYPASS"
EOF

cat >"$BACKUP/sudoers.new" <<'EOF'
Defaults env_keep += "HTTP_PROXY HTTPS_PROXY NO_PROXY http_proxy https_proxy no_proxy"
EOF
chmod 0440 "$BACKUP/sudoers.new"
visudo -cf "$BACKUP/sudoers.new" >/dev/null

# Ensure sudo actually includes /etc/sudoers.d.
grep -Eq \
    '^[[:space:]]*([#@]includedir)[[:space:]]+/etc/sudoers\.d/?([[:space:]]|$)' \
    /etc/sudoers ||
    die "sudoers does not include /etc/sudoers.d; configure that first."

# DNS change is deliberately reversible; never chattr or replace a mount.
changed=1
printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' >/etc/resolv.conf

# Docker image bootstrap still needs working direct/approved registry access.
if ! d image inspect "$IMAGE" >/dev/null 2>&1; then
    d pull "$IMAGE"
fi

# Listener is :8796 INSIDE Docker, published only on workspace loopback.
# Host CA bundle provides trust even if the image has no CA bundle.
d create \
    --name "$NAME" \
    --label "managed-by=gost-proxy-setup" \
    --restart unless-stopped \
    --publish "127.0.0.1:${PORT}:${PORT}/tcp" \
    --dns 1.1.1.1 \
    --dns 8.8.8.8 \
    --cap-drop ALL \
    --security-opt no-new-privileges:true \
    --read-only \
    --user 65534:65534 \
    --tmpfs /tmp:rw,noexec,nosuid,size=16m \
    --mount "type=bind,src=${CA_FILE},dst=/etc/ssl/certs/ca-certificates.crt,readonly" \
    --env SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    --log-opt max-size=10m \
    --log-opt max-file=2 \
    "$IMAGE" \
    -L="http://:${PORT}" \
    -F="$FORWARD" >/dev/null

created=1
unset FORWARD
d start "$NAME" >/dev/null

# Exercise the real HTTPS tunnel, not just an open local TCP port.
# An explicit empty --noproxy ensures this test uses the bridge.
healthy=0
for ((i = 0; i < 5; i++)); do
    if curl --silent --show-error --fail \
        --connect-timeout 10 --max-time 25 \
        --proxy "$PROXY" --noproxy "" \
        https://example.com/ --output /dev/null; then
        healthy=1
        break
    fi
    sleep 2
done
[[ $healthy -eq 1 ]] ||
    die "Tunnel test failed: check credentials, /ws path, TLS, Railway backend and egress."

# Publish environment configuration only after the tunnel works.
install -d -m 0755 /etc/profile.d /etc/sudoers.d

cat "$BACKUP/environment.new" >"$ENV_FILE"
chmod 0644 "$ENV_FILE"

cat "$BACKUP/profile.new" >"$PROFILE_FILE"
chmod 0644 "$PROFILE_FILE"

cat "$BACKUP/sudoers.new" >"$SUDO_FILE"
chmod 0440 "$SUDO_FILE"
visudo -c >/dev/null

printf '\nTunnel HTTPS test passed.\n'
printf 'Proxy: %s\n' "$PROXY"
printf 'Backups: %s\n' "$BACKUP"
printf 'Current shell: source /etc/profile.d/gost-proxy.sh\n'
