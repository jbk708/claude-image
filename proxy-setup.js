// Loaded via NODE_OPTIONS="--require /proxy-setup.js"
// Patches Node.js built-in fetch() to route through Tailscale's HTTP proxy
const { setGlobalDispatcher, ProxyAgent } = require('undici');
setGlobalDispatcher(new ProxyAgent(process.env.TS_HTTP_PROXY || 'http://127.0.0.1:1055'));
