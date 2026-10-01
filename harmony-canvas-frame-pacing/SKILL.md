---
name: harmony-canvas-frame-pacing
description: HarmonyOS/ArkUI Canvas 全屏自绘（星图/地图/仪表）的帧率与跟手延迟诊断方法。用于「很卡」「晃手机跟不上」「分段打点全是 0」「优化了却没变化」「调用数比数据量还大」这类反复出现的性能问题：先修打点（高精度时钟 + 累加口径），再用「调用数 ≤ 数据量上限」做数值体检 + Python 离线复现过滤器，然后按「每帧 Canvas 调用数 × ~11µs」的成本模型定位，最后让数据源样本直接出帧（脏标记只是必要条件）。触发词：ArkUI 卡顿、Canvas 掉帧、跟手延迟、性能打点、perf 日志、帧耗时、setInterval 渲染循环、脏标记重绘、requestAnimationFrame 替代、Float64Array 未分配、NaN 静默失效。
agent_created: true
---

# ArkUI Canvas 自绘的帧率与跟手延迟

全屏 Canvas 逐帧重绘（星图、地图、雷达）在 HarmonyOS 上很容易陷入「改了很多轮还是很卡」。
本 skill 是踩过五轮无效优化后总结的**诊断顺序**：先修打点，再谈优化。

## 铁律（优先级从高到低）

1. **读数自相矛盾时，先怀疑打点，不要怀疑代码。**
   典型矛盾：`stars 0.03ms / 457 颗` 物理上不可能（457 次绘制不可能 30µs），
   而同一行 `art 1ms / 78 次调用` 却合理 —— 这时答案已经写在脸上：两个数的**口径不同**。
2. **帧内计时禁用 `Date.now()`**。它只有 ~1ms 分辨率，而单次 Canvas NAPI 调用只要
   10~20µs —— 所有分段都会读成 0.00，让你误判「时间不在这些代码里」（然后连续几轮
   去优化根本不占时间的地方）。用高精度单调时钟：
   ```ts
   import { systemDateTime } from '@kit.BasicServicesKit';
   private static nowHi(): number {
     return systemDateTime.getUptime(systemDateTime.TimeType.STARTUP, true) / 1e6; // ms，亚毫秒
   }
   ```
   （`getUptime(type, true)` 返回**纳秒**；`STARTUP`=含休眠，`ACTIVE`=不含。API 10+）
3. **累加口径必须显式对齐**：窗口累加量 ÷ 帧数，每帧清零量 ÷ 1。
   最阴的 bug：累加器**每帧清零**，打点却仍 `v / frames` → 读数小了「帧数」倍，
   看上去像「这项没有开销」。本项目曾因此把 `stars 5ms / eq 7ms` 读成 `0.03 / 0.04`，
   连续五轮优化全打偏。
4. **对「调用次数」打点，不要对「耗时」打点。** 成本模型：
   `帧耗时 ≈ 每帧 Canvas 调用数 × 单次成本`，但**单次成本按调用类型差 5 倍以上**，
   用实测反推再算总账（本项目实测）：

   | 调用类型 | 实测单次 | 依据 |
   |---|---|---|
   | `moveTo`/`lineTo`（建路径） | ~1.7~2.6µs | `eq 4.4ms/2546`、`grid 1.4ms/548` |
   | `fill`（含光栅化） | ~7~8µs | `star 5.1ms/651`、`art 1ms/88` |

   ⇒ **优先砍 `fill` 的次数和填充面积；建路径的调用便宜，可以多几条**（但几千条仍不可忽略）。
   给每类绘制埋计数器（grid/eq/line/star/text/misc），比埋计时器有用得多 ——
   一次调用测得再准也测不出「有多少次」。
   反过来也能用这个表**校验打点是否可信**：算出 2546 次建路径却只报 4.4ms 是自洽的；
   若某类反推出的单次成本和上表差一个数量级，先怀疑打点而不是代码。
5. **任何 `c.*` 调用都是调用**：`fillStyle`/`globalAlpha`/`lineWidth`/`strokeStyle`
   这些 setter 也算。能烘进 `fillStyle` 的 alpha 就别设 `globalAlpha`。

## Canvas 尺寸口径：全是 vp，禁止 px2vp（2026-09-29 实测，最贵的一个坑）

