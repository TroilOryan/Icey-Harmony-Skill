import { DeviceProfile } from '../../model/DeviceProfile';

/// 通用底部弹窗容器（bindSheet 内容用）
/// 用 @BuilderParam content 传弹窗内容（选项/进度等）
/// 用法：AppSheet({ show: this.show, sheetTitle: '...' }) { SheetContainer() { 内容 } }
///
/// ## 职责（2026-10-02 第四次定案：**去标题化**）
///
/// 用户原话（第三次反馈）：「标题和关闭按钮看起来都没有垂直居中对齐 你还是用的自绘吧？
/// 而且为什么自带了白色 和弹窗本身的灰色放一起了」。
///
/// 前两版（10-01 自绘模糊带 / 10-02 上午 Hds `HdsNavDestination.titleBar`）都不成立：
/// - **自绘**标题行永远"看起来是自绘的"；
/// - **Hds 标题栏是内容区里的浮层**：其 56vp 标题基准与系统关闭按钮不在同一行 ⇒ 必然不齐；
///   它另带 64vp 背板底色 ⇒ 白色与弹窗灰色底冲突（用户反馈的"自带了白色"）。
///
/// 第四次曾改为 `bindSheet` 原生 `SheetOptions.title`（平台配置化标题、与系统关闭按钮同行）。
/// **2026-10-02 第八轮推翻**：官方文档（FAQ 1088 + 开发指导《绑定半模态页面》）写明该标题区域
/// 与 builder **同级布局**⇒ 占位不透光、内容无法穿进 ⇒ 与官方真机截图的"内容穿过标题带并被
/// 模糊"相悖。⇒ 标题改**自绘浮层**（见 `AppSheet.sheetHeader`）。
/// 标题仍**不归本容器管** —— 本容器只负责内容滚动 + 首部留白（`SHEET_TITLE_AREA_VP`）。
///
/// ## 高度（2026-10-02 第七次定案：**跟随内容**）
///
/// 用户原话：「就是目前感觉可以不用都用最大高度了 **跟随内容吧**」（第五轮的"恒定最高高度"
/// 因此被推翻）。第五轮之所以改成恒定 LARGE，是为了"内容少也能测滚动顶部模糊"——但真机实测
/// 后用户明确要求回到紧凑身高：**内容少 → 弹窗只占内容高；内容多 → 封顶后内部滚动**。
///
/// 实现 = 「**比例上限 + 内容自适应**」（与 a27faad 之前的旧版同构，只是留白口径按第四/五轮
/// 收敛过）：内容区竖屏 `height('auto')`（自适应紧凑）、横屏 `height('100%')`（撑满受限高度），
/// 再由 `constraintSize({ maxHeight })` 封顶成真实滚动视口；上限取「比例值」与「窗口净空」的
/// 较小者（比例值本身也可能超出可用空间——小屏/横屏/分屏/平板悬浮窗）。
///
/// ⚠️ 因此 `AppSheet.detents` 也必须同步回 `[SheetSize.FIT_CONTENT, SheetSize.LARGE]`
/// （见该字段注释）——两者是同一个口径的两半，只改一边会出现"面板高但内容塌"或反之。
///
/// ⚠️ **为什么保留显式高度 + `bottomSpace` 记账，而不是 `layoutWeight(1)` 撑满**：
/// 卡片外底栏是 `SheetContainer` 的**兄弟节点**，flex 方案要求调用方给本组件加
/// `layoutWeight(1)`（23 个调用点全改）且依赖"bindSheet 百分比有确定参照"这一未验证前提；
/// 而显式上限 + `bottomSpace` 已在真机跑通多轮（2026-09-08 小屏/横屏底栏被顶出屏幕即此机制修好的）。
/// 保持同一套机制、只换上限口径 = 零调用点改动、零回归面。
/// ⚠️ 真机若观感偏太高/偏矮，**只调 `PANEL_RATIO_LANDSCAPE` / `PANEL_RATIO_PORTRAIT`**。
///
/// ## 横向内距的唯一出处
/// 左右留白放在**滚动内容那一层**（`PANEL_PAD_H` = 16，对齐系统标题），面板只留**下** padding
/// （⚠️ 2026-10-02 第十轮起**上留白也下放**到内容层：模糊要覆盖到面板顶边，视口顶必须 = 面板顶）：
/// - 而 Scroll 视口 = **面板整宽** ⇒ 浮动件（搜索胶囊、带材质的卡片）的**外阴影/光感**
///   有余量可落**，不再被视口边缘裁掉（用户反馈「搜索框两侧明显有裁切、阴影都被裁切了」）。
/// ⚠️ 旧版把 24 放在面板的 padding 上 → Scroll 视口 = 面板宽−48，且内容盒与视口完全重合、
///   零余量 ⇒ 任何越出内容盒的阴影/光晕当场被裁。
/// ⚠️ **禁**「内缩卡片式」写法（`.width('100%')` + 左右 margin 24）：百分比按父级内容宽
///   解析、margin 在外叠加 → 真宽 = 100% + 48vp 溢出父级，内缩全部失效、贴死面板两边
///   （原卡片层的实测坑，2026-09-09）。

/// **标题带高度**（自绘浮层 + 内容首部留白共用）：
/// **2026-10-02 第八轮定案：标题改为「自绘浮层」，本常量升为标题带高度（导出）。**
///
/// 用户真机截图（官方 AppGallery 评分弹窗）证实：官方半模态**内容可以滚进标题带、并被模糊**。
/// 而官方文档（FAQ 1088 正文 + 开发指导《绑定半模态页面》）写明：「通过 `SheetOptions` 的
/// title 属性设置的**标题区域与 builder 处于同级布局**」⇒ 系统标题带是与内容**上下排列的
/// 兄弟区域**，占位且不透光，**系统标题下内容物理上无法穿进标题带**。
///
/// ⇒ 要复刻截图效果，**只能去掉 `SheetOptions.title` 改自绘浮层**（用户已裁决）：内容视口
/// 扩到面板整高，标题带作为 `Stack` 浮层压在内容之上（见 `AppSheet.sheetHeader`）。
///
/// ⚠️ 本常量现在有**两个消费方**，必须同步：
/// ① `AppSheet.sheetHeader()` 的标题带高度（浮层）；
/// ② 本容器内容层顶部的 `padding({top})`（静止时内容从标题带下沿开始）；
/// ③ 标题带**返回按钮**的命中块高度（⇒ 其圆心落在本行中心，再整体下沉
///   `SHEET_TITLE_ROW_DROP_VP` 后与系统关闭按钮同心，见 `SHEET_BACK_BTN_SIZE`）。
export const SHEET_TITLE_AREA_VP = 64;

