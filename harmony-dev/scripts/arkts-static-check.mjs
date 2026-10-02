#!/usr/bin/env node
/// ArkTS/ETS 静态一致性检查（无 hvigor 构建时的兜底）
///
/// 用法：node arkts-static-check.mjs <项目根目录> [--ets-src <相对路径>] [--media <相对路径>]
///   例：node arkts-static-check.mjs /path/to/MyHarmonyApp
///
/// 检查五项：
///   1) 括号配平（模板字面量感知的状态机剥离注释/字符串）
///   2) import 相对路径可解析
///   3) Class.member 引用有定义（抓 "类名打错/符号不存在" 这类必编译失败项）
///   4) SFIcons.sf_xxx → resources/base/media/<name>.svg 存在
///   5) AppStorage 键的写入/读取接线（只读键作为提示，不计失败）
///
/// 退出码：0 = ALL OK，1 = 有真实问题，2 = 用法错误
import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { join, dirname, resolve, basename } from 'node:path';

// ---------------- 参数 ----------------
const argv = process.argv.slice(2);
const ROOT = argv[0];
if (!ROOT) {
  console.error('用法：node arkts-static-check.mjs <项目根目录> [--ets-src <路径>] [--media <路径>]');
  process.exit(2);
}
const opt = (name, dflt) => {
  const i = argv.indexOf('--' + name);
  return i >= 0 && argv[i + 1] ? argv[i + 1] : dflt;
};

/// 自动找源码根：优先 <root>/entry/src/main/ets，退化为任意 */src/main/ets 或 **/ets
function autoEtsSrc(root) {
  const tryList = [join(root, 'entry/src/main/ets')];
  try {
    for (const e of readdirSync(root, { withFileTypes: true })) {
      if (e.isDirectory() && e.name !== 'node_modules' && e.name !== 'oh_modules') {
        tryList.push(join(root, e.name, 'src/main/ets'));
      }
    }
  } catch (_) {}
  for (const p of tryList) if (existsSync(p)) return p;
  return null;
}
/// 源码根：显式传入优先，否则自动探测
const etsOpt = opt('ets-src', '');
const SRC_EFFECTIVE = etsOpt ? resolve(ROOT, etsOpt) : autoEtsSrc(ROOT);
if (!SRC_EFFECTIVE) { console.error(`在 ${ROOT} 下找不到 ets 源码目录，请用 --ets-src 指定`); process.exit(2); }
const MAIN = dirname(SRC_EFFECTIVE);                       // .../src/main
const mediaOpt = opt('media', '');
const MEDIA = mediaOpt ? resolve(ROOT, mediaOpt) : join(MAIN, 'resources/base/media');

const files = [];
(function walk(d) {
  for (const e of readdirSync(d, { withFileTypes: true })) {
    const p = join(d, e.name);
    if (e.isDirectory()) walk(p); else if (e.name.endsWith('.ets')) files.push(p);
  }
})(SRC_EFFECTIVE);

const rel = p => p.replace(SRC_EFFECTIVE, '').replace(/^[\\/]/, '');
console.log(`项目根：${ROOT}`);
console.log(`源码目录：${SRC_EFFECTIVE}`);
console.log(`图标目录：${MEDIA}`);
console.log(`ets 文件：${files.length} 个\n`);

// ---------------- 状态机剥离注释/字符串 ----------------
/// 模板字面量从 ` 到配对 ` 之间整体跳过（含 ${} 表达式内的括号），
/// 只跟踪 ${ } 嵌套深度以找到正确的结束反引号 —— 这样不会把模板正文里的 {} 计入配平
function strip(src) {
  let out = '';
  let i = 0;
  const n = src.length;
  let inTpl = false, tplBrace = 0;
  while (i < n) {
    const c = src[i], c2 = src.slice(i, i + 2);
    if (inTpl) {
      if (c2 === '${') { tplBrace += 1; i += 2; continue; }
      if (c === '{') { tplBrace += 1; i++; continue; }
      if (c === '}') { if (tplBrace > 0) tplBrace -= 1; i++; continue; }
      if (c === '`' && tplBrace === 0) { inTpl = false; i++; continue; }
      if (c === '\n') out += '\n';
      i++; continue;
    }
    if (c === '\n') { out += '\n'; i++; continue; }
    if (c2 === '//') { while (i < n && src[i] !== '\n') i++; continue; }
    if (c2 === '/*') { i += 2; while (i < n && src.slice(i, i + 2) !== '*/') { if (src[i] === '\n') out += '\n'; i++; } i += 2; continue; }
    if (c === '`') { inTpl = true; tplBrace = 0; i++; continue; }
    if (c === '\'' || c === '"') {
      const q = c; i++;
      while (i < n && src[i] !== q) { if (src[i] === '\\') i++; i++; }
      i++; out += '""'; continue;
    }
    out += c; i++;
  }
  return out;
}

