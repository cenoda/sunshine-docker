# Custom Sunshine Docker image with X11 capture support and NVIDIA encoding
# Extends lizardbyte/sunshine with missing runtime dependencies

FROM lizardbyte/sunshine:latest-ubuntu-24.04

USER root

# Install X11 client libraries for display capture
# Install Avahi for mDNS/Moonlight discovery
# Install PulseAudio client for audio capture
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libxrandr2 \
        libx11-6 \
        libxcb1 \
        libxfixes3 \
        libxtst6 \
        libxdamage1 \
        libxcomposite1 \
        libxcursor1 \
        libxi6 \
        libxext6 \
        libxinerama1 \
        libxss1 \
        libavahi-common3 \
        libavahi-client3 \
        libpulse0 \
        libssl3 \
        ca-certificates \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Make home directory world-accessible for UID mapping
RUN chmod 755 /home/lizard

# Remove the /config symlink - we'll bind-mount directly
RUN rm -f /config

USER lizard