/// **标题行内容的整体下沉量**（2026-10-02 第十七轮定案）
///
/// 用户真机反馈原话：「返回按钮整体来说基本对 但是要**稍微下来 6vp**试试 然后**有返回按钮存在的
/// 话 标题需要右移一点距离**吧」→ 紧接着自己修正：「等下 那要这么说 其实**标题也没有和关闭按钮
/// 居中对齐** 因为我看**返回按钮和标题是居中对齐了** 所以**标题也一起下沉**一下看看效果」。
///
/// **根因（用户观察是对的）**：自绘浮层里，标题与返回按钮都在 `SHEET_TITLE_AREA_VP`(64) 行内居中
/// ⇒ 它们的共同中线 = **行心 = 面板顶 + 32**；而**系统关闭按钮的圆心实测比它低 6vp**
/// （≈ 面板顶 + 38）。所以"标题/返回按钮没和关闭按钮对齐"是**两个自绘元素一起偏高**，
/// 而不是其中某个错位——只挪按钮会把按钮与标题错开（用户一句"返回按钮和标题是居中对齐了"
/// 就点破了这一点）⇒ **正解 = 整行一起下沉**。
///
/// **做法**：浮层 `Column` 加 `.padding({ top: SHEET_TITLE_ROW_DROP_VP })`。
/// ⚠️ 为什么用 padding 而不是负 `margin` / `offset`：
///   - ArkUI 的 `.height()` **包含 padding**（border-box 语义）⇒ `.height(SHEET_HEADER_BAND_VP)`
///     不变时，行内容整体下移，**带总高仍是 76vp** ⇒ 渐变档位（`titleBandStops`，位置是比例）
///     与内容层顶部留白（`SHEET_CONTENT_TOP_VP`）**一律不需要动**，零连锁。
///   - 负 margin 会让行顶探出浮层顶（靠 `.clip(true)` 裁掉，有被切风险）；`offset` 是绘制位移，
///     命中区是否跟随需另证 —— 两者都不如 padding 干净。
/// ⚠️ **窄屏与宽屏都要下沉（2026-10-07 改）**：宽屏 `dialogBody` 没有系统关闭按钮、
///   其"居中"退化为"和标题文字垂直居中"，本来可不下沉；但两端的标题基线必须一致
///   （否则同一弹窗在手机与平板上标题高度对不上、切换设备读作"标题位置漂了"）
///   ⇒ 宽屏 `dialogHeader()` 也加同一份 `.padding({ top: SHEET_TITLE_ROW_DROP_VP })`。
///   ⚠️ 旧注释写的"只影响窄屏"已不成立，勿再引用。
export const SHEET_TITLE_ROW_DROP_VP = 6;

/// **内容层渐变模糊**（`linearGradientBlur`；2026-10-02 第九轮立、**第十轮调参**）
///
/// 用户真机反馈标题带「边缘明显能看出来硬切割」。根因是第八轮用 `backdropBlur` ——
/// 它是**均匀**模糊：带内糊、带外清楚 ⇒ 边界处模糊强度**突变**，怎么调底色都去不掉那道线。
///
/// Hds 标题栏没有硬边，机制已查实（`@hms.hds.hdsBaseComponent.d.ets`）：
/// `ScrollEffectType.GRADIENT_BLUR` 模式下由 `HdsNavigationTitleBarStyle.blurRadius`
/// （range 0~128，**仅 GRADIENT_BLUR / IMMERSIVE_GRADIENT_BLUR 生效**）驱动，
/// 并以 `maskExtraHeight`（默认 **32vp**）在标题栏高之外**继续延伸一段遮罩**给模糊收尾。
/// 其底层能力就是 ArkUI 通用属性 **`linearGradientBlur`（模糊强度可渐变）**
/// （`common.d.ts`，@since 12；`[模糊程度, 位置]` 档位，位置 = **组件高的比例**）。
/// ⚠️ 更高层的 `ScrollEffectOptions`（`navigation.d.ts` / Hds）**只能挂在 Navigation /
///   NavDestination 标题栏上**，bindSheet 挂不上 ⇒ 只能把底层属性下放到**内容层**。
///
/// 做法：模糊从**内容视口顶部**最强，按 9 档曲线衰减到 0；带长见 `SHEET_BLUR_BAND_VP`。
///
/// ## 第十轮三项调参（用户对着官方 AppGallery 截图逐项比对）
///
/// 用户原话：「感觉**无法完全到弹窗的顶部边缘**、感觉**只是一个渐变的遮罩 没有模糊效果**、
/// **范围也不够大**」。
/// 1. **没模糊感 → 半径量级错了**：`linearGradientBlur` 的 `value` 单位是 **px 不是 vp**
///    （`common.d.ts` 原文 "Blur radius … Value range: [0, 1000]"，全仓其余模糊接口都是 vp）
///    ⇒ 原来的 20 只有 ≈6.7vp，肉眼几乎只是"变淡"。调到 `SHEET_BLUR_RADIUS`（px）。
/// 2. **到不了顶边 → 面板上留白挡住了**：本容器外层 Column 原来有 `PANEL_PAD_V(12)` 上留白，
///    Scroll 视口顶 = 面板顶 + 12 ⇒ 模糊最强处也在下移 12vp，顶部那道 12vp 恒清晰。
///    现把**上留白一并下放给内容层**（与横向 `PANEL_PAD_H` 同一逻辑）⇒ 视口顶 = 面板顶。
/// 3. **范围小 → 带长从「等于标题带」放长**：见 `SHEET_BLUR_BAND_VP`（不再与浮层同长）。
///    ⚠️ 浮层带长与模糊带长**解耦后仍无硬切割**：硬边来自"某处强度/颜色突变"，
///    两者各自的归零点都是**逐档渐进的**（浮层在 64vp 处 alpha 已收到 0，模糊在带尾收到 0），
///    区间 64~带尾 是"无底色 + 模糊渐弱"⇒ 只有"由虚转实"，没有台阶。
///
/// ⚠️ `linearGradientBlur` 是**前景模糊**——模糊的是组件**自身内容**（这里的滚动列表），
///   正是要的效果（内容滚到标题带时变糊）；不是 `backdropBlur` 那种取背景的模糊。
/// ⚠️ 档位位置是**组件高的比例**（0~1），而 Hds 用的是 vp 偏移 ⇒ 必须用 `onAreaChange`
///   实测 Scroll 视口高再换算，否则矮弹窗的模糊带会等比缩窄（观感与高弹窗不一致）。
/// ⚠️ **本接口会受 `BlendApplyType.OFFSCREEN` 的 `blendMode` 干扰**（`common.d.ts`：
///   OFFSCREEN 下"may cause issues with screen capture for APIs such as linearGradientBlur"）
///   ⇒ 本链路上**不要**给 Scroll / 内容加 OFFSCREEN 的 blendMode（当前没有）。
/// ⚠️ **性能**：GPU 模糊，作用在滚动列表上每帧重采样。若真机滚动掉帧，
///   优先调小 `SHEET_BLUR_RADIUS`；仍不足则缩短 `SHEET_BLUR_BAND_VP`。
/// **导出**：不走本容器的弹窗（`DownloadImportSheet` 自管布局）也挂同一份模糊，
/// 否则同一宿主（`AppSheet`）下的弹窗会"有的糊、有的不糊"。
/// 2026-10-21 用户：「加大一点模糊程度」⇒ **64 → 96**（px）。`linearGradientBlur` 的 value
/// 单位是 **px 不是 vp**，96px ≈ 32vp@3x；再往上（128+）会糊到看不出内容轮廓。
/// 真机若仍嫌不够，只调这一个值；带长（`SHEET_BLUR_BAND_VP`）决定"糊多长"，两者别一起动。
export const SHEET_BLUR_RADIUS = 96;