let fail = 0;
const problems = [];
const note = m => console.log('  ' + m);

// ---------------- 1. 配平 ----------------
console.log('== 1. 括号配平 ==');
const stripped = new Map();
let balBad = 0;
for (const p of files) {
  const s = strip(readFileSync(p, 'utf8'));
  stripped.set(p, s);
  const cnt = re => (s.match(re) || []).length;
  const b1 = cnt(/\{/g), b2 = cnt(/\}/g), p1 = cnt(/\(/g), p2 = cnt(/\)/g), q1 = cnt(/\[/g), q2 = cnt(/\]/g);
  if (b1 !== b2 || p1 !== p2 || q1 !== q2) {
    balBad++; fail++;
    problems.push(`${rel(p)}: {} ${b1}/${b2}  () ${p1}/${p2}  [] ${q1}/${q2}`);
    console.log(`  ✗ ${rel(p)}  {} ${b1}/${b2}  () ${p1}/${p2}  [] ${q1}/${q2}`);
  }
}
if (!balBad) note(`全部 ${files.length} 个文件配平 OK`);
if (balBad) note('提示：若确认源码本身没问题，多半是 strip() 未覆盖的新语法（嵌套模板/正则字面量），先修检查器');

// ---------------- 2. import 路径 ----------------
console.log('\n== 2. import 相对路径解析 ==');
let impBad = 0;
for (const p of files) {
  const s = stripped.get(p);
  for (const m of s.matchAll(/from\s+'(\.\.?\/[^']+)'/g)) {
    const cand = [resolve(dirname(p), m[1]) + '.ets', resolve(dirname(p), m[1]) + '.ts',
                  resolve(dirname(p), m[1]) + '/index.ets'];
    if (!cand.some(existsSync)) {
      impBad++;
      problems.push(`${rel(p)} → 找不到 ${m[1]}`);
      console.log(`  ✗ ${rel(p)} → ${m[1]}`);
    }
  }
}
if (!impBad) note('全部相对 import 可解析 OK');

// ---------------- 3. 成员引用 ----------------
console.log('\n== 3. 成员引用存在性 ==');
/// 系统/框架类型白名单 —— 出现误报就往这里加，不要改业务代码
const SKIP_CLASS = new Set(['Math', 'Number', 'String', 'Object', 'Array', 'JSON', 'Promise', 'Date', 'Set', 'Map',
  'WeakMap', 'WeakSet', 'RegExp', 'Error', 'TypeError', 'RangeError', 'Float32Array', 'Float64Array', 'Uint16Array',
  'Int16Array', 'Int32Array', 'Uint8Array', 'Uint8ClampedArray', 'Int8Array', 'ArrayBuffer', 'DataView', 'Buffer',
  'URL', 'URLSearchParams', 'Function', 'Boolean', 'Symbol', 'BigInt', 'Iterator', 'IIterator', 'console',
  'Color', 'FontWeight', 'FlexAlign', 'Alignment', 'HorizontalAlign', 'VerticalAlign', 'TextAlign', 'TextOverflow',
  'Curve', 'BarState', 'BarMode', 'BarPosition', 'EdgeEffect', 'TabsCacheMode', 'NavigationMode', 'HitTestMode',
  'GestureMode', 'PanGesture', 'PinchGesture', 'GestureGroup', 'TapGesture', 'LongPressGesture', 'SwipeGesture',
  'TransitionEffect', 'SliderStyle', 'SliderChangeMode', 'FlexWrap', 'FlexDirection', 'InputType', 'Direction',
  'Visibility', 'Axis', 'BlurStyle', 'ShadowStyle', 'LinearGradient', 'SafeAreaType', 'SafeAreaEdge', 'SizeOptions',
  'Rect', 'ResourceColor', 'ResourceStr', 'SymbolGlyph', 'NavPathStack', 'NavPathInfo', 'AppStorage',
  'CanvasRenderingContext2D', 'RenderingContextSettings', 'LoadingProgress', 'LocalStorage', 'PersistentStorage',
  'common', 'preferences', 'window', 'display', 'hilog', 'util', 'resourceManager', 'wantAgent', 'abilityAccessCtrl',
  'bundleManager', 'BusinessError', 'TypedValue', 'ConfigurationConstant', 'fileIo', 'photoAccessHelper', 'picker',
  'media', 'audio', 'sensor', 'vibrator', 'pasteboard', 'promptAction', 'router', 'uiObserver', 'mediaquery']);
