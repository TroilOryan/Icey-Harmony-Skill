> **分册：`harmony-interaction-feel`** ｜ 交互手感参考（改编自 Apple WWDC 设计讲座的 Web 转译，映射到 ArkUI），2026-11-21 入库。
> 触发场景见入口 `SKILL.md` 的路由表。
> ⚠️ **定位：手感 / 动效哲学参考，不是视觉权威，更不是苹果视觉规范的搬运。** 配色、字体、图标、材质一律以 HarmonyOS Hds 原生规范与本库既有定案为准（见下方「与本库定案的关系」）。

# 交互手感总纲（改编自 Apple *Designing Fluid Interfaces*，映射到 ArkUI）

## 结论（先读）

- **一句话主线**：界面"活"不活，取决于动效是否**从当前屏幕值启动、继承用户速度、可被随时抓取反向**。做到这三点的工具是**弹簧**，不是固定时长的补间。原文把这条列为"最重要原则"（§3），本册沿用。
- **来源与边界**：本册改编自外部技能 `emilkowalski/skills` 的 `apple-design/SKILL.md`（来源见文末），其知识源自 WWDC 2018《Designing Fluid Interfaces》等讲座、**转译为 Web 平台**（CSS / Pointer Events / Motion）。本册只取其中**平台无关的交互哲学**，把 Web 实现全部替换为 ArkUI 对应物；**不引入苹果的视觉观感、不引入第三方技能包本身**。
- **术语对齐（Apple → ArkUI）**：

  | Apple / Web 概念 | ArkUI 对应 | 备注 |
  | --- | --- | --- |
  | spring / 从当前值启动 | `curves.springMotion`、**`curves.responsiveSpringMotion`**（跟手 / 可中断场景首选） | 参数语义近似，**数值须真机校准**，勿照抄 |
  | 松手速度交接 | `PanGesture` 回调 `GestureEvent.velocityX/velocityY` | `responsiveSpringMotion` 内部按当前值与速度续接 |
  | `setPointerCapture` 1:1 跟手 | `PanGesture({ distance: 5 })` + `onActionStart/Update/End` 内联 | 手势对象**必须内联**，见本库 `harmony-arkts-lint-fix.md`「手势对象必须内联」（§13~§16） |
  | 进出同路径 / 锚定触发源 | `TransitionEffect`、`geometryTransition`、`bindMenu` 锚点 | `geometryTransition` 铁律见 `harmony-app-template.md` LSN-039 |
  | `backdrop-filter` 半透明浮层 | `backdropBlur` / `systemMaterial` / `backgroundBlurStyle` | **以 `harmony-material-layer.md` 为准**，本节不重复 |
  | `prefers-reduced-motion` | **无直接等价物** → 用设置开关 + 集中动效配置（见 §14） | 不要照抄 Web media query |
  | `@media prefers-contrast` | 高对比场景走主题色板 + 明确边框（见 §14） | 用实色底 + 明确对比边框，不要靠半透明 |

- **与本库定案的关系（冲突时一律以本库为准）**：
  1. **视觉权威是 Hds，不是 iOS** —— 全局配色已明确"去 iOS 系统灰"（`assets/harmony-standard/.../ThemeManager.ets:8-23`），苹果的材质色板 / 字体观感 / 控件位置约定不得照抄。
  2. **本节是"总纲 + 指针"**，细节在既有分册：过渡（`SKILL.md` 铁律 7）、材质（`harmony-material-layer.md`）、加载态（`harmony-system-loading.md`，一律系统 `LoadingProgress` 禁自绘）、几何转场（`harmony-app-template.md` LSN-039）、帧计时（铁律 9）、Canvas 帧率（`harmony-canvas-frame-pacing.md`）、命中测试（铁律 24）。**不要在本册重复展开它们。**
  3. 本册新增的是"**为什么这样动**"的判断框架，供评审界面手感、定位"哪里不像原生"时使用。

---

## 一、响应：按下即反馈（原文 §1）