/// **模糊带长**（vp，2026-10-02 第十轮新增）：模糊从视口顶衰减到 0 的纵向长度。
///
/// 原本恒等于 `SHEET_TITLE_AREA_VP(64)`（与浮层标题带同长）；用户要求"范围更大" ⇒ 放长。
/// 但**不能无脑取大值**：带长必须 **≤ 内容静止留白**，否则弹窗刚打开、内容还没滚动时，
/// 首行内容就已经落在模糊带里被糊住（观感 = 内容发虚、读不清）。留白 = `SHEET_TITLE_AREA_VP
/// + PANEL_PAD_V` = 76vp ⇒ 带长在"高弹窗"封顶到 96（此时首行位于 79% 处、强度已≈0）。
/// 矮弹窗（视口本来就小）再按 `SHEET_BLUR_BAND_RATIO` 收缩，防止 96 覆盖掉大半个视口。
const SHEET_BLUR_BAND_VP = 96;
/// 带长的视口占比上限（矮弹窗用）：视口 168vp → 带 70vp（首行 76 已在带外 ⇒ 完全不糊）。
const SHEET_BLUR_BAND_RATIO = 0.42;

/// 模糊带长（vp）：高弹窗封顶 `SHEET_BLUR_BAND_VP`、矮弹窗按比例收缩，下限 `SHEET_TITLE_AREA_VP`。
/// **导出**：`DownloadImportSheet` 同口径复用（见 `blurStopsFor`）。
export function blurBandVp(componentHeight: number): number {
  if (componentHeight <= 0) return SHEET_TITLE_AREA_VP;
  let band = componentHeight * SHEET_BLUR_BAND_RATIO;
  if (band > SHEET_BLUR_BAND_VP) band = SHEET_BLUR_BAND_VP;
  if (band < SHEET_TITLE_AREA_VP) band = SHEET_TITLE_AREA_VP;
  return band;
}

/// 模糊档位（**导出重载**：给自管布局的弹窗用，逻辑与本文件内 `blurStops` 一致）
export function blurStopsFor(componentHeight: number): FractionStop[] {
  return blurStops(componentHeight);
}

/// 渐变模糊档位（模糊程度, 位置）：0 = 不糊、1 = 全量模糊；位置必须**严格递增**、数组 ≥2 项。
/// 曲线 = 「顶部恒定全糊 → 中段快衰减 → 尾部务必收到 0」：尾部（0.76 / 0.88 处 ≈ 0.06 / 0.015）
/// 正好压在**内容静止留白**（76/96 ≈ 0.79）附近 ⇒ 弹窗打开时首行几乎无残余模糊，
/// 而滚动时 0~50% 区间（强度 ≥ 0.44）糊得明显。
/// `componentHeight` = Scroll 视口实际高（vp）：带长换算成比例；首帧未上报（0）时兜底，
/// 保证档位合法（不报"位置非递增"）。
function blurStops(componentHeight: number): FractionStop[] {
  const h = componentHeight > 0 ? componentHeight : SHEET_BLUR_BAND_VP * 2;
  let band = blurBandVp(componentHeight) / h;
  if (band > 1) band = 1;
  const blur: number[] = [1, 1, 0.9, 0.68, 0.44, 0.22, 0.06, 0.015, 0];
  const frac: number[] = [0, 0.16, 0.28, 0.4, 0.52, 0.64, 0.76, 0.88, 1];
  const stops: FractionStop[] = [];
  for (let i = 0; i < frac.length; i++) {
    let p = band * frac[i];
    if (p > 1) p = 1;
    stops.push([blur[i], p]);
  }
  return stops;
}

/// **面板高度比例上限**（跟随内容后的封顶值）：
/// 竖屏 0.75 / 横屏 0.55（沿用 2026-09-08 口径）。
/// 内容矮 → 面板随内容收紧（不撑满）；内容高 → 到此封顶、内部 Scroll 承担滚动。
const PANEL_RATIO_PORTRAIT = 0.75;
const PANEL_RATIO_LANDSCAPE = 0.55;
/// **面板高度下限**（vp）：内容很少时不至于压扁到看不见内容（旧版 `MIN_CARD_HEIGHT` 同义）
const MIN_PANEL_HEIGHT = 180;
/// **面板纵向留白**（2026-10-02 第五次定案：24 → 12；第七次沿用）
///
/// 用户原话：「内容和顶部标题的距离是不是有点大了」。
/// 24 是"面板收缩贴合内容"时代的呼吸值——那时面板紧贴内容，24 是唯一的间距来源；
/// 改恒定最高高度后内容顶到标题下方即"面板顶部"，24 在整屏高的面板上明显偏空。
/// 收敛到 12：内容 ↔ 系统标题、内容 ↔ 面板底 都收紧一档。
/// ⚠️ 第七次回到"跟随内容"后，面板高度不再恒满屏，但 12 仍是观感合适的收窄值
///   （比 24 紧凑、比 8 有呼吸），**不再回调**，避免同一处反复横跳。
/// ⚠️ 与 `PANEL_PAD_H`(16) 语义不同：横向是**对齐系统标题左缘**的基准（实测值），
///   纵向是纯呼吸间距（观感值），两者不共用常量。
/// **导出**供自管布局的弹窗（`DownloadImportSheet`）手工对齐同一口径——它不经过本容器，
/// 写死数值会与其余弹窗的顶部间距分叉。
export const PANEL_PAD_V = 12;

