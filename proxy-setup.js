// Loaded via NODE_OPTIONS="--require /proxy-setup.js"
// Patches Node.js built-in fetch() to route through Tailscale's HTTP proxy
try {
  const { setGlobalDispatcher, ProxyAgent } = require('undici');
  const proxyUrl = process.env.TS_HTTP_PROXY || 'http://127.0.0.1:1055';
  setGlobalDispatcher(new ProxyAgent(proxyUrl));
  console.error('[proxy-setup] Patched fetch() to use proxy:', proxyUrl);
} catch (err) {
  console.error('[proxy-setup] FAILED to patch fetch():', err.message);
}
