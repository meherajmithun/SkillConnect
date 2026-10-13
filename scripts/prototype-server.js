import http from 'node:http';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = fileURLToPath(new URL('../docs/sprint-1/prototype',import.meta.url));
const types = { '.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8' };
http.createServer(async (req,res) => {
  try {
    const filename = path.resolve(root,`.${new URL(req.url,'http://localhost').pathname === '/' ? '/index.html' : decodeURIComponent(new URL(req.url,'http://localhost').pathname)}`);
    if (!filename.startsWith(`${root}${path.sep}`)) throw new Error();
    res.setHeader('Content-Type',types[path.extname(filename)] || 'application/octet-stream');
    res.end(await readFile(filename));
  } catch { res.statusCode = 404; res.end('Not found'); }
}).listen(Number(process.env.PROTOTYPE_PORT || 8082),'127.0.0.1',() => console.log('Prototype: http://localhost:8082'));