/// **面板横向留白**（2026-10-02 第四次定案：24 → 16）
///
/// 用户原话：「因为去掉了卡片，边距应该也要缩小吧，这样才能和标题对齐」。
/// 依据：官方《半模态转场》示例 2 动图**逐像素实测**（frame_30.png，405px 宽）——
/// 标题最左暗像素 x=16（面板左缘 x=0）、关闭按钮圆形背景几乎贴面板右缘。
/// ⇒ 系统标题的横向内距**明显小于**我们原来的 24，取值 16 与标题观感齐平。
/// ⚠️ 不写"严格对齐"：截图 px 与 vp 的缩放比未知，无法反推系统真实 vp 值；
///   16 是「明显收窄 + 与应用内通用留白（搜索框/列表行）同值」的收敛值，
///   真机若仍偏内缩/偏贴边，只需调这一个常量。
///
/// ⚠️ 各弹窗行内的横向 padding 视为**在 16 之上再叠**：需要与标题对齐的行内横向留白必须为 0
///   （卡片时代为在卡片内缩进而加的那批 `padding({left:16,right:16})` 已同步清除）。
/// 导出供**卡片外的底栏**（如更新日志「知道了」按钮）对齐同一边距，避免"按钮比内容宽一圈"。
export const PANEL_PAD_H = 16;
/// 内容底部留白：内容滚到末尾时不贴着面板底边
const CONTENT_BOTTOM_PAD = 4;

/// **内容静止起点**（vp）= 标题行 `SHEET_TITLE_AREA_VP` + 内容层上留白 `PANEL_PAD_V`。
/// 与 `SheetContainer` 内容层 `padding({top})` 的表达式**同源**（改一处必须同步另一处）。
/// 用途：① 浮层标题带的画高上限（`AppSheet.SHEET_HEADER_BAND_VP`）；② 相关注释的口径基准。
export const SHEET_CONTENT_TOP_VP = SHEET_TITLE_AREA_VP + PANEL_PAD_V;

/// **标题带滚动补偿量**（vp，2026-10-02 第十四轮新增）：内容**能滚进标题带**所需的滚动余量。
///
/// 用户原话：「我感觉内容往上滚动的话 **还是无法到达弹窗的顶部最边缘** 明显差了一点距离」。
/// 根因：可滚动范围 = `内容高 − 视口高`，而内容层顶部留白（`SHEET_CONTENT_TOP_VP` 76vp）
/// **属于内容** ⇒ 它把可用滚动范围**吃掉**了 76vp —— 内容最多只能滚到"留白下沿"（76vp 处），
/// 面板顶部那 76vp 恒定露着，`linearGradientBlur` 的最强档永远压不到任何内容上。
///
/// 补偿手段 = **终点偏移**（`ScrollableCommonMethod.contentEndOffset`，@since 22）：
/// 给滚动终点也留出等量偏移 ⇒ 原本"留白占据"的那段变成真实可滚动行程，内容得以穿进标题带。
/// ⚠️ 不能用「同时给 `contentStartOffset`」的写法：官方语义是
///   `contentStartOffset + contentEndOffset` 一旦超过内容区长度就**双双归零**（`list.d.ts`
///   原文），而矮内容（视口高≈内容高）恒会触发 ⇒ 偏移静默失效。故本容器**只按差额给
///   `contentEndOffset`**，见 `endFill()`。
/// ⚠️ 与 `SHEET_HEADER_BAND_VP` 同值但**语义不同**：那个是"底色带画多高"，本值是"允许内容
///   穿进该带多少"。两者当前一致，是因为底色带正好画到内容静止起点。
export const SHEET_TITLE_SCROLL_OFFSET = SHEET_CONTENT_TOP_VP;

/// **标题带浮层总高**（2026-10-02 第十轮新增 → **第十三轮收窄**）：`AppSheet.sheetHeader()`
/// 的**渐变底色带**画多高。
///
/// - 标题行仍占 `SHEET_TITLE_AREA_VP(64)`（标题文字垂直居中 ≈ 系统关闭按钮圆心，**不动**）；
/// - 余下部分为纯渐隐缓冲区（`本值 − 64`）。
///
/// ⚠️⚠️ **本值必须 ≤ `SHEET_CONTENT_TOP_VP`（内容静止起点，76vp）——第十三轮用户报的
/// 「我非滚动状态下 媒体信息的卡片都被模糊的渐变影响到了」就是这个约束被破坏**。
/// 第十轮为"范围更大"把本值拉到 120vp，比内容起点多出 44vp —— 于是**静止状态下内容的首行
/// 就落在带内**：76vp 处底色 alpha 尚 ≈49%（`titleBandStops` 0.56 档 #9A），媒体信息顶部
/// 那张封面（padding top 16 ⇒ 约 92vp 处才起）被压暗近三成。
/// ⇒ 现收回 76vp：**底色在内容出现之前逐档归零**，静止时首行完全不受影响。
/// ⚠️ 不要"缩短而不改档位"：`titleBandStops` 的位置档是**比例**，带变矮后原本落在缓冲区里的
///   档位会整体前移、反而在内容首行处留更多底色（见 `titleBandStops` 注释）。
///
/// ⚠️ 与**模糊带长**（`SHEET_BLUR_BAND_VP` = 96，只作用于**滚动中的内容**）解耦且**本值更短**：
///   模糊带内**静止时无内容**（内容从 76vp 起，而 76vp 处模糊强度已≈0.04）⇒ 静止观感干净；
///   带长不同不会有台阶——两者各自尾部都逐档归零，且模糊作用的是**内容**、本带作用的是**底色**。
export const SHEET_HEADER_BAND_VP = SHEET_CONTENT_TOP_VP;

/// **弹窗标题带「返回按钮」规格**（2026-10-02 第十六轮新增）
/// 用户原话：「媒体->媒体信息这个弹窗的**返回按钮没有和关闭按钮垂直居中**和**做光感按钮效果**
/// **大小尺寸也注意对齐**」。
///
/// 三处都是"与其他弹窗不一致"的问题，故把规格**导出**，窄屏 `AppSheet.sheetHeader` 与宽屏
/// `AppSheet.dialogHeader`（宽屏自绘浮层）共用同一组值 —— 2026-10-07 宽屏标题改浮层后，
/// 两端结构完全同构，规格只此一处（此前宽屏写的是 40×40 且行内 padding 不同 ⇒ 观感分叉）。
///
/// - `SHEET_BACK_BTN_SIZE`：命中块 + 光感底盘的**直径**。用户说的"和关闭按钮垂直居中"
///   前提是**行高一致**：系统关闭按钮参与的是**标题行**（`SHEET_TITLE_AREA_VP` 64）的居中，
///   故本按钮也必须在这 64 行内居中。高度写 `SHEET_TITLE_AREA_VP`（占满整行），宽度取本值、
///   由 `Row.alignItems(Center)` 居中 ⇒ 按钮**圆心恰好落在标题行中心**，与标题文字、关闭按钮同线。
///   ⚠️ 旧版是 40×`SHEET_TITLE_AREA_VP` 的扁矩形命中块（纯透明）——圆心虽对，但**没有视觉形态**，
///   读起来"就是个图标"，与右上角那个带圆形背板的关闭按钮**不像一套**。
/// - `SHEET_BACK_ICON_SIZE`：`chevron_left` 图标字号。
/// - 圆角 = 直径 / 2（正圆）。
export const SHEET_BACK_BTN_SIZE = 40;
export const SHEET_BACK_ICON_SIZE = 24;

