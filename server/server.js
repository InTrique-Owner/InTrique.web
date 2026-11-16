const http = require('http');
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const PORT = process.env.PORT || 3000;
// Static site lives at the repository root, one level above this file.
const ROOT = path.join(__dirname, '..');

const MIME_TYPES = {
  '.html': 'text/html; charset=UTF-8',
  '.css': 'text/css; charset=UTF-8',
  '.js': 'application/javascript; charset=UTF-8',
  '.json': 'application/json; charset=UTF-8',
  '.webmanifest': 'application/manifest+json; charset=UTF-8',
  '.txt': 'text/plain; charset=UTF-8',
  '.xml': 'application/xml; charset=UTF-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.gif': 'image/gif',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.eot': 'application/vnd.ms-fontobject',
  '.mp3': 'audio/mpeg',
  '.wav': 'audio/wav',
  '.mp4': 'video/mp4',
  '.webm': 'video/webm',
  '.pdf': 'application/pdf',
  '.zip': 'application/zip',
  '.exe': 'application/octet-stream',
  '.msi': 'application/octet-stream'
};

function sendText(res, status, message, extraHeaders = {}) {
  res.writeHead(status, { 'Content-Type': 'text/plain; charset=UTF-8', ...extraHeaders });
  res.end(message);
}

const server = http.createServer((req, res) => {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    return sendText(res, 405, '405 Method Not Allowed', { Allow: 'GET, HEAD' });
  }

  let reqPath;
  try {
    reqPath = decodeURI(req.url.split('?')[0]);
  } catch {
    return sendText(res, 400, '400 Bad Request');
  }

  if (reqPath.includes('\0')) {
    return sendText(res, 400, '400 Bad Request');
  }

  if (reqPath === '/') reqPath = '/index.html';

  const filePath = path.normalize(path.join(ROOT, reqPath));
  const relative = path.relative(ROOT, filePath);
  const escapesRoot = relative === '..' || relative.startsWith(`..${path.sep}`) || path.isAbsolute(relative);
  if (escapesRoot) {
    return sendText(res, 403, '403 Forbidden');
  }

  let resolvedPath = filePath;
  if (!fs.existsSync(resolvedPath) && fs.existsSync(resolvedPath + '.html')) {
    resolvedPath += '.html';
  }

  fs.stat(resolvedPath, (err, stats) => {
    if (err || !stats.isFile()) {
      return sendText(res, 404, '404 Not Found');
    }

    const ext = path.extname(resolvedPath).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';
    const acceptEncoding = req.headers['accept-encoding'] || '';

    const maxAge = ext === '.html' ? 600 : 86400;
    const headers = {
      'Content-Type': contentType,
      'Cache-Control': `public, max-age=${maxAge}`,
      'Vary': 'Accept-Encoding',
      'X-Content-Type-Options': 'nosniff',
      'X-Frame-Options': 'SAMEORIGIN',
      'Referrer-Policy': 'strict-origin-when-cross-origin'
    };

    const isCompressible = /^(text\/|application\/(javascript|json|xml|manifest\+json)|image\/svg\+xml)/.test(contentType);
    const useGzip = isCompressible && acceptEncoding.includes('gzip');
    const useDeflate = !useGzip && isCompressible && acceptEncoding.includes('deflate');

    if (useGzip) {
      headers['Content-Encoding'] = 'gzip';
    } else if (useDeflate) {
      headers['Content-Encoding'] = 'deflate';
    } else {
      headers['Content-Length'] = stats.size;
    }

    res.writeHead(200, headers);
    if (req.method === 'HEAD') return res.end();

    const rawStream = fs.createReadStream(resolvedPath);
    rawStream.on('error', () => res.destroy());

    if (useGzip) {
      rawStream.pipe(zlib.createGzip()).pipe(res);
    } else if (useDeflate) {
      rawStream.pipe(zlib.createDeflate()).pipe(res);
    } else {
      rawStream.pipe(res);
    }
  });
});

server.listen(PORT, () => {
  console.log(`InTrique server running at http://localhost:${PORT}`);
});
