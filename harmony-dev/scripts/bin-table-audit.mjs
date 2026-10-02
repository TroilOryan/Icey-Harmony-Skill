#!/usr/bin/env node
/// 定长二进制表（rawfile/*.bin）体检 —— 只读，不改任何文件
///
/// 用法：
///   node bin-table-audit.mjs <表文件> <每元素 float 数> [索引文件1 索引文件2 ...]
///
/// 示例（星表：每星 5 个 float = ra,dec,mag,ci,con；lines.bin 是 Uint16 端点对）：
///   node bin-table-audit.mjs entry/src/main/resources/rawfile/stars.bin 5 \
///        entry/src/main/resources/rawfile/lines.bin
///
/// 输出四块：
///   A. 尺寸 / 数值合法性 / 量纲范围
///   B. 来源指纹分段（小数位分布、各列零值比例、坐标精度层级、相邻下标成对）
///   C. 索引文件对表的引用安全（最大下标、越界）
///   D. 近坐标重复对分档（用于甄别「真重复」与「双星分量/设计如此」）
import { readFileSync, existsSync } from 'node:fs';
import { basename } from 'node:path';

const [binPath, strideRaw, ...indexPaths] = process.argv.slice(2);
if (!binPath || !strideRaw) {
  console.error('用法：node bin-table-audit.mjs <表文件> <每元素 float 数> [索引文件...]');
  process.exit(2);
}
const STRIDE = Number(strideRaw);
if (!Number.isFinite(STRIDE) || STRIDE < 2) { console.error('每元素 float 数必须 ≥ 2'); process.exit(2); }

const raw = readFileSync(binPath);
const ab = raw.buffer.slice(raw.byteOffset, raw.byteOffset + raw.byteLength);
const f = new Float32Array(ab);
const count = raw.byteLength / (STRIDE * 4);
const evenly = Number.isInteger(count);
console.log(`文件：${binPath}`);
console.log(`  字节数 ${raw.byteLength}  ÷ (${STRIDE} float × 4) = ${count}${evenly ? '' : '  ⚠ 不能整除，可能有表头/尾填充'}`);
const N = Math.floor(count);

// ---------- A. 数值合法性 ----------
console.log('\n== A. 数值合法性 ==');
for (let k = 0; k < STRIDE; k++) {
  let nan = 0, inf = 0, mn = Infinity, mx = -Infinity, zero = 0;
  for (let i = 0; i < N; i++) {
    const v = f[i * STRIDE + k];
    if (Number.isNaN(v)) { nan++; continue; }
    if (!Number.isFinite(v)) { inf++; continue; }
    if (v === 0) zero++;
    if (v < mn) mn = v;
    if (v > mx) mx = v;
  }
  const flags = [];
  if (nan === N) flags.push('整列 NaN（字段缺列？）');
  else if (nan) flags.push(`NaN ${nan}`);
  if (inf) flags.push(`Inf ${inf}`);
  const zr = zero / N;
  if (zr > 0.3) flags.push(`零值占比 ${(zr * 100).toFixed(1)}%（疑似默认值填充）`);
  console.log(`  列${k}: 范围 [${mn.toFixed(4)}, ${mx.toFixed(4)}]  ${flags.join('  ') || 'ok'}`);
}

// ---------- B. 来源指纹 ----------
console.log('\n== B. 来源指纹（检测多来源拼接） ==');
/// 用「第 0 列需要多少位小数才能无损表示」找分段：
/// 高精度源（Float32 原生）需要 6+ 位；被四舍五入过的低质源只需 3 位。
/// 容差取 Float32 相对精度上限（≈3e-7 相对），避免把浮点误差误判成精度不足。
const decimals = v => {
  const a = Math.abs(v);
  const ulp = a === 0 ? 1e-30 : a * 3e-7;
  for (let k = 0; k <= 6; k++) {
    if (Math.abs(Number(v.toFixed(k)) - v) <= ulp) return k;
  }
  return 7;
};
const decDist = new Array(9).fill(0);
for (let i = 0; i < N; i++) decDist[Math.min(8, decimals(f[i * STRIDE]))]++;
console.log(`  第0列小数位分布：${decDist.map((c, d) => `${d}:${c}`).join(' ')}`);