- **原则**：反馈落在 **pointer-down** 而非释放时；交互**过程中**连续更新，不是结束时才补动画；审计输入路径上一切非必要延迟（防抖、定时器、动画等待）。原文："延迟一出现，直接感就断崖式下跌。"
- **ArkUI 落地**：
  - 按压态用 `.stateStyles({ pressed: { ... } })` 或 `onTouch` 的 `TouchType.Down` 立刻改 `@State`，**不要等 `onClick`**。
  - 拖拽 / 滑块在 `PanGesture.onActionUpdate` 里**逐帧 1:1** 更新，松手才做的动画只负责"收尾"。
  - 这正是本库铁律 7「状态 / 操作类变化一律要有过渡，不要硬切」的**手感版**：过渡是默认要求，不是可选优化。
- **自检**：按下去那一刻有没有视觉变化？拖拽全程 UI 是否跟手？如果是"松手才动"，手感已经丢了。

## 二、直接操控：1:1 跟手（原文 §2）

- **原则**："手指和内容一起动。"必须保留**抓取偏移**——用户抓在元素哪个位置，就从哪个位置跟，不能瞬间吸附到中心。
- **ArkUI 落地**：

```ets
PanGesture({ distance: 5 })   // 5vp 阈值 ≈ 原文的 hysteresis，先判定方向再 1:1
  .onActionStart((e: GestureEvent) => {
    // 记录抓取偏移：this.grabOffset = 手指位置 - 元素当前位置
  })
  .onActionUpdate((e: GestureEvent) => {
    // e.offsetX / e.offsetY 是相对上一次的增量；累计进 @State
    this.offsetY = this.startY + e.offsetY;   // 保留抓取点，不吸附中心
  })
  .onActionEnd((e: GestureEvent) => {
    // e.velocityY：松手瞬时速度（px/s），供 §5 / §6 使用
    this.settle(e.velocityY);
  })
```

- ⚠️ **手势对象必须内联**（本库 `harmony-arkts-lint-fix.md`「手势对象必须内联」（§13~§16） 的实测定案）：不要把 `PanGesture` 抽成成员变量复用，否则手势不识别 / `requestFocus` 之类静默失效。
- ⚠️ 命中层问题先看铁律 24（native surface 抢触摸时，加多少 `onClick` 都没用，只能 `HitTestMode.Block`）。

## 三、中断性：最重要的原则（原文 §3）

- **原则**：任何动画都必须**随时可被抓取并反向**。用户抓住一个正在关闭的弹窗，它应该跟手回来，而不是"先关完再重开"。
- **四条硬约束**：
  1. **过渡期间绝不锁输入**。
  2. **从屏幕上的当前值启动动画**，不是从目标值 / 逻辑值启动 —— 从逻辑值启动会看到一次可见跳变。
  3. **跟手 / 可打断的动画不要用固定时长补间**（Web 侧的 CSS transition / `@keyframes`）。ArkUI 对应：**不要用固定 `duration` 的 `animateTo` 做跟手**，改用 `curves.responsiveSpringMotion`（它按当前值与速度续接，天然可中断）。
  4. **反向时延续速度，不硬切**。换目标时用带速度延续的弹簧曲线；2D 运动拆成 X、Y 两个独立弹簧，避免两轴速度不同步。
- **ArkUI 落地要点**：属性动画 `.animation({ curve: ... })` 作用在属性变化上；跟手阶段直接改 `@State`（不靠动画补间），松手阶段才交给响应弹簧。**"改状态 → 属性动画自然从当前值补间"** 是 ArkUI 实现"从当前值启动"最直接的路径。

## 四、用弹簧，不用固定时长（原文 §4）

- **原则**：固定时长动画无法响应新输入，弹簧可以 —— 新输入只是改变目标，运动连续。Apple 把物理三元组简化成两个设计师友好的参数：
  - **damping ratio（阻尼比）**：`1.0` = 临界阻尼、无过冲、平稳落位；`< 1.0` 过冲振荡，越低越弹。
  - **response（响应）**：到位的快慢，**不是 duration** —— 弹簧没有固定时长。
