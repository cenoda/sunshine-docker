# Sunshine Docker - NVIDIA GPU Game Streaming

Isolated Moonlight/Sunshine game streaming server running in Docker.

Supports RTX 5080 + NVENC + X11 & Wayland capture + auto-start (systemd).

## Requirements

- NVIDIA GPU (RTX 20xx or higher recommended)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
- Docker & docker-compose
- X11 or Wayland display server (X11 recommended for lower latency)
- PulseAudio or PipeWire (for audio streaming)

## Platform Compatibility

| Platform | Status | Notes |
|----------|--------|-------|
| **Ubuntu 22.04/24.04** | ✅ Full support | Primary target. X11 + PulseAudio + NVIDIA |
| **Debian 12** | ✅ Full support | Same stack as Ubuntu |
| **Fedora 40+** | ✅ Works | Wayland + PipeWire supported natively. See Wayland setup below. |
| **Arch Linux** | ✅ Works | Ensure `xorg-server` and `pulseaudio` are installed |
| **openSUSE Tumbleweed** | ✅ Works | Install `xorg-x11-server` package |
| **Windows** | ❌ Not supported | Docker GPU passthrough + X11 capture require Linux kernel features. Use [Sunshine for Windows](https://github.com/LizardByte/Sunshine/releases) natively instead. |
| **Windows (WSL2)** | ⚠️ Partial | NVIDIA GPU passthrough works via WSL2, but X11 capture may need additional setup. Not recommended. |
| **macOS** | ❌ Not supported | No NVIDIA GPU, no X11 |

### Wayland Support

Wayland capture uses KMS (Kernel Mode Setting) via `/dev/dri` — no X11 required. Audio uses PipeWire.

**1. Edit `docker-compose.yml`** — uncomment the Wayland lines:

```yaml
environment:
  - WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-0}   # uncomment

volumes:
  # Wayland socket for KMS capture (uncomment for Wayland):
  - ${XDG_RUNTIME_DIR:-/run/user/1000}/${WAYLAND_DISPLAY:-wayland-0}:/tmp/wayland-0:ro  # uncomment
  # PipeWire socket for audio on Wayland (uncomment for Wayland):
  - ${XDG_RUNTIME_DIR:-/run/user/1000}/pipewire-0:/tmp/pipewire-0:ro                    # uncomment
```

**2. Edit `config/sunshine.conf`** — switch to KMS capture:

```ini
capture = kms
```

**3. Rebuild and restart:**

```bash
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

**4. Verify:**

```bash
# Check if Wayland socket is visible inside the container
docker exec sunshine ls -la /tmp/wayland-0 /tmp/pipewire-0
```

> **Note:** KMS capture may have higher latency than X11 capture. If you experience issues, switch back to X11.

### PulseAudio Notes

Some distros use PipeWire instead of PulseAudio. Install `pipewire-pulse` or `pulseaudio`:

```bash
# Ubuntu/Debian
sudo apt install pulseaudio

# Fedora
sudo dnf install pulseaudio

# Arch
sudo pacman -S pulseaudio
```

## Quick Start

### One-Click Setup (Recommended)

```bash
git clone https://github.com/cenoda/sunshine-docker.git
cd sunshine-docker
./setup.sh
```

The script automatically:
- Detects your distro (Ubuntu, Debian, Fedora, Arch, openSUSE)
- Installs Docker + NVIDIA Container Toolkit if missing
- Detects X11 or Wayland and configures accordingly
- Detects PulseAudio or PipeWire for audio
- Builds and starts the container
- Optionally installs systemd auto-start

### Manual Setup

```bash
# 1. Clone
git clone https://github.com/cenoda/sunshine-docker.git
cd sunshine-docker

# 2. Edit config (display, encoder, etc.)
vim config/sunshine.conf

# 3. Build & run
docker-compose up -d

# 4. Access Web UI → set username/password
# https://localhost:47990
```

## Auto-start on Boot

```bash
sudo cp sunshine-docker.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now sunshine-docker.service
```

## Configuration

Key options in `config/sunshine.conf`:

| Option | Default | Description |
|--------|---------|-------------|
| `encoder` | `nvenc` | Encoder (nvenc / vaapi / software) |
| `fps` | `60` | Framerate |
| `bitrate` | `50000` | Bitrate (kbps) |
| `capture` | `x11` | Capture method (x11 / nvfbc / kms) |
| `output_name` | `1` | Output display number (check with `xrandr`) |
| `origin_pin_allowed` | `true` | Allow PIN authentication |

## File Structure

```
sunshine-docker/
├── setup.sh                 # One-click setup (auto-detect + install + configure)
├── Dockerfile              # Custom image (adds X11/Wayland/Avahi/PulseAudio/PipeWire)
├── docker-compose.yml      # Service definition
├── sunshine-docker.service # systemd unit (auto-start)
├── config/
│   └── sunshine.conf       # Sunshine config file
└── README.md
```

## Troubleshooting

```bash
# Check logs
docker logs sunshine

# Restart container
docker-compose restart

# List available displays
xrandr --listmonitors

# Verify GPU is detected
docker exec sunshine nvidia-smi
```

## Ports

| Port | Purpose |
|------|---------|
| 47984 | Web UI (HTTPS) |
| 47989 | HTTP |
| 47990 | HTTPS |
| 48010 | RTSP |

## License

MIT