/// 定位「低精度后缀块」候选：逐窗口统计各列的「恰好等于 0」比例。
/// 这是比小数位更稳的多来源指纹 —— 主段某列几乎不为 0，补录段却大面积是 0（默认值填充）。
/// 不自动下结论：打印每窗口的零值分布，由使用者确认分界（自动判定容易过度自信）。
const WINS = 20;
const winSize = Math.max(1, Math.ceil(N / WINS));
const globalZero = Array.from({ length: STRIDE }, (_, k) => {
  let z = 0; for (let i = 0; i < N; i++) if (f[i * STRIDE + k] === 0) z++;
  return z / N;
});
console.log(`  按 ${WINS} 段统计各列「恰好为 0」的比例（全局：${globalZero.map((r, k) => `列${k}=${(r * 100).toFixed(1)}%`).join(' ')}）`);
const suspects = [];
for (let w = 0; w < WINS; w++) {
  const s = w * winSize, e = Math.min(N, s + winSize);
  if (s >= N) break;
  const zeroPct = Array.from({ length: STRIDE }, (_, k) => {
    let z = 0; for (let i = s; i < e; i++) if (f[i * STRIDE + k] === 0) z++;
    return z / (e - s);
  });
  const decMode = (() => {
    const d = new Array(9).fill(0);
    for (let i = s; i < e; i++) d[Math.min(8, decimals(f[i * STRIDE]))]++;
    return d.indexOf(Math.max(...d));
  })();
  // 该窗口某列零值比例远高于全局 → 疑似换源
  const spike = zeroPct.findIndex((v, k) => v > 0.3 && globalZero[k] < 0.05);
  console.log(`    idx [${String(s).padStart(5)}, ${String(e).padStart(5)})  小数位众数 ${decMode}  零值比例 `
    + zeroPct.map(v => `${(v * 100).toFixed(0)}%`).join('/') + (spike >= 0 ? `   ← 列${spike} 零值激增，疑似换源` : ''));
  if (spike >= 0) suspects.push({ s, e, col: spike });
}
if (suspects.length) {
  console.log(`  → 疑似换源窗口 ${suspects.length} 个，最早起点 idx ≈ ${suspects[0].s}；`
    + `确认后用该下标作为「主表 / 补录块」分界，改动只落在分界之后`);
} else {
  console.log('  → 未发现零值激增，倾向单一来源（仍请人工核对末尾若干行）');
}

/// 尾部逐行转储（末 24 行）—— 找分界最可靠的手段，同时这份转储本身就是一份备份：
/// 表被覆盖且无版本控制时，可以靠它重建被删掉的行
const TAIL = Math.min(24, N);
console.log(`\n  尾部逐行（末 ${TAIL} 行；dec = 第0列需要的小数位数，多来源拼接处会明显下降）：`);
for (let i = N - TAIL; i < N; i++) {
  const cols = Array.from({ length: STRIDE }, (_, k) => f[i * STRIDE + k].toFixed(4)).join('  ');
  console.log(`    idx ${String(i).padStart(6)}  dec=${decimals(f[i * STRIDE])}  ${cols}`);
}

/// 相邻下标近坐标对（分量对 / 结构数据的指纹）
/// 用容差比较而非 Float32 位精确：同一目标的两次四舍五入可能只差 1 ULP
const nearSame = (i, j) => {
  for (let k = 0; k < Math.min(2, STRIDE); k++) {
    const a = f[i * STRIDE + k], b = f[j * STRIDE + k];
    if (Math.abs(a - b) > 1e-4 * Math.max(1, Math.abs(a))) return false;
  }
  return true;
};
let adjacentPairs = 0;
for (let i = 0; i + 1 < N; i++) if (nearSame(i, i + 1)) adjacentPairs++;
console.log(`  相邻下标近坐标对：${adjacentPairs} 处${adjacentPairs ? '（常见于双星分量等「分量对」约定，未必是缺陷）' : ''}`);

/// 各列零值比例（缺失列的指纹）
console.log('  各列零值比例： ' + Array.from({ length: STRIDE }, (_, k) => {
  let z = 0; for (let i = 0; i < N; i++) if (f[i * STRIDE + k] === 0) z++;
  return `列${k}=${(z / N * 100).toFixed(1)}%`;
}).join('  '));

// ---------- C. 索引引用安全 ----------
console.log('\n== C. 索引引用安全 ==');
let refMax = -1;
const kindOf = ip => /\.json$/i.test(ip) ? 'json'
  : /\.(bin|dat)$/i.test(ip) || !/\./.test(basename(ip)) ? 'u16' : 'skip';