**`CanvasRenderingContext2D.width/height` 与所有绘图坐标的单位都是 vp** —— 官方文档逐条写着
`默认单位：vp`（本机 `component/canvas.d.ts` 对 `width`/`height`/`fillRect`/`fillText`/`clearRect`
参数的注释也都是 `Default unit: vp`）。所以：

```ts
❌ .onReady(() => { this.w = px2vp(this.ctx.width); })   // 双重换算 → 只有真实值 1/DPI
✅ .onReady(() => { this.applySize(this.ctx.width, this.ctx.height); })
   .onAreaChange((_o, a) => { this.applySize(a.width as number, a.height as number); })
```

- **危害是"静默缩水"而非报错**：`fillText` 坐标也是 vp，所以字**照样画得出来**，
  只是全部挤在左上角、每页行数从 21 掉到 4 —— 表现是"字很少/排版很怪"，很容易误判成排版 bug。
- **真正的空白屏另有入口**：`relayout()` 里 `if (this.w <= 0) return;` 一旦在尺寸就绪前被调用，
  `pages` 就**永远是空数组**，`drawPageContent(ctx, undefined)` 只填一个底色矩形
  → 屏上什么都没有，而 `loading` 早已置 false → **用户看到的是干净的白屏**。
  修法：尺寸取得抽成**单一入口** `applySize()`，`onReady` + `onAreaChange` 共用，
  并在无效尺寸/成功取尺寸两处各留一条日志（这是唯一能把"白屏"归因的埋点）。
- **`onAreaChange` 是必配的**：只挂 `onReady` 时，若首次触发早于布局完成，尺寸就定死在 0；
  `onReady` 与 `onAreaChange` 同挂，尺寸变化（旋转/分屏/字号）也顺带解决。
- **反面教材（必踩）**：把 `onReady` 里那次"首次赋值"写成 `this.w = ...` 而**不带去重**，
  再在 `onAreaChange` 里无条件 `relayout()` → 同一尺寸会重复排版（大章一次几十 ms）。
  `applySize` 内部做 `if (nw === this.w && nh === this.h) return;`。
- **排查话术**：用户报"白屏/一屏没几个字"时，先打 `pages.length` + 正文长度 + 内容区尺寸
  三者一条日志，**一读就能区分**「正文没读到」(`正文=0`) / 「画布口径错」(`内容区=120x260`) / 「正常」。

## 数值体检：先拿「上限」卡读数，再拿「同类读数」做对照

打点修对之后，**不要马上读性能结论，先做两个算术体检**：

1. **`调用数 ≤ 数据量上限`**。任何一类调用的每帧次数**不可能超过它的数据集大小**
   （除非同一份数据被多趟画）。实测出现 `eq 2546` 而赤道系网格总共只有 2411 点
   → 立刻就能断定「它的过滤器等于没工作」，不必再猜。
2. **同帧的同类读数做对照**。同一个 `cosLimit`、同一帧、同样循环结构的
   `grid 548 / 数据 2314 点 = 23% 通过率`（合理）对比 `eq 2546 / 2411 点 = 100%`
   → 问题在 **eq 自己的数据**里，不在投影/滤波代码里。**有对照组就不用二分猜测。**
3. **把过滤器在 Python 里离线复现一遍**，算出「正常应该是多少」。
   本项目：把 `fpx`、`cosVisible`、`projTo` 的矩形判据、趟/kind 过滤全在 Python 重写，
   跑出 276~580，与实测 2546 差 5 倍 → 铁证。
   （在脑子里算三角 / 算立体角必错；离线脚本几秒钟就能给出确定答案。）
4. 顺带：**判定 bug 前先确认口径**。`cosVisible` 写成 `1.2*sqrt(w²+h²)` 看着像
   "忘了除以 2"，其实是对的 —— `projTo` 的矩形半宽本来就是 `1.2w` / `1.2h`
   （= 2.4 倍屏幕宽、约 5 倍面积，为的是不让跨屏折线在屏幕外断掉）。

## ArkTS 静默失效陷阱（会让"过滤器全部失灵"，且不报错）

