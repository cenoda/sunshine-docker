#!/bin/bash
# Sunshine Docker - One-Click Setup Script
# Auto-detects X11/Wayland, installs dependencies, configures and starts
set -e

# ── Colors ──────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }
info() { echo -e "${BLUE}[i]${NC} $1"; }

# ── Banner ──────────────────────────────────────────────
echo ""
echo -e "${BOLD}================================${NC}"
echo -e "${BOLD}  Sunshine Docker Setup${NC}"
echo -e "${BOLD}================================${NC}"
echo ""

# ── Check root / sudo ───────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    SUDO="sudo"
    info "Some steps require sudo. You may be prompted for your password."
else
    SUDO=""
    warn "Running as root. Container will also run as root — this is expected."
fi

# ── Detect distro ───────────────────────────────────────
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    DISTRO_VER=$VERSION_ID
else
    err "Cannot detect Linux distribution."
    exit 1
fi
log "Detected: ${DISTRO} ${DISTRO_VER}"

# ── Check Docker ────────────────────────────────────────
if ! command -v docker &>/dev/null; then
    warn "Docker is not installed. Installing..."
    case $DISTRO in
        ubuntu|debian)
            $SUDO apt-get update -qq
            $SUDO apt-get install -y -qq docker.io docker-compose-v2 2>/dev/null || \
            $SUDO apt-get install -y -qq docker.io docker-compose
            ;;
        fedora)
            $SUDO dnf install -y docker docker-compose
            ;;
        arch)
            $SUDO pacman -S --noconfirm docker docker-compose
            ;;
        opensuse*|suse)
            $SUDO zypper install -y docker docker-compose
            ;;
        *)
            err "Unsupported distro: $DISTRO. Please install Docker manually."
            exit 1
            ;;
    esac
    $SUDO systemctl enable --now docker
    log "Docker installed and started."
else
    log "Docker is already installed."
fi

# Add user to docker group if not already
if ! groups | grep -q docker; then
    warn "Adding user to 'docker' group..."
    $SUDO usermod -aG docker "$USER"
    log "Added to docker group. You may need to log out and back in for this to take effect."
    NEED_RELOG=1
fi

# ── Check NVIDIA drivers ────────────────────────────────
if ! command -v nvidia-smi &>/dev/null; then
    warn "nvidia-smi not found. NVIDIA drivers may not be installed."
    warn "Please install NVIDIA drivers: https://www.nvidia.com/download/index.aspx"
else
    log "NVIDIA drivers detected: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo 'GPU')"
fi

# ── Check NVIDIA Container Toolkit ──────────────────────
if ! docker info 2>/dev/null | grep -q "nvidia"; then
    warn "NVIDIA Container Toolkit not detected. Installing..."
    case $DISTRO in
        ubuntu|debian)
            curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | $SUDO gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
            curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
                sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
                $SUDO tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
            $SUDO apt-get update -qq
            $SUDO apt-get install -y -qq nvidia-container-toolkit
            ;;
        fedora)
            curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | \
                $SUDO tee /etc/yum.repos.d/nvidia-container-toolkit.repo
            $SUDO dnf install -y nvidia-container-toolkit
            ;;
        arch)
            warn "Please install nvidia-container-toolkit from AUR: yay -S nvidia-container-toolkit"
            ;;
        *)
            warn "Please install NVIDIA Container Toolkit manually."
            ;;
    esac
    $SUDO systemctl restart docker
    log "NVIDIA Container Toolkit installed."
else
    log "NVIDIA Container Toolkit is configured."
fi

# ── Detect display server ───────────────────────────────
DISPLAY_SERVER="x11"
if [ -n "$WAYLAND_DISPLAY" ]; then
    DISPLAY_SERVER="wayland"