- **默认档**：UI 大多从 **damping `1.0`** 起步；**只有手势本身带动量**（甩、抛、拖拽释放）才用 **~`0.8`** 加一点回弹。淡入的菜单回弹是错的，甩出去的卡片回弹是对的。
- **ArkUI 对应（近似，须真机校准）**：

```ets
import { curves } from '@kit.ArkUI';

const SPRING_CALM       = curves.springMotion(0.4, 1.0);  // 默认 UI：无过冲
const SPRING_INTERACTIVE = curves.responsiveSpringMotion(0.3, 0.8); // 跟手 / 带动量 / 可反复打断
// 用法：.animation({ curve: SPRING_CALM, ... }) / animateTo({ curve: ... }, () => {...})
```

- ⚠️ **不要照抄数值**：ArkUI 的 `damping` 参数与 Apple 的 damping ratio 语义相近但非严格等同，且设备性能、布局尺寸都会改变观感。**用"1.0 = 稳、0.8 = 微弹"这一定性锚点，在真机上调到顺手**，而不是把字面数值搬过去。

## 五、速度交接（原文 §5）

- **原则**：手势结束时，动画要以**手指的精确速度**续接，拖拽与动画之间不能有可见接缝。这是"顺滑"与"还行"的最大分水岭。
- **ArkUI 落地**：从 `PanGesture.onActionEnd` 的 `GestureEvent.velocityX/velocityY` 拿到释放速度，交给 §4 的响应弹簧（其内部已处理速度延续）。
- 原文给出的归一化参考（某些弹簧 API 需要相对速度）：`relativeVelocity = gestureVelocity / (targetValue − currentValue)`。**ArkUI 的响应弹簧不需要你手动做这一步**，保留此式仅用于理解"速度如何被继承"。

## 六、动量投射（原文 §6）

- **原则**：不要从**松手点**吸附到最近边界；用速度**预测静止点**（像滚动减速），再吸附到离预测点最近的目标。甩一下要能"抛"过去。
- **平台无关的数学，可直接使用**：

```
project(v, d = 0.998) = (v / 1000) * d / (1 - d)   // v 单位 px/s
预测落点 = 当前值 + project(v)
目标 = 离预测落点最近的吸附点
// 注意：这是指数衰减形式，不是物理教科书的 v²/(2·decel)
```

- **ArkUI 落地**：在 `onActionEnd` 里算出预测落点，决定吸附到哪一档（Dialog / 可拖拽面板的高度档位、轮播页、抽屉开合），再用响应弹簧带速度接管。**标准 Scroll / List 的滚动减速由系统负责，无需手写。**
- 与既有分册的分工：`bindSheet` 的高度 / 拖拽范式以 `harmony-sheet-panel.md` 为准；此处只补"用速度决定吸附哪一档"的判断。

## 七、空间一致性：路径对称、锚定来源（原文 §7）

- **原则**："从哪来，回哪去。"从右侧进的面板就向右出；菜单 / 弹出层应从**触发它的元素**长出（`transform-origin` / 锚点指向触发器），而不是从屏幕中心冒出来。
- **ArkUI 落地**：
  - `TransitionEffect` 的进场 / 退场用**同一路径**（进出都 translateX 同向）。
  - `bindMenu` / 弹出层的锚点对齐触发控件，见 `harmony-titlebar-menu.md`。
  - **几何转场（缩略图 → 全屏）** 用 `geometryTransition`，但必须遵守 `harmony-app-template.md` LSN-039 的铁律：**只与 Navigation 的 push/pop 搭配，禁与 `bindContentCover` 混用**。

## 八、朝手势方向给暗示（原文 §8）