**类型化数组只声明、不分配**，写入会**静默丢弃**，读出是 `undefined`，
参与算术变 `NaN`，而 JS 里 **`NaN < x` 和 `NaN > x` 恒为 false** —— 于是所有
`if (dot < cosLimit) continue;` / `if (px > w*1.2) continue;` 判断**全部失效**，
既不报错也不崩，只是"什么都不剔除"：

```ts
private static buf: Float64Array = new Float64Array(0);   // ← 只有这一处
// 之后 refresh(buf) 里 buf[i*3] = ... 全是静默 no-op
```

一箭双雕的后果，两边都要查：

- **视觉**：坐标全是 `NaN` → Canvas 直接丢弃 → 这一层**根本没画出来过**。
  （易被忽略：用户盯卡顿时不会报"少了一层网格"。改完 bug 反而像"新功能出现了"，
  要主动告诉用户这是修复不是新增。）
- **性能**：过滤器失效 ⇒ 每帧把**全部**数据点走一遍 `moveTo/lineTo`。
  本项目 2532 个点 × 2 处 ≈ 4.4ms/帧纯白烧。

**排查手法**：凡是"分类绘制 + 预剔锥"结构的模块，都数一遍
「数据集长度」与「每帧调用数」是否同量级 —— 同量级 = 过滤器死了。

## 渲染调度：让数据源样本**直接出帧**（治「跟不上手」）

`setInterval` 定时器 + 「帧耗时超阈值就跳帧」的门限会**制造抖动**：
16ms 打点撞 33ms 门限时，实际周期在 32/48ms 之间跳（相位决定跳 2 段还是 3 段），
手感就是「跟不上手」；而且帧耗时均值被首帧 JIT / GC 尖峰顶高后会**长期偏大**，
明明能画却一直跑最慢档。

⚠️ **但"脏标记 + 粗档位"只做对了一半**（此坑二次踩过）：脏标记解决的是
"不必画的时候不画"，**没解决"该画的时候立刻画"**。置了 dirty 还等定时器来取，
每个样本白加 0~5ms 量化延迟；而定时器本身又被上一帧绘制阻塞
（实测 `tick gap 7.7ms`，因为约 49% 的主线程时间花在 `drawFrame` 里）。
两者叠加 → 实测出帧周期 `26.9 / 42.7 / 41.8ms` 乱跳 —— 帧只要 13ms 却只出 23~37fps。
**粗档位（12/20/33/50）是"无条件出帧"时代的产物；一旦有了脏标记，
它就只剩下"加延迟"这一个作用。** 间隔只该保留下界：`max(8ms, 帧耗时中位数)`。

正解：**把出帧动作从定时器里抽成 `drawIfDue(t)`，让数据源回调自己调它。**

```ts
private frameIntervalMs(): number {            // 只有下界，无粗档位
  const m = this.frameMsMed;
  return m > FRAME_FLOOR_MS ? m : FRAME_FLOOR_MS;   // FRAME_FLOOR_MS = 8
}

/// 到点就画。传感器回调与定时器**共用这一条路径**。
private drawIfDue(t: number): boolean {
  if (!this.dirty) return false;
  if (t - this.lastDrawAt < this.frameIntervalMs()) return false;
  this.lastDrawAt = t; this.dirty = false;
  this.updateTime(); this.drawFrame(t); this.drawnN++;
  return true;
}

// 数据源样本 = 垂直同步信号：一到就画，出帧周期锁在采样周期上
private onSensorFrame(f: ViewFrame): void {
  ...
  if (this.drawnView) {
    const dot = f.fx * this.drawnFx + f.fy * this.drawnFy + f.fz * this.drawnFz;
    if (dot < COS_DIRTY_EPS) { this.dirty = true; this.drawIfDue(nowHi()); }
  } else { this.dirty = true; this.drawIfDue(nowHi()); }
}

// 定时器退回**兜底**：拖动/捏合/设置改动/加速播放/1s 保活（这些没有样本事件）
this.rafId = setInterval(() => { ...; if (!this.drawIfDue(nowHi())) this.skipN++; }, 5);
```

- **前置确认**：传感器/数据源回调必须在 **UI 主线程**（日志里看 `tid` 是否等于主线程）
  才能直接画 Canvas。且非当前页面/后台要 `stop()` 退订，否则回调会乱触发。