elif [ -n "$XDG_SESSION_TYPE" ] && [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    DISPLAY_SERVER="wayland"
elif loginctl show-session "$(loginctl | grep "$USER" | awk '{print $1}' | head -1)" -p Type 2>/dev/null | grep -q "wayland"; then
    DISPLAY_SERVER="wayland"
fi
log "Display server: ${DISPLAY_SERVER^^}"

# ── Detect audio system ─────────────────────────────────
AUDIO_SYSTEM="pulseaudio"
if pgrep -x pipewire &>/dev/null || [ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/pipewire-0" ]; then
    AUDIO_SYSTEM="pipewire"
fi
log "Audio system: ${AUDIO_SYSTEM^}"

# ── Auto-configure ──────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
CONFIG_FILE="$SCRIPT_DIR/config/sunshine.conf"

info "Configuring for ${DISPLAY_SERVER^^}..."

if [ "$DISPLAY_SERVER" = "wayland" ]; then
    # Uncomment Wayland lines in docker-compose.yml
    sed -i 's|^      # - WAYLAND_DISPLAY=|      - WAYLAND_DISPLAY=|' "$COMPOSE_FILE"
    sed -i 's|^      # - \${XDG_RUNTIME_DIR:-/run/user/1000}/\${WAYLAND_DISPLAY:-wayland-0}:/tmp/wayland-0:ro|      - ${XDG_RUNTIME_DIR:-/run/user/1000}/${WAYLAND_DISPLAY:-wayland-0}:/tmp/wayland-0:ro|' "$COMPOSE_FILE"
    sed -i 's|^      # - \${XDG_RUNTIME_DIR:-/run/user/1000}/pipewire-0:/tmp/pipewire-0:ro|      - ${XDG_RUNTIME_DIR:-/run/user/1000}/pipewire-0:/tmp/pipewire-0:ro|' "$COMPOSE_FILE"
    # Set KMS capture
    sed -i 's/^capture = .*/capture = kms/' "$CONFIG_FILE"
    log "Wayland mode configured (KMS capture + PipeWire)."
else
    # Keep X11 defaults — ensure capture is x11
    sed -i 's/^capture = .*/capture = x11/' "$CONFIG_FILE"
    log "X11 mode configured."
fi

# ── Set correct display output ──────────────────────────
ACTIVE_DISPLAY="${DISPLAY:-:0}"
info "Using DISPLAY=${ACTIVE_DISPLAY}"

# ── Build & start ───────────────────────────────────────
echo ""
info "Building Docker image (this may take a few minutes)..."
cd "$SCRIPT_DIR"
docker compose build --no-cache 2>&1 | tail -5

echo ""
info "Starting Sunshine container..."
docker compose up -d

# Wait for container to be ready
sleep 3
if docker ps --format '{{.Names}}' | grep -q sunshine; then
    log "Sunshine container is running!"
else
    err "Container failed to start. Check logs: docker compose logs"
    exit 1
fi

# ── Optional: systemd auto-start ────────────────────────
echo ""
read -rp "Install systemd service for auto-start on boot? [Y/n]: " INSTALL_SERVICE
INSTALL_SERVICE=${INSTALL_SERVICE:-y}
if [[ "$INSTALL_SERVICE" =~ ^[Yy]$ ]]; then
    SERVICE_FILE="$SCRIPT_DIR/sunshine-docker.service"
    # Update paths in service file to match current location
    sed -i "s|ExecStart=.*|ExecStart=/usr/bin/docker compose -f $COMPOSE_FILE up -d|" "$SERVICE_FILE"
    sed -i "s|ExecStop=.*|ExecStop=/usr/bin/docker compose -f $COMPOSE_FILE down|" "$SERVICE_FILE"
    sed -i "s|ExecReload=.*|ExecReload=/usr/bin/docker compose -f $COMPOSE_FILE restart|" "$SERVICE_FILE"
    sed -i "s|User=.*|User=$USER|" "$SERVICE_FILE"
    $SUDO cp "$SERVICE_FILE" /etc/systemd/system/
    $SUDO systemctl daemon-reload
    $SUDO systemctl enable --now sunshine-docker.service 2>/dev/null || \
        warn "Could not enable service. You can do this manually later."
    log "Systemd service installed."
fi

# ── Done ────────────────────────────────────────────────
echo ""
echo -e "${BOLD}================================${NC}"
echo -e "${BOLD}  Setup Complete!${NC}"
echo -e "${BOLD}================================${NC}"
echo ""
echo -e "  Web UI:  ${GREEN}https://localhost:47990${NC}"
echo -e "  Logs:    ${BLUE}docker compose logs -f${NC}"
echo -e "  Restart: ${BLUE}docker compose restart${NC}"
echo -e "  Stop:    ${BLUE}docker compose down${NC}"
echo ""

if [ "$NEED_RELOG" = "1" ]; then
    warn "You were added to the 'docker' group. Please log out and back in, or run:"
    echo "       newgrp docker"
    echo ""
fi

echo "  Moonlight client → add host at this machine's IP address."
echo ""
