import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
const major = Number(process.versions.node.split('.')[0]);
let failures = 0;
function check(label,ok,detail) { console.log(`${ok ? 'OK' : 'MISSING'} ${label}: ${detail}`); if(!ok) failures++; }
check('Node.js',major >= 22,process.version);
for(const command of ['npm','flutter','dart']) {
  const result = spawnSync('which',[command],{ encoding:'utf8' }); check(command,result.status === 0,result.stdout.trim() || 'not on PATH');
}
for(const file of ['package-lock.json','node_modules','mobile/pubspec.lock']) check(file,existsSync(file),'project prerequisite');
console.log('Next: npm run check; npm test; make check-mobile test-mobile');
process.exitCode = failures ? 1 : 0;