- **原则**：中间帧要"预告"终点，而不是盲目插值。例如 Control Center 模块朝手指方向"长出去"。
- **ArkUI 落地**：跟手阶段除了 1:1 位移，可叠加轻微的 `scale` / 透明度渐变指向最终状态；让中间帧读得出"它要去哪"，而不是线性搬过去。

## 九、橡皮筋边界（原文 §9）

- **原则**：到边界要**渐进阻尼**，不要硬停。硬停读作"卡死"，持续阻力读作"响应了，但到头了"。
- **ArkUI 落地**：
  - `Scroll` / `List` 用 `.edgeEffect(EdgeEffect.Spring)` 得到系统回弹，**优先用系统能力**。
  - 自定义拖拽才手写阻尼（越界越远、跟手越少）：`rubberband(o, d, c=0.55) = o*d*c / (d + c*|o|)`。

## 十、手势设计细节（原文 §10）

| 细节 | 原文口径 | ArkUI 落地 / 本库关联 |
| --- | --- | --- |
| 点击 | 按下高亮、抬起提交；约 10px 容差；拖走再回来可取消 | `.stateStyles({ pressed: ... })`；容差见 `PanGesture({ distance: 5 })`；取消走 `onActionCancel` |
| 拖拽 / 滑动 | 小位移阈值（~10px）后再定向，然后 1:1 | `PanGesture({ distance: 5 })`，见 §2 |
| 多手势并行 | 从第一次移动就并行识别所有可能手势，意图明确后取消落选者 | 避免只用"最终态"回调的手势；多手势组合时注册顺序与互斥要真机验证 |
| 消歧延迟 | 双击检测必然延迟单击，只在真有双击的地方付这个成本 | 不要全局加双击识别 |

- ⚠️ "看得见点不动"先查铁律 24（命中层 / native surface）与铁律 28（带参 `@Builder` 根节点事件失效），**不要先怀疑手势参数**。

## 十一、帧级顺滑（原文 §11）

- **原则**：顺滑是"帧里有什么"，不只是帧率。高速运动用轻微运动模糊 / 拉伸表达速度；只动合成器友好的属性（`transform` / `opacity`）；`will-change` 只在量到掉帧后加。
- **ArkUI 落地**：
  - 动画只改 `opacity` / `translate` / `scale`（本库铁律 7 的纯属性动画），**不要把 `width` / `margin` 等布局属性塞进动画帧**。
  - 帧内计时用 `systemDateTime.getUptime(...)`，**禁用 `Date.now()`**（铁律 9）。
  - 掉帧诊断走 `harmony-canvas-frame-pacing.md` 的分段打点，别凭感觉调。

## 十二、材质与层次（原文 §12）→ 指针到 `harmony-material-layer.md`

- 原文要点（半透明浮层表达层次、材质重量编码层级、**浅色半透明不叠浅色半透明**、大面更厚、滚动边缘渐隐而非硬分割线、入场时 blur 与 scale 同动）**作为评审判据保留**。
- **实现细节一律以 `harmony-material-layer.md` 为准**：档位方向（"强"=薄）、四种 scope、官方默认档表、Toggle 承载层清单、"去 iOS 系统灰"色板。
- 本册补充的两条交叉判据：
  1. **浅透不叠浅透**（原文）：与材质册"薄层材质 `materialColor` 必须 `Color.Transparent`、不额外着色"结论一致 —— 叠出来的"奶白 / 发灰"是经典翻车。
  2. **滚动边缘用渐隐**（原文）：与材质册"HdsNavigation 标题栏 scroll effect 跨页残留"相呼应 —— 模糊 / 渐隐是窗口级的，跨页要共享同一构造器。

## 十三、多模态反馈：动效 + 声音 + 触感（原文 §13）

- **三条规则**：
  1. **因果**：反馈在真实因果事件上触发（开关翻过去、条目吸附到位），性质要匹配动作的物理性。
  2. **同帧**：视觉、声音、触感**同一帧**触发；音频 / 触感被 CSS 过渡拖慢就会穿帮。
  3. **克制**：只在有意义的时刻（成功 / 错误 / 提交 / 吸附）给反馈；过度反馈会训练用户忽略一切。