for (const ip of indexPaths) {
  if (!existsSync(ip)) { console.log(`  ${ip}：不存在，跳过`); continue; }
  const kind = kindOf(ip);
  if (kind === 'u16') {
    const b = readFileSync(ip);
    if (b.byteLength % 2 !== 0) { console.log(`  ${ip}：字节数 ${b.byteLength} 非偶数，不是 Uint16 表，跳过`); continue; }
    const u16 = new Uint16Array(b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength));
    let mx = -1, oob = 0;
    for (const v of u16) { if (v > mx) mx = v; if (v >= N) oob++; }
    refMax = Math.max(refMax, mx);
    console.log(`  ${basename(ip)}：${u16.length} 个 Uint16  最大下标 ${mx}  越界(${N}) ${oob} 个  ${oob ? '✗' : 'ok'}`);
  } else if (kind === 'json') {
    let j;
    try { j = JSON.parse(readFileSync(ip, 'utf8')); } catch (e) { console.log(`  ${basename(ip)}：JSON 解析失败，跳过`); continue; }
    const idxs = [];
    (function walk(o) {
      if (Array.isArray(o)) o.forEach(walk);
      else if (o && typeof o === 'object') for (const [k, v] of Object.entries(o)) {
        if ((k === 'star' || k === 'index' || /Idx$/.test(k)) && Number.isInteger(v)) idxs.push({ k, v });
        else walk(v);
      }
    })(j);
    if (idxs.length) {
      const mx = Math.max(...idxs.map(x => x.v));
      const oob = idxs.filter(x => x.v >= N).length;
      console.log(`  ${basename(ip)}：${idxs.length} 个下标字段，最大 ${mx}，越界 ${oob} 个  ${oob ? '✗' : 'ok'}`);
      refMax = Math.max(refMax, mx);
    } else {
      console.log(`  ${basename(ip)}：无下标字段`);
    }
  }
}
if (refMax >= 0) {
  console.log(`\n  ★ 改动区间必须整体位于 [0, ${refMax}] 之外，否则需要重映射所有索引`);
  console.log(`     即：只在 idx > ${refMax} 的区间内删除/追加 → 现有索引全部无变化`);
}

// ---------- D. 近坐标重复分档 ----------
if (STRIDE >= 2) {
  console.log('\n== D. 近坐标重复对分档（需第0列=RA°/x、第1列=Dec°/y、第2列=星等/权重） ==');
  const D2R = Math.PI / 180, R2D = 180 / Math.PI;
  const sep = (i, j) => Math.acos(Math.max(-1, Math.min(1,
    Math.sin(f[i * STRIDE + 1] * D2R) * Math.sin(f[j * STRIDE + 1] * D2R)
    + Math.cos(f[i * STRIDE + 1] * D2R) * Math.cos(f[j * STRIDE + 1] * D2R)
    * Math.cos((f[i * STRIDE] - f[j * STRIDE]) * D2R)))) * R2D;
  const BANDS = [[0, 0.005], [0.005, 0.01], [0.01, 0.02], [0.02, 0.05], [0.05, 0.15]];
  const rows = [];
  for (let i = 0; i < N; i++) {
    for (let j = i + 1; j < N; j++) {
      const dRa = Math.abs(f[i * STRIDE] - f[j * STRIDE]);
      if (dRa > 0.15 && dRa < 359.85) continue;
      if (Math.abs(f[i * STRIDE + 1] - f[j * STRIDE + 1]) > 0.15) continue;
      const d = sep(i, j);
      if (d < 0.15) rows.push({ i, j, d, dm: f[i * STRIDE + 2] - f[j * STRIDE + 2] });
    }
  }
  for (const [lo, hi] of BANDS) {
    const g = rows.filter(r => r.d >= lo && r.d < hi);
    const conflict = g.filter(r => Math.abs(r.dm) > 0.3);
    const adjacent = conflict.filter(r => r.j === r.i + 1).length;
    console.log(`  角距 [${lo},${hi})：${String(g.length).padStart(4)} 组，其中权重差 >0.3 的 ${String(conflict.length).padStart(3)} 组（含相邻下标对 ${adjacent}）`);
  }
  console.log('  判读：相邻下标的近坐标对多为「分量对」约定（设计如此）；');
  console.log('        非相邻、且权重差系统性地偏向某一侧 → 才是真重复（多来源拼接的典型症状）');
}

console.log('\n（本脚本只读，不修改任何文件）');
