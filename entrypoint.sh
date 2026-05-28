#!/bin/sh
set -e

# Source .env file if present
if [ -f /.env ]; then
  set -a
  . /.env
  set +a
fi

# Start tailscaled in userspace networking mode (no TUN device needed)
tailscaled --tun=userspace-networking --statedir=/var/lib/tailscale --socket=/var/run/tailscale/tailscaled.sock &

# Wait for tailscaled to be ready
sleep 2

# Build tailscale up flags
TS_UP_FLAGS="--authkey=${TS_AUTHKEY} --hostname=${TS_HOSTNAME:-claude-code}"
if [ -n "$TS_EXIT_NODE" ]; then
  TS_UP_FLAGS="${TS_UP_FLAGS} --exit-node=${TS_EXIT_NODE} --exit-node-allow-lan-access"
fi

# Authenticate and connect
eval tailscale up $TS_UP_FLAGS

# Set proxy env vars so Claude API traffic routes through Tailscale
# When using userspace networking, tailscale provides a SOCKS5 and HTTP proxy
export ALL_PROXY=socks5://localhost:1055
export HTTP_PROXY=http://localhost:1055
export HTTPS_PROXY=http://localhost:1055

exec claude "$@"