/// **返回按钮右缘 → 标题左缘的间距**（2026-10-02 第十七轮新增）
///
/// 用户原话：「有返回按钮存在的话**标题需要右移一点距离**」。
/// ⚠️ **标题本身没有"右移"的余地**：它是 `layoutWeight(1)`，左缘已由前一个兄弟（返回按钮）的
///   右缘决定；给它加 `margin.left` 只会让文字在剩余宽度里视觉偏移，与"左对齐"语义打架，
///   还会让长标题的**省略号提前出现**。用户真正感知的是"标题贴着返回按钮太近"
///   ⇒ 调整**这一处间距**即可，观感上就是"标题被让开了"。
/// ⚠️ 与整行下沉（`SHEET_TITLE_ROW_DROP_VP`）无关：这是**水平**间距，那是**垂直**位置。
export const SHEET_BACK_TITLE_GAP = 8;


/// **卡片外底栏间距**（2026-10-01 用户真机二次反馈定案）：
/// 上方 = FOOTER_PADDING_TOP(12)；下方 = FOOTER_PADDING_BOTTOM(16) + 安全区 —— 与上方基本对称。
/// ⚠️ **本值覆盖 2026-09-08 的 50**（当时三轮微调 36→44→50）。用户 2026-10-01 真机反馈：
/// 「更新日志……**知道了**那个按钮都没有很靠下，明显**离底部的距离比离内容卡片的距离更大**」
/// ——即 50 + 安全区（阔直板 ≈30vp）= 80vp 空白 vs 上方 36vp，失衡到按钮"浮在半空"。
/// 收敛到 16 后底部 ≈ 16+30 = 46vp，与上方 36vp 目视平衡；安全区仍完整避让。
export const FOOTER_PADDING_TOP = 12;
export const FOOTER_PADDING_BOTTOM = 16;

/// **卡片外底栏高度公式**（2026-09-08）：上 padding 12 + 主按钮 44 + （次按钮 40 + 间距 12）
/// + 下 padding 16；**不含底部安全区**（安全区由调用方在下 padding 上叠加，视觉抬起 ↔ 净空一致）。
/// 例：单按钮 72、双按钮 124、三按钮 176。
/// 调用方把它算出来的值传给 `bottomSpace`，SheetContainer 再据此从面板净空里扣除，
/// 保证卡片外的按钮不被顶出屏幕（小屏/横屏/分屏必现，2026-09-08 用户反馈）。
/// 另一处消费：`LyricPosterSheet.computePreviewSize()` 估算底部按钮占掉的净空以反算海报预览尺寸。
/// ⚠️ 改底栏样式必须同步这两处。
export function footerHeightOf(buttonCount: number): number {
  const n = buttonCount < 1 ? 1 : buttonCount;
  return FOOTER_PADDING_TOP + 44 + (n - 1) * (40 + 12) + FOOTER_PADDING_BOTTOM;
}

/// **面板高度上限**（vp）= min(比例值, 窗口净空)
///
/// 比例值 = 竖屏 `h*0.75` / 横屏 `h*0.55`；窗口净空 = `h − 底部安全区 − 底栏`
/// （比例值本身也可能超出可用空间——小屏/横屏/分屏/平板悬浮窗必现）。
/// 下限 `MIN_PANEL_HEIGHT`，但不许超过净空。
///
/// ⚠️ **第八轮起不再扣 `SHEET_TITLE_AREA_VP`**：标题已改**自绘浮层**（`AppSheet.sheetHeader`），
///   浮层本身**不占布局高度**（内容视口 = 面板整高，内容可滚进标题带下方）。系统标题带已移除，
///   没有需要扣的"同级占位区域"了。
///
/// **导出**供自管内容布局的弹窗（`DownloadImportSheet`——它历史原因不走本容器）
/// 取同一份口径做封顶，避免两处各算一套高度。
export function sheetPanelMaxHeight(windowHeight: number, windowIsLandscape: boolean,
  safeAreaBottom: number, bottomSpace: number): number {
  const h = windowHeight > 0 ? windowHeight : 600;
  const ratio = windowIsLandscape ? PANEL_RATIO_LANDSCAPE : PANEL_RATIO_PORTRAIT;
  const byRatio = h * ratio;
  const chrome = safeAreaBottom + bottomSpace;
  const available = h - chrome;
  const cap = available > 0 ? Math.min(byRatio, available) : byRatio;
  const floor = Math.min(MIN_PANEL_HEIGHT, available > 0 ? available : MIN_PANEL_HEIGHT);
  return cap < floor ? floor : cap;
}

/// **面板内容区上限**（vp）= 面板高度上限 − 面板上下留白
export function sheetPanelContentMax(windowHeight: number, windowIsLandscape: boolean,
  safeAreaBottom: number, bottomSpace: number): number {
  const v = sheetPanelMaxHeight(windowHeight, windowIsLandscape, safeAreaBottom, bottomSpace)
    - PANEL_PAD_V * 2;
  return v > 0 ? v : MIN_PANEL_HEIGHT;
}

