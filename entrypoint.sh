#!/bin/sh
set -e

# Source .env file if present
if [ -f /.env ]; then
  set -a
  . /.env
  set +a
fi

# Clean up any leftover tailscaled from a previous run (shared network namespace in Singularity)
pkill -f tailscaled 2>/dev/null || true
rm -f /var/run/tailscale/tailscaled.sock
sleep 1

# Start tailscaled in userspace networking mode (no TUN device needed)
tailscaled --tun=userspace-networking \
  --socks5-server=localhost:1056 \
  --statedir=/var/lib/tailscale \
  --socket=/var/run/tailscale/tailscaled.sock &

# Wait for tailscaled to be ready
sleep 2

# Build tailscale up flags
TS_UP_FLAGS="--authkey=${TS_AUTHKEY} --hostname=${TS_HOSTNAME:-claude-code}"
if [ -n "$TS_EXIT_NODE" ]; then
  TS_UP_FLAGS="${TS_UP_FLAGS} --exit-node=${TS_EXIT_NODE} --exit-node-allow-lan-access"
fi

# Authenticate and connect
eval tailscale up $TS_UP_FLAGS

# Wait for proxy listener to be ready
sleep 2

# --- Diagnostics ---
echo "=== Tailscale Diagnostics ==="
tailscale status 2>/dev/null | head -3 || true

echo "SOCKS5 proxy test:"
curl -s --max-time 5 --socks5-hostname localhost:1056 https://api.ipify.org && echo " OK" || echo " FAILED"

echo "proxy-setup.js test:"
NODE_PATH=/usr/local/lib/node_modules node -e "require('/proxy-setup.js'); console.log('OK')" 2>&1
echo "=== End Diagnostics ==="

# Ensure globally installed npm packages are findable by require()
export NODE_PATH=/usr/local/lib/node_modules
export NODE_OPTIONS="--require /proxy-setup.js ${NODE_OPTIONS:-}"

exec claude "$@"
