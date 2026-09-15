import fs from 'fs';
import path from 'path';
import translate from 'translate-google';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const dir = path.join(__dirname, '..'); // translations folder
const sourceFile = 'en_US.json';

const args = process.argv.slice(2);
let targetFile = args[0];

if (!targetFile) {
  console.log("Usage: node auto-translate.js <lang_code>");
  console.log("Example: node auto-translate.js pt_BR");
  process.exit(1);
}

if (!targetFile.endsWith('.json')) {
  targetFile += '.json';
}

if (targetFile === sourceFile) {
  console.error(`Error: ${sourceFile} is the canonical source locale and must not be auto-translated.`);
  process.exit(1);
}

const filePaths = fs.readdirSync(dir).filter(f => f.endsWith('.json'));

if (!filePaths.includes(targetFile)) {
  console.error(`Error: File ${targetFile} not found in ${dir}`);
  process.exit(1);
}
if (!filePaths.includes(sourceFile)) {
  console.error(`Error: Canonical source locale ${sourceFile} not found in ${dir}`);
  process.exit(1);
}

const langMap = {
  'es_AR.json': 'es', 'he_HE.json': 'iw', 'it_IT.json': 'it',
  'ja_JP.json': 'ja', 'ru_RU.json': 'ru', 'uk_UA.json': 'uk',
  'vi_VN.json': 'vi', 'zh_CN.json': 'zh-cn', 'pt_BR.json': 'pt',
  'hi_IN.json': 'hi', 'fr_FR.json': 'fr', 'de_DE.json': 'de',
  'ko_KR.json': 'ko', 'ar_SA.json': 'ar', 'tr_TR.json': 'tr'
};

const targetLang = langMap[targetFile];

if (!targetLang) {
  console.error(`Error: No google translate code mapped for ${targetFile}`);
  console.error(`Please add it to langMap in auto-translate.js`);
  process.exit(1);
}

function loadJson(fileName) {
  const filePath = path.join(dir, fileName);
  return JSON.parse(fs.readFileSync(filePath, 'utf-8'));
}

function assertKeyParity(sourceData, targetData) {
  const sourceKeys = new Set(Object.keys(sourceData));
  const targetKeys = new Set(Object.keys(targetData));
  const missing = [...sourceKeys].filter(k => !targetKeys.has(k)).sort();
  const extra = [...targetKeys].filter(k => !sourceKeys.has(k)).sort();

  if (missing.length === 0 && extra.length === 0) return;

  console.error(
    `Error: ${targetFile} keyset differs from ${sourceFile} ` +
    `(${missing.length} missing, ${extra.length} extra).`
  );
  if (missing.length > 0) {
    console.error(`  Missing sample: ${missing.slice(0, 5).join(' | ')}`);
  }
  if (extra.length > 0) {
    console.error(`  Extra sample: ${extra.slice(0, 5).join(' | ')}`);
  }
  console.error('Run the locale sync/clean pipeline before auto-translation.');
  process.exit(2);
}

async function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

// Strip lone surrogates and U+FFFD replacement chars so we never persist
// malformed text. Valid supplementary Unicode characters are UTF-16 surrogate
// pairs and must survive intact (emoji and some CJK characters depend on this).
function sanitizeTranslation(s) {
  if (typeof s !== 'string') return s;

  let clean = '';
  for (let i = 0; i < s.length; i++) {
    const code = s.charCodeAt(i);
    if (code === 0xFFFD) continue;

    if (code >= 0xD800 && code <= 0xDBFF) {
      const next = i + 1 < s.length ? s.charCodeAt(i + 1) : -1;
      if (next >= 0xDC00 && next <= 0xDFFF) {
        clean += s[i] + s[i + 1];
        i++;
      }
      continue;
    }

    if (code >= 0xDC00 && code <= 0xDFFF) continue;
    clean += s[i];
  }
  return clean;
}

function writeAtomic(filePath, data) {
  const json = JSON.stringify(data, null, 2);
  // Round-trip validate: if parse fails, abort the write entirely.
  try { JSON.parse(json); } catch (e) {
    throw new Error(`Refusing to write invalid JSON to ${filePath}: ${e.message}`);
  }
  const tmp = filePath + '.tmp';
  fs.writeFileSync(tmp, json, { encoding: 'utf-8' });
  fs.renameSync(tmp, filePath);
}

async function run() {
  console.log(`Processing ${targetFile} (to ${targetLang})...`);
  const filePath = path.join(dir, targetFile);
  const sourceData = loadJson(sourceFile);
  const data = loadJson(targetFile);

  assertKeyParity(sourceData, data);

  const keysToTranslate = Object.keys(data).filter(k => {
    const sourceValue = sourceData[k];
    const targetValue = data[k];
    if (typeof sourceValue === 'string' && sourceValue.trim().endsWith('/*keep*/')) return false;
    if (typeof targetValue === 'string' && targetValue.trim().endsWith('/*keep*/')) return false;
    return targetValue === k || !targetValue;
  });

  console.log(`Found ${keysToTranslate.length} keys to translate.`);
  if (keysToTranslate.length === 0) {
    console.log("Nothing to do.");
    return;
  }

  const batchSize = 100;
  const maxBatchAttempts = 3;
  let badStrings = 0;
  for (let i = 0; i < keysToTranslate.length; i += batchSize) {
    const batchKeys = keysToTranslate.slice(i, i + batchSize);
    console.log(` Translating batch ${i} to ${i + batchSize} of ${keysToTranslate.length}...`);

    let completed = false;
    for (let attempt = 1; attempt <= maxBatchAttempts && !completed; attempt++) {
      try {
        const batchValues = await translate(batchKeys, { to: targetLang });
        let batchBadStrings = 0;
        for (let j = 0; j < batchKeys.length; j++) {
          const raw = batchValues[j];
          const clean = sanitizeTranslation(raw);
          if (clean !== raw) batchBadStrings++;
          data[batchKeys[j]] = clean;
        }
        writeAtomic(filePath, data);
        badStrings += batchBadStrings;
        completed = true;
      } catch (err) {
        console.error(`Error on batch ${i} (attempt ${attempt}/${maxBatchAttempts}):`, err.message);
        if (attempt === maxBatchAttempts) {
          throw new Error(`Translation failed for batch ${i} after ${maxBatchAttempts} attempts`);
        }
        await sleep(5000);
      }
    }

    await sleep(1000);
  }

  writeAtomic(filePath, data);
  console.log(`Finished ${targetFile}.${badStrings > 0 ? ` (sanitized ${badStrings} malformed string(s))` : ''}`);
}

run().catch(err => {
  console.error('Translation failed:', err.message);
  process.exitCode = 1;
});
