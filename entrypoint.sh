#!/bin/sh
set -e

# Source .env file if present
if [ -f /.env ]; then
  set -a
  . /.env
  set +a
fi

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
sleep 1

# Configure proxychains to use Tailscale's SOCKS5 proxy
cat > /tmp/proxychains.conf <<EOF
strict_chain
proxy_dns
tcp_read_time_out 15000
tcp_connect_time_out 8000
[ProxyList]
socks5 127.0.0.1 1056
EOF

exec proxychains4 -f /tmp/proxychains.conf claude "$@"