function exportsOf(file) {
  if (!existsSync(file)) return null;
  const s = strip(readFileSync(file, 'utf8'));
  const statics = new Set();
  for (const m of s.matchAll(/\bstatic\s+(?:readonly\s+|get\s+|async\s+)?([A-Za-z_$][\w$]*)\s*[:(=]/g)) statics.add(m[1]);
  return { src: s, statics };
}
const defCache = new Map();
function findDefFile(symbol) {
  if (defCache.has(symbol)) return defCache.get(symbol);
  const re = new RegExp(`export\\s+(?:class|struct|const|enum|interface|function|type)\\s+${symbol}\\b`);
  let hit = null;
  for (const p of files) if (re.test(stripped.get(p))) { hit = p; break; }
  defCache.set(symbol, hit);
  return hit;
}
let refBad = 0;
for (const p of files) {
  const s = stripped.get(p);
  for (const m of s.matchAll(/\b([A-Z][A-Za-z0-9_$]*)\.([a-zA-Z_$][\w$]*)\b/g)) {
    const cls = m[1], mem = m[2];
    if (SKIP_CLASS.has(cls)) continue;
    const def = findDefFile(cls);
    if (!def) continue;
    const ex = exportsOf(def);
    if (!ex) continue;
    if (ex.statics.has(mem)) continue;
    if (new RegExp(`\\b${mem}\\b`).test(ex.src)) continue;
    refBad++; fail++;
    problems.push(`${rel(p)}: ${cls}.${mem} 未在 ${rel(def)} 中定义`);
    console.log(`  ✗ ${rel(p)}: ${cls}.${mem} 未在 ${rel(def)} 中定义`);
  }
}
if (!refBad) note('全部 Class.member 引用可解析 OK');

// ---------------- 4. 图标资源 ----------------
console.log('\n== 4. 图标 → SVG 资源 ==');
const iconCandidates = files.filter(p => /sficon_names\.ets$/.test(p));
if (!iconCandidates.length) note('未找到 sficon_names.ets，跳过');
else {
  const iconSrc = readFileSync(iconCandidates[0], 'utf8');
  const icons = [...iconSrc.matchAll(/static\s+readonly\s+(\w+)\s*:\s*string\s*=\s*'([^']+)'/g)]
    .map(m => ({ sym: m[1], res: m[2] }));
  let iconBad = 0;
  for (const { sym, res } of icons) {
    if (!existsSync(join(MEDIA, res + '.svg'))) {
      iconBad++; fail++;
      problems.push(`图标 ${sym} → ${res}.svg 缺失`);
      console.log(`  ✗ ${sym} → ${res}.svg 缺失`);
    }
  }
  if (!iconBad) note(`全部 ${icons.length} 个图标 SVG 就位 OK`);
  const allSrc = files.map(p => stripped.get(p)).join('\n');
  const unused = icons.filter(({ sym }) => (allSrc.match(new RegExp(`\\.${sym}\\b`, 'g')) || []).length === 0).map(i => i.sym);
  if (unused.length) note(`（未被引用的图标名 ${unused.length} 个：${unused.join(', ')}）`);
}

// ---------------- 5. AppStorage 键 ----------------
console.log('\n== 5. AppStorage 键一致性 ==');
const rawAll = files.map(p => readFileSync(p, 'utf8')).join('\n');
const written = new Set([...rawAll.matchAll(/AppStorage\.(?:setOrCreate|set)<[^>]*>\(\s*'([^']+)'/g)].map(m => m[1]));
const read = new Set([...rawAll.matchAll(/(?:@StorageLink|@StorageProp)\('([^']+)'|AppStorage\.get<[^>]*>\('([^']+)'/g)]
  .map(m => m[1] ?? m[2]));
const dangling = [...read].filter(k => !written.has(k));
const neverRead = [...written].filter(k => !read.has(k));
console.log(`  写入键 ${written.size} 个，读取键 ${read.size} 个`);
if (dangling.length) note(`提示：${dangling.length} 个键只被读取、无写入点 → ${dangling.join(', ')}`);
if (neverRead.length) note(`提示：${neverRead.length} 个键只写不读 → ${neverRead.join(', ')}`);
if (!dangling.length && !neverRead.length) note('键的读写接线完整 OK');

// ---------------- 汇总 ----------------
console.log(`\n==== 静态检查：${fail === 0 && impBad === 0 && refBad === 0 ? 'ALL OK' : '存在问题'} ====`);
if (problems.length) { console.log('\n问题清单：'); problems.forEach(x => console.log('  - ' + x)); }
console.log('\n注意：本检查只覆盖「低级错误」，不能替代编译。真机相关的渲染/传感器/权限行为仍需上机验证。');
process.exit(fail === 0 ? 0 : 1);
