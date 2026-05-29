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
  --outbound-http-proxy-listen=127.0.0.1:1055 \
  --socks5-server=127.0.0.1:1056 \
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
tailscale status 2>/dev/null || true

echo "SOCKS5 test (15s timeout):"
curl -s --max-time 15 --socks5-hostname 127.0.0.1:1056 https://api.ipify.org && echo " OK" || echo " FAILED"

echo "HTTP proxy test (15s timeout):"
curl -s --max-time 15 -x http://127.0.0.1:1055 https://api.ipify.org && echo " OK" || echo " FAILED"

echo "HTTP proxy -> Anthropic API test:"
curl -s --max-time 15 -x http://127.0.0.1:1055 -o /dev/null -w "%{http_code}" https://api.anthropic.com/v1/messages && echo " OK" || echo " FAILED"
echo "=== End Diagnostics ==="

# Claude Code is a compiled Bun binary (not Node.js).
# Set all proxy env var forms — Bun may check lowercase or uppercase.
export HTTP_PROXY=http://127.0.0.1:1055
export HTTPS_PROXY=http://127.0.0.1:1055
export http_proxy=http://127.0.0.1:1055
export https_proxy=http://127.0.0.1:1055
export ALL_PROXY=http://127.0.0.1:1055
export all_proxy=http://127.0.0.1:1055

exec claude "$@"