- **ArkUI 落地**：触感走 `@ohos.vibrator`（`startVibration`，具体接口与权限以实际 SDK 为准），音频走多媒体 Kit；关键是**在手势 commit 的那个回调里一起触发**，不要等动画结束再补。

## 十四、减弱动效与无障碍（原文 §14）

- **原则**：减弱动效 ≠ 没有反馈，而是**更温和的等价物**：滑入 / 弹簧 / 视差 → 短 opacity 交叉淡化或静态过渡；去掉过冲；保留有助理解的透明度 / 颜色变化。
- ⚠️ **平台差异（重点）**：Web 的 `prefers-reduced-motion` / `prefers-reduced-transparency` / `prefers-contrast` 媒体查询在 ArkUI **没有直接等价物**。不要照抄 `@media` 写法。推荐做法：

```ets
// 1) 动效参数集中到一处，禁止散落硬编码 duration/curve
class MotionConfig {
  static curve(reduced: boolean) {
    return reduced ? Curve.Ease : curves.responsiveSpringMotion(0.3, 0.8);
  }
  static duration(reduced: boolean) { return reduced ? 180 : 350; }
}
// 2) "减弱动效"开关走本库既有设置体系：AppStorage.setOrCreate + @StorageLink 订阅
//    （见 SKILL.md 铁律 6 / 31；静态 getter 在 build 路径上是死依赖）
// 3) 减弱档：去掉 scale/translate/overshoot，只留 opacity 交叉淡化
```

- 其他：字号用 **`fp`**（跟随系统字体大小设置），间距用 `vp`；避免全屏移动背景、~0.2Hz 慢速循环、亮度突变；深色 / 浅色切换要平滑过渡。

## 十五、排版：字号相关、字距与行高（原文 §15）

- **原则**：
  - **字距随字号变化，绝不全字号一个值**：大标题负字距，正文接近 0。
  - **行高与字号反向**：大标题紧、正文松。
  - 用**字重 + 字号 + 行高**一起建立层级，不只靠字号。
  - 默认用系统字体 —— 鸿蒙侧即 **HarmonyOS Sans**（成品字体在 `assets/design-resources/fonts/HarmonyOS Sans/`）。
- **ArkUI 落地**：`.fontSize()`（fp）、`.lineHeight()`、`.letterSpacing()`、`.fontWeight()` 组合；标题 `letterSpacing` 取负值、正文取 0 附近。
  - ⚠️ 本库另有坑：ArkUI `Text` 折行后自动缩字（`heightAdaptivePolicy` 默认 `MAX_LINES_FIRST`），要固定字号时设 `minFontSize == maxFontSize` + 显式 `lineHeight`，见 `harmony-arkts-lint-fix.md` 的分档章节 —— **别把它误当成"动态字体"能力**。

## 十六、八条设计原则（原文 §16，平台无关，作为评审清单）

1. **Purpose 目的**：有意图地做，决定"不做什么"。
2. **Agency 自主**：给用户控制权、提供选择；用"易撤销"兜底，**确认弹窗只用于真正不可逆的破坏性操作**（滥用会训练用户一路点过）。
3. **Responsibility 责任**：以用户利益行事 —— 隐私请求在恰当时刻、只取所需；预判误用与伤害；风险大于价值的特性直接砍掉。
4. **Familiarity 熟悉**：建立在用户已有认知上，用不过分字面也不过分抽象的隐喻；**看起来一样的必须行为一样、位置一样**。
   ⚠️ **鸿蒙语境修正**：原文举的"关闭按钮永远在 macOS 左上"是苹果平台的具体约定，**不可照抄**；位置约定以 Hds / HarmonyOS 原生规范为准。
