import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';

// Only the files needed by the local interface can be served.
const files = new Map([
  ['/web/', [new URL('./index.html', import.meta.url), 'text/html; charset=utf-8']],
  ['/web/index.html', [new URL('./index.html', import.meta.url), 'text/html; charset=utf-8']],
  ['/web/style.css', [new URL('./style.css', import.meta.url), 'text/css; charset=utf-8']],
  ['/web/app.js', [new URL('./app.js', import.meta.url), 'text/javascript; charset=utf-8']],
  ['/web/solver-worker.js', [new URL('./solver-worker.js', import.meta.url), 'text/javascript; charset=utf-8']],
  ['/_build/js/release/build/cmd/web/web.js', [new URL('../_build/js/release/build/cmd/web/web.js', import.meta.url), 'text/javascript; charset=utf-8']],
]);

const server = createServer(async (request, response) => {
  response.setHeader('X-Content-Type-Options', 'nosniff');
  response.setHeader('Content-Security-Policy', "default-src 'self'; object-src 'none'; base-uri 'none'");
  response.setHeader('Cache-Control', 'no-store');
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    response.writeHead(405, { Allow: 'GET, HEAD', 'Content-Type': 'text/plain; charset=utf-8' });
    response.end('不支持的请求。');
    return;
  }
  let path;
  try { path = new URL(request.url, 'http://localhost').pathname; }
  catch { response.writeHead(400); response.end('请求无效。'); return; }
  if (path === '/' || path === '/web') {
    response.writeHead(302, { Location: '/web/' });
    response.end();
    return;
  }
  const file = files.get(path);
  if (!file) {
    response.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    response.end('页面不存在。');
    return;
  }
  try {
    const content = await readFile(file[0]);
    response.writeHead(200, { 'Content-Type': file[1] });
    response.end(request.method === 'HEAD' ? undefined : content);
  } catch {
    response.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    response.end('文件不可用。请先构建 JavaScript 版本。');
  }
});

server.on('error', () => {
  console.error('无法启动本地服务，请检查端口 8765 是否已被占用。');
  process.exitCode = 1;
});
server.listen(8765, '127.0.0.1', () => {
  console.log('MoonRoster 已启动：http://127.0.0.1:8765/web/');
  console.log('按 Ctrl+C 停止。');
});
