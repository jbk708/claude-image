// Loaded via NODE_OPTIONS="--require /proxy-setup.js"
// Routes ALL outgoing traffic through Tailscale's SOCKS5 proxy.
// Patches at every level: fetch(), http.globalAgent, https.globalAgent,
// and monkey-patches https.request/http.request to force the agent.

const http = require('http');
const https = require('https');
const tls = require('tls');

const SOCKS_HOST = '127.0.0.1';
const SOCKS_PORT = parseInt(process.env.TS_SOCKS_PORT || '1056');
const SOCKS_URL = `socks5://${SOCKS_HOST}:${SOCKS_PORT}`;

// --- Layer 1: Patch http/https globalAgent and monkey-patch request() ---
try {
  const { SocksProxyAgent } = require('socks-proxy-agent');
  const socksAgent = new SocksProxyAgent(SOCKS_URL);

  // Replace global agents
  http.globalAgent = socksAgent;
  https.globalAgent = socksAgent;

  // Monkey-patch https.request to force our agent on EVERY call
  const origHttpsRequest = https.request;
  https.request = function (url, options, callback) {
    if (typeof url === 'string' || url instanceof URL) {
      if (typeof options === 'function') {
        callback = options;
        options = { agent: socksAgent };
      } else {
        options = Object.assign({}, options, { agent: socksAgent });
      }
      return origHttpsRequest.call(this, url, options, callback);
    }
    // url is actually the options object
    const opts = Object.assign({}, url, { agent: socksAgent });
    return origHttpsRequest.call(this, opts, options); // options is callback here
  };

  // Also patch https.get
  https.get = function (url, options, callback) {
    const req = https.request(url, options, callback);
    req.end();
    return req;
  };

  // Same for http
  const origHttpRequest = http.request;
  http.request = function (url, options, callback) {
    if (typeof url === 'string' || url instanceof URL) {
      if (typeof options === 'function') {
        callback = options;
        options = { agent: socksAgent };
      } else {
        options = Object.assign({}, options, { agent: socksAgent });
      }
      return origHttpRequest.call(this, url, options, callback);
    }
    const opts = Object.assign({}, url, { agent: socksAgent });
    return origHttpRequest.call(this, opts, options);
  };

  http.get = function (url, options, callback) {
    const req = http.request(url, options, callback);
    req.end();
    return req;
  };

  console.error('[proxy-setup] Patched http/https.request() with SOCKS5 agent');
} catch (err) {
  console.error('[proxy-setup] FAILED to patch http/https:', err.message);
}

// --- Layer 2: Patch undici global dispatcher (for fetch()) ---
try {
  const { SocksClient } = require('socks');
  const { Agent, setGlobalDispatcher } = require('undici');

  const agent = new Agent({
    connect: async (opts, cb) => {
      try {
        const host = opts.hostname || opts.host;
        const port = parseInt(opts.port || '443');

        // Don't proxy local connections
        if (host === '127.0.0.1' || host === 'localhost' || host === '::1') {
          const net = require('net');
          const socket = net.connect(port, host);
          socket.on('connect', () => cb(null, socket));
          socket.on('error', (err) => cb(err));
          return;
        }

        const { socket } = await SocksClient.createConnection({
          proxy: { host: SOCKS_HOST, port: SOCKS_PORT, type: 5 },
          command: 'connect',
          destination: { host, port },
        });

        if (opts.protocol === 'https:') {
          const tlsSocket = tls.connect({
            socket,
            servername: host,
            ALPNProtocols: ['http/1.1'],
          });
          tlsSocket.on('secureConnect', () => cb(null, tlsSocket));
          tlsSocket.on('error', (err) => cb(err));
        } else {
          cb(null, socket);
        }
      } catch (err) {
        cb(err);
      }
    },
  });

  setGlobalDispatcher(agent);
  console.error('[proxy-setup] Patched fetch() with SOCKS5 dispatcher');
} catch (err) {
  console.error('[proxy-setup] FAILED to patch fetch():', err.message);
}
