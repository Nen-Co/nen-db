const fs = require('fs');
const path = require('path');
const https = require('https');
const { execSync } = require('child_process');
const crypto = require('crypto');

function platformKey() {
  const plat = process.platform; // 'darwin'|'linux'|'win32'
  const arch = process.arch;     // 'x64'|'arm64' ...
  if (plat === 'darwin' && arch === 'x64') return 'darwin-x86_64';
  if (plat === 'darwin' && arch === 'arm64') return 'darwin-aarch64';
  if (plat === 'linux' && arch === 'x64') return 'linux-x86_64';
  if (plat === 'win32' && arch === 'x64') return 'win32-x86_64';
  return null;
}

function download(url, dest) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(dest);
    https.get(url, (res) => {
      if (res.statusCode !== 200) return reject(new Error('Failed to download ' + url + ' status ' + res.statusCode));
      res.pipe(file);
      file.on('finish', () => file.close(resolve));
    }).on('error', (err) => {
      try { fs.unlinkSync(dest); } catch (e) {}
      reject(err);
    });
  });
}

async function main() {
  const key = platformKey();
  if (!key) {
    console.log('nendb: prebuilt binary not available for this platform; skipping download.');
    return;
  }

  const version = process.env.NENDB_RELEASE_TAG || process.env.NPM_PACKAGE_VERSION || 'latest';
  const archiveName = `nendb-${key}.${process.platform === 'win32' ? 'zip' : 'tar.gz'}`;
  const assetName = archiveName;
  const checksumName = `${archiveName}.sha256`;
  const url = `https://github.com/Nen-Co/nendb/releases/download/${version}/${assetName}`;
  const checksumUrl = `https://github.com/Nen-Co/nendb/releases/download/${version}/${checksumName}`;

  const outDir = path.join(__dirname, '..', '..', 'bin');
  fs.mkdirSync(outDir, { recursive: true });
  const dest = path.join(outDir, assetName);
  const checksumDest = path.join(outDir, checksumName);

  console.log(`nendb: downloading ${assetName} from ${url}`);

  // Basic retry logic for flaky networks
  const maxAttempts = 3;
  let attempt = 0;
  try {
    // download checksum first (best-effort)
    try {
      await download(checksumUrl, checksumDest);
    } catch (e) {
      // checksum may not exist for older releases; continue
      try { fs.unlinkSync(checksumDest); } catch (_) {}
    }

    while (attempt < maxAttempts) {
      attempt++;
      try {
        await download(url, dest);

        // verify checksum if we have one
        if (fs.existsSync(checksumDest)) {
          const expected = fs.readFileSync(checksumDest, 'utf8').trim().split(/\s+/)[0];
          const actual = sha256OfFile(dest);
          if (expected !== actual) {
            throw new Error(`checksum mismatch: expected ${expected} got ${actual}`);
          }
        }

        console.log('nendb: download complete, extracting...');
        if (process.platform === 'win32') {
          execSync(`powershell -command "Expand-Archive -LiteralPath '${dest}' -DestinationPath '${outDir}'"`, { stdio: 'inherit' });
        } else {
          execSync(`tar -xzf ${dest} -C ${outDir}`, { stdio: 'inherit' });
        }
        console.log('nendb: installed binaries to', outDir);
        break;
      } catch (err) {
        console.warn(`nendb: attempt ${attempt} failed:`, err.message);
        try { fs.unlinkSync(dest); } catch (_) {}
        if (attempt >= maxAttempts) {
          throw err;
        }
        await new Promise((r) => setTimeout(r, 1000 * attempt));
      }
    }
  } catch (err) {
    console.warn('nendb: failed to download or extract prebuilt binary:', err.message);
    // leave it to user to build from source if desired
  }
}

function sha256OfFile(filePath) {
  const hash = crypto.createHash('sha256');
  const data = fs.readFileSync(filePath);
  hash.update(data);
  return hash.digest('hex');
}

main();