- **帧间隔下界用帧耗时中位数**（16 帧滑窗 + 插入排序，零分配）而非均值/EMA：免疫尖峰。
  下界取 `max(8ms, 中位数)` 即可 —— 中位数 ≈ 一帧实际耗时，正好是"不能比画得过来更快"。
- **drawFrame 内记录「真正画出去」的状态**（视向向量等），供脏判定比较。
- 拖动/捏合/时间控制/**所有影响画面的设置**（`@StorageLink` 加 `@Watch`）都要置脏，
  否则改了开关要等保活那一秒才刷新。
- 副作用红利：静止时几乎零成本（原来静止也在满帧重画，是发热来源）。
- 收益：出帧周期 = 数据源周期，跟手延迟 = 一帧绘制耗时，**没有排队/量化环节**。

## 已证实的调用数陷阱（直接查这几处）

- **空桶也照调**：按颜色档 × alpha 桶两层循环批绘制时，若每个桶都无条件
  `beginPath()`，空桶会白送几百次调用。→ 收集时记**桶位掩码** `used |= 1 << q`，
  只遍历有元素的桶；整档没有亮星就别跑辉光那轮。
- **逐段设置样式**：网格类（赤道/黄道/经纬）几十条线各画一次
  `beginPath + stroke + 重设 strokeStyle/lineWidth`。同 kind 颜色宽度一致时
  **合并成一条路径一次 stroke**（断笔用 `started=false + moveTo`），视觉不变、
  调用数从「段数 × 2 趟」降到「kind 数 × 2」。
- **屏外也画**：可见锥阈值要按**真实屏幕矩形外接**算，别为「跨屏线段不能断」而
  把锥放大到 1.2 倍屏幕（面积 5 倍，屏外的全画了）。星点这类点图元应再叠一次
  精确矩形裁剪。
- **数据量本身就是开销**：星点/散点是唯一随数量线性增长的项。给一个
  **自适应数量档位**（如星等限 6.5→5.0，每 0.5 一等，每 5s 才许动一次），
  比在渲染细节里抠更有效，且不会闪。

## 打点行该长什么样

一条日志同时给出「我们画得慢」与「主线程被占」两类信息：

```
perf: 12.3ms/frame med 12.2 | seg 13.2 [pre .. bg .. grid .. eq .. line .. star .. lbl .. gnd ..] | art ..ms/..cell
    | pts 449 | calls g548 e2546 l213 s651 t10 m4 | draw 187/657tick gap 7.7ms 出帧 26.9ms tick自身 3.8ms
    | fov 56 440x744 budget 48 starMag 6.5
```

- `seg`（分段之和）对比整帧：**≈ 整帧 ⇒ 耗时就是这些绘制；远小于整帧 ⇒ 时间在别处**
  （渲染管线提交、被抢占、或还有没打点的代码）
- `tick gap` vs 定时器周期：间隔明显大于设定值 ⇒ 主线程被占
  （自己画得慢也会占 —— 用 `tick自身` 判断：`tick自身 ≈ 绘制耗时 × 绘制数 / tick 数`
  就说明是自己在占）
- `出帧周期` 才是用户感知的跟手延迟上限；`draw N/n tick` 看有多少 tick 是空跑
- 出帧周期明显大于「帧耗时 + 间隔」⇒ 有排队/量化环节在偷延迟（见调度一节）

## 排查顺序（照这个走，别跳）

1. 先确认打点口径正确（高精度时钟 + 累加对齐），让读数能解释整帧
2. **数值体检**：`调用数 ≤ 数据量上限`？和同类模块的通过率比值对得上吗？
   （对不上 = 过滤器死了；见「静默失效陷阱」）
3. 用调用计数找「哪一类调用最多」，而不是看耗时最大
4. 查上面列的四个调用数陷阱
5. 帧耗时降下来之后再改调度
6. 调度做完脏标记还不够：**要让数据源样本直接出帧**，定时器只做兜底
7. 每次只改一类，改动后用同一份 perf 行对比（别同时改三处，否则无法归因）
8. 交付时明确写出「预期读数的变化」（如 `出帧 27~43ms → ~20ms`），
   下一轮直接拿数字验收，避免又变成"感觉还是卡"的循环