@Component
export struct SheetContainer {
  /// 窗口高度（vp，Index 广播）——面板高度基准
  @StorageLink('windowHeight') windowHeight: number = 0;
  /// 窗口横竖屏（Index 广播）——**竖屏按内容自适应紧凑 / 横屏撑满受限高度滚动**
  /// （2026-08-21 用户定案；第七次"跟随内容"沿用同一套）
  @StorageLink('windowIsLandscape') windowIsLandscape: boolean = false;
  /// 卡片外还挂了底栏时（如更新日志「知道了」按钮条）传该高度——
  /// 要从面板净空里扣掉，否则底栏（在最外层 Column 内、本容器下方）会被顶出屏幕
  @Prop bottomSpace: number = 0;
  /// 底部安全区（导航条/手势条高度）——bindSheet 内容不自动避让，净空必须扣掉
  @StorageLink('safeAreaBottom') safeAreaBottom: number = 0;
  /// **外部可控滚动器**（2026-10-21 新增，可选）：默认自建，外部传进来就能主动
  /// `scrollTo(0)`——更新日志弹窗首次挂载时内容高度边测边涨，会停在中段，需要开局把
  /// 位置钉回顶部（成因见 ChangelogSheetHost.onShowSignal 注释）。
  /// ⚠️ 只是把 Scroll 的滚动器换成外部实例，**不改任何布局/滚动行为**。
  sheetScroller: Scroller = new Scroller();
  @BuilderParam content: () => void;
  /// Scroll 视口实际高（vp，`onAreaChange` 实测）——`linearGradientBlur` 的档位位置是
  /// **组件高的比例**，需要它把「固定 vp 带长」换算成比例（见 `blurStops`）。
  /// 只在跨整数 vp 时赋值，避免逐帧重渲染。
  @State viewportH: number = 0;
  /// 内容盒实际高（vp，`onAreaChange` 实测，**含**内容层 padding）——与 `viewportH` 一起
  /// 算「内容是否真的滚得动」，见 `endFill()`。
  @State contentH: number = 0;
  /// **顶部留白模式**（2026-10-02 第十四轮新增）：
  /// - `true`（默认，绝大多数弹窗）：内容自带 `SHEET_TITLE_AREA_VP + PANEL_PAD_V` 顶部 padding
  ///   ⇒ 静止时从标题带下沿开始、滚动时穿进标题带被模糊（由 `endFill()` 补足滚动行程）；
  /// - `false`：**内容自己占满面板**（如播放队列的 `List`——它内部已有"顶部留空 ListItem"和
  ///   自身的 `contentStartOffset`）⇒ 本容器**不再加顶部 padding**，否则两层留白叠加、
  ///   且外层 Scroll 把 List 当内容托着会再吃掉一段行程。
  @Prop contentTopPad: boolean = true;
  /// ⚠️ **宽屏居中 dialog 下内容层不加顶部留白**（2026-10-07 第二轮）：
  /// 宽屏标题行是**真实占位**（`AppSheet.dialogHeader` 在 `Column` 里占布局高度）
  /// ⇒ 再留 76vp 就成了双份，真机读作「**内容默认垂直居中了 而不是从上到下排布的**」
  /// （用户 2026-10-07 反馈）。
  /// 判定走 `DeviceProfile.isWideDialog()`（与 `AppSheet` **同一份实现**，见其注释的同步要求）。

  /// 内容区上限 = 面板高度上限 − 面板上下留白（本容器 Column 的 padding）
  private contentMax(): number {
    return sheetPanelContentMax(this.windowHeight, this.windowIsLandscape,
      this.safeAreaBottom, this.bottomSpace);
  }

  /// **滚动终点补偿**（vp）——见 `SHEET_TITLE_SCROLL_OFFSET`。
  ///
  /// `可滚动范围 = 内容高 − 视口高` 是滚动行程的**唯一来源**。留白（76vp）属于内容 ⇒ 当内容
  /// 只比视口高出一点点时（`away < 76`），行程不足以把首行推到面板顶边 —— 正是用户看到的
  /// 「**明显差了一点距离**」。此处把行程补到 76vp（`fill = 76 − away`）。
  ///
  /// ⚠️ **内容没超出视口时（`away ≤ 0`）必须返回 0**，不能"补满 76"：
  ///   ① 那种情况内容本就完整可见、无需滚动；
  ///   ② `Scroll` 竖屏是 `height('auto')`，若给偏移后其布局高把偏移算进去，面板就会凭空高出
  ///      76vp —— 直接破坏第七轮定案的「跟随内容」。只对**已经溢出**（面板已顶到上限）的弹窗
  ///      补偏移，面板高度不受影响。
  /// - `away ≥ 76`（内容足够长）：本就够行程，补 0（否则底部平白多一段空白行程）；
  /// - `0 < away < 76`：补到 76 ⇒ 首行能穿进标题带、被 `linearGradientBlur` 糊掉。
  ///
  /// ⚠️ **首帧兜底**：`viewportH`/`contentH` 未上报（0）时返回 0（不给偏移），
  ///   避免用"内容高 0"算出满额偏移、造成开场一次跳动。
  private endFill(): number {
    if (!this.contentTopPad) return 0;
    // 宽屏不再特殊：2026-10-21 起宽屏标题同样是**浮层**、内容同样吃 76vp 留白
    // ⇒ 与窄屏一样需要把"留白吃掉的行程"补回来（否则滚不到标题带、糊不起来）。
    if (this.viewportH <= 0 || this.contentH <= 0) return 0;
    const away = this.contentH - this.viewportH;
    if (away <= 0) return 0;
    const fill = SHEET_TITLE_SCROLL_OFFSET - away;
    return fill > 0 ? fill : 0;
  }