5. **Flexibility 灵活**：适配不同设备与能力（手机 = 快速触控；PC/2in1 = 精确指针 + 深度工作流），必要时让用户自定义。
6. **Simplicity 简洁 ≠ 极简**：去掉不必要，让核心目的凸显；用层级（顺序、间距、对比）让最重要的最显眼；常用路径先展示，高级选项下一层。
7. **Craft 匠心**：每个间距、时长、对齐都是可辩护的刻意选择；抖动滚动、错位图标、旋转即崩读作"不用心"。
8. **Delight 愉悦**：是前七条做对的结果，不是额外撒的彩蛋。

**配套战术规则**：反馈分四类（状态 / 完成 / 警告 / 错误）；每个页面回答"我在哪 / 能去哪 / 有什么 / 怎么退出"；邻近性暗示关系（控件靠近它影响的对象）；**具体标签优于泛化标签**（导航项写"进度 / 书库"而非笼统的"首页"）。

## 十七、流程（原文 §17）

- **交互式原型优先** —— "一个能跑的 demo 胜过一百万张静态图"；边做边玩才能发现界面。
- **交互与视觉一起设计** —— "不应该分得出哪是交互、哪是视觉"；动效不是像素做完后再贴的一层。
- **真人真场景测试**，并用新眼睛评审动效 —— 慢放 / 逐帧看全速下看不见的问题（真机取证命令见 `SKILL.md`「本机环境坑」）。

---

## 速查表（ArkUI 版）

| 需求 | 手段 | 落点 |
| --- | --- | --- |
| 默认 UI 弹簧 | 临界阻尼、无过冲 | `curves.springMotion(0.4, 1.0)`，真机校准 |
| 甩动 / 跟手弹簧 | 微弹、可反复打断 | `curves.responsiveSpringMotion(0.3, 0.8)` |
| 反馈时机 | 按下即给、全程连续 | `.stateStyles({ pressed })` / `onActionUpdate` |
| 1:1 拖拽 | 内联 PanGesture + 抓取偏移 | `distance: 5` + `offsetX/Y` 累计 |
| 速度交接 | 松手速度交给响应弹簧 | `GestureEvent.velocityX/Y` |
| 甩动落点 | 动量投射后吸附最近档 | `v/1000 * d/(1-d)`，`d≈0.998` |
| 干净中断 | 从屏幕当前值启动 | 属性动画 / 响应弹簧，禁用固定时长跟手 |
| 反向不撞墙 | 延续速度换目标 | 带速度延续的响应弹簧 |
| 边界 | 橡皮筋而非硬停 | `.edgeEffect(EdgeEffect.Spring)` / 阻尼公式 |
| 半透明浮层 | 系统材质 + 主题配对 scrim | `harmony-material-layer.md`（**不叠浅透**） |
| 进出场 | 同路径、锚定触发源 | `TransitionEffect` / `geometryTransition`（LSN-039） |
| 减弱动效 | 设置开关 + 集中配置 → opacity | §14，**无 CSS media query 等价物** |
| 排版层级 | 字重 + 字号 + 行高 + fp | HarmonyOS Sans，标题负字距 |

## 来源与版权边界

- **知识来源**：外部技能 `emilkowalski/skills` → `skills/apple-design/SKILL.md`（<https://github.com/emilkowalski/skills/blob/main/skills/apple-design/SKILL.md>），其原始内容为 Apple WWDC 设计讲座（ chiefly *Designing Fluid Interfaces*, WWDC 2018；另含 *The Details of UI Typography* 2020、*Principles of Great Design* 2026）的 Web 转译。
- **本册性质**：**原创转译 + 与本库定案对齐** —— 平台无关原则被重新组织，Web 实现被替换为 ArkUI 对应物，冲突处以 HarmonyOS 原生规范与本库定案为准。不是原文复制，也未把该第三方技能包纳入本库（符合上级 `README.md` 同步铁律 4「仅纳用户自建技能」）。
- **引用方式**：正文节号（§1~§17）对应原文小节，便于对照溯源；具体 API 以本机 SDK d.ts 为准（本库通用原则：查 d.ts，不猜）。
