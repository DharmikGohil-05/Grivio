// One-off generator: renders the GRIVIO logo PNG (512px) procedurally —
// rounded tile with the indigo→cyan brand gradient and a white trending-up
// arrow — using a tiny SDF rasterizer + Node's built-in zlib (no deps).
// Mirrors webapp/public/grivio_logo.svg exactly.
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const SIZE = 512;
const SS = 2; // 2x2 supersampling for anti-aliasing

// SDF helpers -------------------------------------------------------------
function sdRoundRect(px, py, half, rad) {
  const qx = Math.abs(px) - (half - rad);
  const qy = Math.abs(py) - (half - rad);
  const ox = Math.max(qx, 0), oy = Math.max(qy, 0);
  return Math.hypot(ox, oy) + Math.min(Math.max(qx, qy), 0) - rad;
}

function sdSegment(px, py, ax, ay, bx, by) {
  const abx = bx - ax, aby = by - ay;
  const apx = px - ax, apy = py - ay;
  const t = Math.max(0, Math.min(1, (apx * abx + apy * aby) / (abx * abx + aby * aby)));
  const dx = apx - t * abx, dy = apy - t * aby;
  return Math.hypot(dx, dy);
}

// Shapes ------------------------------------------------------------------
const HALF = SIZE / 2;
const RAD = 112;
const STROKE = 44;
const ARROW = [
  [453.3, 149.3, 288, 330.7],
  [288, 330.7, 181.3, 224],
  [181.3, 224, 42.7, 362.7],
  [341.3, 149.3, 469.3, 149.3],
  [469.3, 149.3, 469.3, 277.3],
];

// Brand gradient endpoints (match app_theme.dart / styles.css)
const C1 = [0x58, 0x65, 0xd9]; // indigo #5865D9
const C2 = [0x42, 0xbf, 0xc4]; // cyan   #42BFC4

function sample(x, y) {
  // Average SS×SS sub-pixels.
  let a = 0, r = 0, g = 0, b = 0;
  for (let sy = 0; sy < SS; sy++) {
    for (let sx = 0; sx < SS; sx++) {
      const px = x + (sx + 0.5) / SS;
      const py = y + (sy + 0.5) / SS;
      // Center-relative coords
      const cx = px - HALF, cy = py - HALF;

      // Tile
      const dTile = sdRoundRect(cx, cy, HALF - 1, RAD);
      const tileA = clamp01(0.5 - dTile);

      // Gradient color along the diagonal
      const t = clamp01((px + py) / (2 * SIZE));
      const tr = C1[0] + (C2[0] - C1[0]) * t;
      const tg = C1[1] + (C2[1] - C1[1]) * t;
      const tb = C1[2] + (C2[2] - C1[2]) * t;

      // Arrow (white) over the tile
      let dArrow = Infinity;
      for (const [ax, ay, bx, by] of ARROW) {
        const d = sdSegment(cx, cy, ax - HALF, ay - HALF, bx - HALF, by - HALF);
        if (d < dArrow) dArrow = d;
      }
      const arrowA = clamp01(0.5 - (dArrow - STROKE / 2)) * tileA;

      // Composite: transparent bg → tile → arrow
      const rA = tileA, rR = tr, rG = tg, rB = tb;
      const outA = arrowA + rA * (1 - arrowA);
      const outR = (255 * arrowA + rR * rA * (1 - arrowA)) / (outA || 1);
      const outG = (255 * arrowA + rG * rA * (1 - arrowA)) / (outA || 1);
      const outB = (255 * arrowA + rB * rA * (1 - arrowA)) / (outA || 1);

      a += outA; r += outR; g += outG; b += outB;
    }
  }
  const n = SS * SS;
  return [r / n, g / n, b / n, (a / n) * 255];
}

function clamp01(v) { return v < 0 ? 0 : v > 1 ? 1 : v; }

// PNG encode (RGBA, no filtering) ------------------------------------------
const raw = Buffer.alloc(SIZE * (SIZE * 4 + 1));
let o = 0;
for (let y = 0; y < SIZE; y++) {
  raw[o++] = 0; // filter: none
  for (let x = 0; x < SIZE; x++) {
    const [r, g, b, a] = sample(x, y);
    raw[o++] = Math.round(r);
    raw[o++] = Math.round(g);
    raw[o++] = Math.round(b);
    raw[o++] = Math.round(a);
  }
}

const table = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c;
  }
  return t;
})();
function crc32(buf) {
  let c = 0xffffffff;
  for (const byte of buf) c = table[(c ^ byte) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}

const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(SIZE, 0);
ihdr.writeUInt32BE(SIZE, 4);
ihdr[8] = 8;  // bit depth
ihdr[9] = 6;  // color type RGBA
const png = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  chunk('IHDR', ihdr),
  chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
  chunk('IEND', Buffer.alloc(0)),
]);

const out = process.argv[2];
fs.writeFileSync(out, png);
console.log(`Wrote ${out} (${png.length} bytes)`);
