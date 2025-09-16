const { WASI } = require('wasi');
const opts = { args: [], env: process.env, preopens: {'/': process.cwd()} };
const candidates = ['wasi_snapshot_preview1','wasi_unstable','preview1'];
let ok=false;
for (const v of candidates){
  try {
    new WASI({...opts, version:v});
    console.log('constructed with version', v);
    ok = true;
    break;
  } catch (e) {
    console.error('version', v, 'failed:', e.message);
  }
}
if (!ok) {
  try {
    new WASI(opts);
    console.log('constructed without version');
    ok = true;
  } catch (e) {
    console.error('construct without version failed:', e.message);
    process.exitCode = 2;
  }
}
