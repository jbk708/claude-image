// Loaded via NODE_OPTIONS="--require /proxy-setup.js"
// Routes all fetch() traffic through Tailscale's SOCKS5 proxy
const tls = require('tls');
const { SocksClient } = require('socks');
const { Agent, setGlobalDispatcher } = require('undici');

const SOCKS_HOST = '127.0.0.1';
const SOCKS_PORT = parseInt(process.env.TS_SOCKS_PORT || '1056');

const agent = new Agent({
  connect: async (opts, cb) => {
    try {
      const { socket } = await SocksClient.createConnection({
        proxy: { host: SOCKS_HOST, port: SOCKS_PORT, type: 5 },
        command: 'connect',
        destination: {
          host: opts.hostname,
          port: parseInt(opts.port || '443'),
        },
      });

      if (opts.protocol === 'https:') {
        const tlsSocket = tls.connect({
          socket,
          servername: opts.hostname,
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
console.error('[proxy-setup] fetch() patched to use SOCKS5 proxy on', SOCKS_HOST + ':' + SOCKS_PORT);