  /// **内容盒**（Scroll 内部承担横向留白 / 顶部留白 / 内容盒高实测）——
  /// 宽屏与窄屏共用同一份，避免"两处各写一遍"（本轮为让宽屏**不挂** `linearGradientBlur`
  /// 而把 Scroll 分成两条分支，这是唯一被抽出的公共部分）。
  ///
  /// ⚠️ 内层内容**逐字节等同**改动前（顶白表达式见 `padding` —— 宽屏自动关顶白，
  ///   因为宽屏标题行是**真实占位**）。
  /// **内容盒**（Scroll 的内部：横向留白 / 顶部留白 / 内容盒高实测）——
  /// 宽屏与窄屏**共用同一份**：本轮为了让宽屏**不挂** `linearGradientBlur`
  /// （真机黑块）而把 Scroll 分成两条分支，这里是被抽出的公共部分。
  ///
  /// ⚠️ 内层内容与改动前**逐字节等同**（顶白表达式见 `padding`：宽屏自动关顶白，
  ///   因为宽屏标题行是**真实占位**）。
  @Builder
  panelInner() {
    Column() {
      this.content()
    }
    .width('100%')
    // **首部留白 = 标题带高度**（2026-10-02 第八轮）：标题改自绘浮层后**不占布局高度**
    // （内容视口 = 面板整高 ⇒ 内容**可以滚进标题带下方**，这正是用户要的）；但**静止时**
    // 内容应从标题带下沿开始 ⇒ 在**内容层**顶部加等量 padding（padding 属内容，随滚动一起走）。
    // ⚠️ **不用 `Blank()` 垫空块**：Blank 主轴方向带 flexGrow 语义，在本 Column（竖屏
    //   `height('auto')`、高度由内容决定）里可能反过来把矮内容撑到视口高，破坏"跟随内容"。
    // ⚠️ 与 `AppSheet.sheetHeader()` 的带高**同源**（都是 `SHEET_TITLE_AREA_VP`），
    //   改一处必须同步另一处，否则会出现"内容被标题压住"或"标题下方多一段空白"。
    // **四周留白（含纵向）全由内容自己承担** ⇒ Scroll 视口 = **面板整宽 + 面板整高**：
    // ① 横向：浮动件（搜索胶囊/材质卡片）的外阴影/光感有余量可落（不被视口边缘裁掉）；
    // ② **纵向（2026-10-02 第十轮）**：上留白从面板层下放到这里后，视口顶 = **面板顶**
    //    ⇒ `linearGradientBlur` 的最强档正好压在面板顶边（用户：「无法完全到弹窗的顶部边缘」）。
    //    ⚠️ 旧版面板层留 `PANEL_PAD_V(12)` 上白 ⇒ 顶部那道 12vp 恒清晰，模糊"差一口气到顶"。
    // 上留白 = `SHEET_TITLE_AREA_VP`（标题带）+ `PANEL_PAD_V`（内容 ↔ 标题带的呼吸）。
    // ⚠️ **第十轮的下放只解决了"糊不到顶"，没解决"滚不到顶"**（第十四轮修）：留白属于内容
    //   ⇒ 它占掉 76vp 的可滚动范围，内容最多滚到留白下沿、永远碰不到面板顶边。
    //   补偿见 Scroll 上的 `contentEndOffset(this.endFill())`。
    // ⚠️ `contentTopPad = false`（播放队列）时**不加顶白**：内容占满面板，留白由内容自理。
    // ⚠️ **宽屏（居中 dialog）也要这份顶白**（2026-10-21 改）：宽屏标题已改**浮层**
    //   （`AppSheet.dialogBody` 从 Column 改回 Stack），不再占布局高度 ⇒ 内容静止时必须
    //   自己让开标题带。旧口径"宽屏标题真实占位、再留一份就双留白"已随结构变更失效。
    .padding({
      left: PANEL_PAD_H, right: PANEL_PAD_H,
      top: this.contentTopPad
        ? SHEET_TITLE_AREA_VP + PANEL_PAD_V : 0,
      bottom: CONTENT_BOTTOM_PAD,
    })
    // 实测**内容盒高**（含上面的 padding）——`endFill()` 用它算"内容是否真的滚得动"。
    // 只在跨整数 vp 时赋值（省重渲染，与 `viewportH` 同口径）。
    .onAreaChange((_oldC: Area, newC: Area) => {
      const ch = Math.round(Number(newC.height));
      if (ch > 0 && ch !== this.contentH) {
        this.contentH = ch;
      }
    })
  }

