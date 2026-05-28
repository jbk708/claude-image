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
  --outbound-http-proxy-listen=localhost:1055 \
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
echo "Tailscale status:"
tailscale status || true
echo ""

echo "Checking proxy on localhost:1055..."
if command -v curl > /dev/null 2>&1; then
  curl -s --max-time 5 -x http://localhost:1055 https://api.ipify.org && echo " (proxy works)" || echo " (proxy FAILED)"
else
  echo "curl not available"
fi
echo ""

echo "Checking SOCKS5 on localhost:1056..."
if command -v curl > /dev/null 2>&1; then
  curl -s --max-time 5 --socks5 localhost:1056 https://api.ipify.org && echo " (socks works)" || echo " (socks FAILED)"
fi
echo ""

echo "Checking direct connectivity to api.anthropic.com..."
if command -v curl > /dev/null 2>&1; then
  curl -s --max-time 5 https://api.anthropic.com/ && echo " (direct works)" || echo " (direct FAILED - expected on blocked network)"
fi
echo ""

echo "Testing proxy-setup.js loading..."
node -e "require('/proxy-setup.js'); console.log('proxy-setup.js loaded OK')" 2>&1 || echo "proxy-setup.js FAILED to load"
echo "=== End Diagnostics ==="

# Patch Node.js fetch() to use Tailscale's HTTP proxy (undici is built into Node 22)
export NODE_OPTIONS="--require /proxy-setup.js ${NODE_OPTIONS:-}"

exec claude "$@"