  build() {
    Column() {
      // **唯一 Scroll**：竖屏 `height('auto')` — 内容矮则面板随内容收紧（第七次"跟随内容"）；
      // 横屏 `height('100%')` — 父级是本 Column 的确定高度（下面 constraintSize 封顶），
      // 撑满受限高度滚动。两者统一由 `constraintSize({ maxHeight })` 封顶成真实滚动视口。
      //
      // ⚠️ 竖屏**绝不能用 `height('100%')`**：曾因 Scroll '100%' + maxHeight 把内容少的弹窗
      //   撑到 440vp 高（2026-08-21 用户定案修好），内容少时明确要紧凑。
      if (DeviceProfile.isWideDialog()) {
        // **宽屏居中 dialog：完全不挂 `linearGradientBlur`**（2026-10-07 第三轮，真机黑块仍未消）
        //
        // 用户报「弹窗**还是有背景色错乱**的问题啊 例如更新日志弹窗」+ 截图铁证：
        // **黑块四角直角、边界正好等于本 Scroll 的布局边界**（含底部一条 `PANEL_PAD_V`），
        // 而**标题带与底栏正常**。第一轮已退回"宽度 / Stack / clip"三个变量，仍复现
        // ⇒ 按排除法，剩下的唯一候选就是**本层挂的 `linearGradientBlur`**
        //   （全链路只有它挂在该层；`common.d.ts` 明示该接口受离屏混合干扰）。
        // 机理：宽屏 `openCustomDialog` 的内容节点处在**高度由内容驱动**的容器里
        //   （前一轮已实测 `height('100%')` 在此无参照），模糊所需的离屏层尺寸无法稳定建立
        //   ⇒ 渲染成整块黑面。窄屏 `bindSheet` 的父级有面板高度上下文，故一直正常。
        //
        // ⇒ 宽屏**让该属性直接缺席**（不是传 0：0 仍可能建立离屏层）。
        //   功能无损失：宽屏标题行是**真实占位**、内容不会穿过标题带，
        //   顶部层次由 `AppSheet.dialogHeader()` 的**多档渐隐底**独立承担。
        Scroll(this.sheetScroller) {
          this.panelInner()
        }
        .width('100%')
        // 宽屏父级无确定高度 ⇒ 不用百分比，走 `auto`（仍由下面 `constraintSize` 封顶）
        .height('auto')
        .constraintSize({ maxHeight: this.contentMax() })
        .scrollBar(BarState.Off)
        .contentEndOffset(this.endFill())
        .edgeEffect(EdgeEffect.Spring)
        // **宽屏也挂同一份渐变模糊**（2026-10-21 用户："同步给大屏的弹窗一起改"）：
        // 此前这里**刻意缺席**——2026-10-07 真机上宽屏弹窗内容区整块变黑，归因到本属性的
        // 离屏层（同时还叠着"根节点写死 420 > 容器上限 400"与"`.clip(true)`"两个变量）。
        // 那两个诱因现已消失（宽度走 `wideDialogWidth()` ≤ 400vp、`dialogBody` 不再 clip），
        // 且标题已改浮层、内容会真的穿进标题带 ⇒ 必须补上才有"由虚转实"。
        // ⚠️ 若真机重现"内容区黑块"：先把 `SHEET_BLUR_RADIUS` 归零确认是否本属性，
        //   确认后**只回退这一处**（宽屏标题带保持纯透明即可），不要动窄屏分支。
        .linearGradientBlur(SHEET_BLUR_RADIUS, {
          fractionStops: blurStops(this.viewportH),
          direction: GradientDirection.Bottom,
        })
        .onAreaChange((_oldV: Area, newV: Area) => {
          const h = Math.round(Number(newV.height));
          if (h > 0 && h !== this.viewportH) {
            this.viewportH = h;
          }
        })
      } else {
        // **窄屏（bindSheet）—— 本节逐字节保持既有实现**（用户明确要求：改动不要影响该分支）
      Scroll(this.sheetScroller) {
        Column() {
          this.content()
        }
        .width('100%')
        // **首部留白 = 标题带高度**（2026-10-02 第八轮）：标题改自绘浮层后**不占布局高度**
        // （内容视口 = 面板整高 ⇒ 内容**可以滚进标题带下方**，这正是用户要的）；但**静止时**
        // 内容应从标题带下沿开始 ⇒ 在**内容层**顶部加等量 padding（padding 属内容，随滚动一起走）。
        // ⚠️ **不用 `Blank()` 垫空块**：Blank 主轴方向带 flexGrow 语义，在本 Column（竖屏
        //   `height('auto')`、高度由内容决定）里可能反过来把矮内容撑到视口高，破坏"跟随内容"。
        // ⚠️ 与 `AppSheet.sheetHeader()` 的带高**同源**（都是 `SHEET_TITLE_AREA_VP`），
        //   改一处必须同步另一处，否则会出现"内容被标题压住"或"标题下方多一段空白"。
        // **四周留白（含纵向）全由内容自己承担** ⇒ Scroll 视口 = **面板整宽 + 面板整高**：
        // ① 横向：浮动件（搜索胶囊/材质卡片）的外阴影/光感有余量可落（不被视口边缘裁掉）；
        // ② **纵向（2026-10-02 第十轮）**：上留白从面板层下放到这里后，视口顶 = **面板顶**
        //    ⇒ `linearGradientBlur` 的最强档正好压在面板顶边（用户：「无法完全到弹窗的顶部边缘」）。
        //    ⚠️ 旧版面板层留 `PANEL_PAD_V(12)` 上白 ⇒ 顶部那道 12vp 恒清晰，模糊"差一口气到顶"。
        // 上留白 = `SHEET_TITLE_AREA_VP`（标题带）+ `PANEL_PAD_V`（内容 ↔ 标题带的呼吸）。
        // ⚠️ **第十轮的下放只解决了"糊不到顶"，没解决"滚不到顶"**（第十四轮修）：留白属于内容
        //   ⇒ 它占掉 76vp 的可滚动范围，内容最多滚到留白下沿、永远碰不到面板顶边。
        //   补偿见下面的 `contentEndOffset(this.endFill())`。
        // ⚠️ `contentTopPad = false`（播放队列）时**不加顶白**：内容占满面板，留白由内容自理。
        .padding({
          left: PANEL_PAD_H, right: PANEL_PAD_H,
          top: this.contentTopPad
            ? SHEET_TITLE_AREA_VP + PANEL_PAD_V : 0,
          bottom: CONTENT_BOTTOM_PAD,
        })
        // 实测**内容盒高**（含上面的 padding）——`endFill()` 用它算"内容是否真的滚得动"。
        // 只在跨整数 vp 时赋值（省重渲染，与 `viewportH` 同口径）。
        .onAreaChange((_oldC: Area, newC: Area) => {
          const ch = Math.round(Number(newC.height));
          if (ch > 0 && ch !== this.contentH) {
            this.contentH = ch;
          }
        })
      }
      .width('100%')
      .height(this.windowIsLandscape ? '100%' : 'auto')
      .constraintSize({ maxHeight: this.contentMax() })
      .scrollBar(BarState.Off)
      // **滚动终点补偿**（2026-10-02 第十四轮）：把"顶部留白吃掉的那段行程"补回来
      // ⇒ 内容能一路滚到**面板顶边**（用户：「还是无法到达弹窗的顶部最边缘 明显差了一点距离」），
      // 那一刻 `linearGradientBlur` 的最强档才真正压着内容 —— 渐隐模糊从此"看得见"。
      // ⚠️ 官方语义（`list.d.ts`）：`contentStartOffset + contentEndOffset` 超过内容区长度会
      //   **双双归零** ⇒ 本容器**不给 `contentStartOffset`**（内容层 padding 已充当起始偏移），
      //   只按差额给终点（`endFill()`），矮内容才不会被静默回退。
      .contentEndOffset(this.endFill())
      // **Spring 回弹**（2026-10-02 第六次定案修）：原 `EdgeEffect.None` 无回弹——
      // 内容不足一屏时**完全不动**，用户读作「内容区域看起来还是不能滚动」。本仓范式
      // （所有 List / 子页）均为 `Spring` + `fadingEdge`；回弹是"这里可以滚"的直观反馈。
      .edgeEffect(EdgeEffect.Spring)
      // **顶部渐变模糊**（2026-10-02 第九轮，替代第八轮的 `backdropBlur` 标题带）：
      // 内容滚到标题带时**逐档变糊**（模糊强度渐变，非均匀模糊）⇒ 无硬切割。
      // 方向 `Bottom` = "from top to bottom" ⇒ 档位位置 0 在**视口顶部**（正是标题带处）。
      // 档位由 `onAreaChange` 实测的视口高换算（见 `blurStops` 注释）。
      .linearGradientBlur(SHEET_BLUR_RADIUS, {
        fractionStops: blurStops(this.viewportH),
        direction: GradientDirection.Bottom,
      })
      // 实测视口高 → 换算模糊带比例；只在跨整数 vp 时赋值（省重渲染）
      .onAreaChange((_oldV: Area, newV: Area) => {
        const h = Math.round(Number(newV.height));
        if (h > 0 && h !== this.viewportH) {
          this.viewportH = h;
        }
      })
      }
      // ⚠️ **第八轮起移除 `fadingEdge`**：顶部渐隐已由 `AppSheet.sheetHeader()` 的
      //   渐变底 + 本处 `linearGradientBlur` 共同承担（复刻官方观感）；此处再叠一层
      //   fadingEdge 会让标题下方的内容"双重淡出"、且底部也一并渐隐（用户没要求底部渐隐）。
    }
    .width('100%')
    // **面板可视高上限**（关键：横屏时内层 Scroll 的 `height('100%')` 需要父级有确定高度，
    // 否则百分比失去参照 → 滚动视口塌陷）
    .constraintSize({
      maxHeight: sheetPanelMaxHeight(this.windowHeight, this.windowIsLandscape,
        this.safeAreaBottom, this.bottomSpace),
    })
    // **面板只在纵向留白（横向已下放到滚动内容层）**：
    // ⚠️ **上留白 2026-10-02 第十轮移除**——模糊要"到弹窗顶边"，视口顶就必须等于面板顶；
    //   原 `PANEL_PAD_V` 上白已并入内容层的 `SHEET_TITLE_AREA_VP + PANEL_PAD_V`。
    //   下留白保留 `PANEL_PAD_V`：内容滚到末尾不贴面板底边（`CONTENT_BOTTOM_PAD` 之上再加一层）。
    //   横向 16 仍由滚动内容那层承担（见文件头「横向内距的唯一出处」）。
    .padding({ bottom: PANEL_PAD_V })
    // 面板底色透明：弹窗不透明底色由 AppSheet 的 bindSheet backgroundColor 统一提供
    .backgroundColor(Color.Transparent)
  }
}