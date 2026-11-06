/// 安全区避让高度（全屏布局 setWindowLayoutFullScreen 后，UI 需手动避让状态栏/导航条）
/// 由 EntryAbility 开全屏后从 window.getWindowAvoidArea 取值写入 AppStorage
/// UI 读 SafeArea.top / SafeArea.bottom / SafeArea.left / SafeArea.right 加 padding
/// 竖屏：top=状态栏、bottom=导航条；横屏：状态栏在左右 → left/right 有值（挖孔同区域）
///
/// ## ★ 2026-10-13「隐藏状态栏期间不改 top」——布局不塌陷的唯一正解
///
/// 用户原话：「**对接一下隐藏状态栏？因为之前隐藏之后会导致布局塌陷 所以我取消了**」
/// （参考工程 `Icey-Reader` 阅读页的同名机制，本文件是它的**精简移植**）。
///
/// ### 旧行为为什么塌陷（三段式）
///   1. `ConcertPage`/`RealPlayerPage` 进页面隐藏状态栏（`WindowHelper.setStatusBarVisible(false)`）；
///   2. 系统回报 `avoidAreaChange(top=0)` → 旧 `set()` **照单全收**写进 `safeAreaTop`；
///   3. 全 App 的 `@StorageLink('safeAreaTop')` 订阅方（Hds 标题栏、各页首项 Blank、
///      播放页封面 top 边距…）**按"全屏态"重排一帧** ⇒ 标题/内容整体**上跳 38vp**；
///      退出页面时值变回 38 ⇒ **再跳一次**。这就是用户看到的"布局塌陷"。
///
/// ### 正解：**根本不让它变**
///   隐藏状态栏是**那一屏自己的**诉求；而 `safeAreaTop` 服务的是**全 App 的避让口径** ——
///   其它页面从来不需要知道"状态栏被藏起来了"。
///   ⇒ 隐藏期间把这次 `top=0` 的回报**整条丢弃**（不写 AppStorage）：
///     · `safeAreaTop` 在整个隐藏期间**恒为上一次的真值** ⇒ 全 App **一次重排都没有**；
///     · 退出隐藏时值本来就没变过 ⇒ 不存在"恢复"这一步 ⇒ 位移从根上消失（不是被补丁挡住）。
///
/// ### 两个状态位（不可合并）
///   · `barsHiddenByUs` —— **我们正在隐藏**（开开关 / 进演唱会·仿真播放器页时置位，恢复时清位）；
///   · `pendingConfirm` —— **刚恢复**、正在等"状态栏真值"回来（`top>0`）的那一段，
///     期间迟到的 `time=0` 回报也要丢（`avoidAreaChange` 是跨进程异步，到达时刻不可控）。
///   两者恰好覆盖连续的两个阶段，中间没有缝隙 —— 这是"有概率位移"不再出现的关键。
///
/// ### ⚠️ 横屏豁免（本项目与 Reader 的唯一实质差异）
///   横屏下状态栏在左右两侧，`top` **合法地就是 0**。若不区分地丢弃，`safeAreaTop` 会卡在
///   竖屏的 38 ⇒ 横屏顶部平白留 38vp 空白（且不报错）。
///   ⇒ `set()` 增加 `portrait` 入参（由 `EntryAbility.refreshSafeArea` 按 drawableRect 判定），
///     **只在竖屏下丢弃 top=0**。横屏照常采纳 0，`left/right` 两项本就不受影响。
import { hilog } from '@kit.PerformanceAnalysisKit';

/// 「恢复状态栏后仍丢弃迟到 0」的时间窗（ms，兜底；主判据是 `pendingConfirm` 状态机）。
/// 取值 = 系统回报 + 恢复动画的合理上界；超时强制放行，避免异常路径下**永久吞掉**真实的 0。
const STALE_ZERO_WINDOW_MS = 2000;

export class SafeArea {
  /// **上一次观察到的「真实状态栏高度」**（vp，只记 >0 的值）。
  /// 用途：`restoreTopOptimistic()` 在"恢复方向"上乐观写回真值，避免转场首帧读到全屏态的 0。
  /// ⚠️ **不预设假值**（Reader 里写死 38 是因为它的阅读页需要首帧兜底）；本项目窗口在 2in1 上
  ///   真实 top 就是 0，预设 38 会凭空多出顶部留白 ⇒ 初始 0，只由系统回报填充。
  private static lastTop: number = 0;

  /// 是否有"我们自己"正在隐藏状态栏（见文件头）。`markBarsHidden/markBarsVisible` 维护。
  private static barsHiddenByUs: boolean = false;

  /// 刚恢复状态栏、正在等真值回报（见文件头）。
  private static pendingConfirm: boolean = false;

  /// 恢复动作的时间戳（0 = 本次进程从未恢复过）。
  private static restoreStampMs: number = 0;

  /// 派发隐藏指令**之前**调用（让随后到达的 `top=0` 被识别为"我们要的全屏态"而丢弃）
  static markBarsHidden(): void {
    SafeArea.barsHiddenByUs = true;
    SafeArea.restoreStampMs = 0;
    // ⚠️ 不动 `pendingConfirm`：它属于"上一次恢复后仍在等真值"的窗口，清掉会让那次迟到的 0 漏进来。
  }

  /// 恢复状态栏时调用：进入"等真值回来"的状态（期间迟到的 0 继续丢）
  static markBarsVisible(): void {
    SafeArea.barsHiddenByUs = false;
    SafeArea.restoreStampMs = Date.now();
    SafeArea.pendingConfirm = true;
  }

  /// 状态栏高度（vp）
  static get top(): number {
    return AppStorage.get<number>('safeAreaTop') ?? 0;
  }

  /// 导航条高度（vp）
  static get bottom(): number {
    return AppStorage.get<number>('safeAreaBottom') ?? 0;
  }

  /// 左避让宽度（vp，横屏状态栏/挖孔在左时）
  static get left(): number {
    return AppStorage.get<number>('safeAreaLeft') ?? 0;
  }

  /// 右避让宽度（vp，横屏状态栏/挖孔在右时）
  static get right(): number {
    return AppStorage.get<number>('safeAreaRight') ?? 0;
  }

  /// 写入四项（唯一出口）。`portrait` = 当前窗口是否竖屏（横屏时 top=0 是合法真值，不能当"隐藏造成"丢掉）
  static set(top: number, bottom: number, left: number = 0, right: number = 0,
             portrait: boolean = true): void {
    const dtRestore: number = SafeArea.restoreStampMs > 0 ? Date.now() - SafeArea.restoreStampMs : -1;
    const inHideWindow: boolean = SafeArea.barsHiddenByUs
      || SafeArea.pendingConfirm
      || (SafeArea.restoreStampMs > 0 && dtRestore <= STALE_ZERO_WINDOW_MS);

    // ★ 丢弃"隐藏造成的竖屏 top=0"（见文件头）。只丢 top，bottom/left/right 照收 ——
    //   隐藏状态栏只影响顶部这一项；left/right 恰恰是横屏承载状态栏/挖孔的两项。
    if (top === 0 && portrait && inHideWindow) {
      const cur = AppStorage.get<number>('safeAreaTop') ?? 0;
      hilog.info(0x0000, 'SafeArea',
        'set top=0 **丢弃**(hiddenByUs=%{public}s pending=%{public}s dtRestore=%{public}d) 保持 top=%{public}d',
        `${SafeArea.barsHiddenByUs}`, `${SafeArea.pendingConfirm}`, dtRestore, cur);
      SafeArea.writeIfChanged(bottom, left, right);
      return;
    }

    // ★ 收到真值（top>0）⇒ 解除"等状态栏回来"挂起
    if (SafeArea.pendingConfirm && top > 0) {
      SafeArea.pendingConfirm = false;
      hilog.info(0x0000, 'SafeArea', '收到真值 top=%{public}d ⇒ 解除挂起（此后恢复正常采纳）', top);
    }

    // 记下真实状态栏高度（只在 >0 时记，避免把"全屏态 0"当真实值记进去）
    if (top > 0) {
      SafeArea.lastTop = top;
    }
    hilog.info(0x0000, 'SafeArea',
      'set top=%{public}d bottom=%{public}d left=%{public}d right=%{public}d portrait=%{public}s',
      top, bottom, left, right, `${portrait}`);
    SafeArea.writeIfChangedAll(top, bottom, left, right);
  }

  /// **只在值真的变了才写**（同值回报零派发）
  /// `AppStorage.set` 对相同值虽通常不触发 `@StorageLink`，但仍是"派发 + 框架判等"的路径 ——
  /// 状态栏显隐动画期间回报很密，显式判等把"无意义重排"的窗口彻底关掉。
  private static writeIfChanged(guard: number, left: number, right: number): void {
    const b = AppStorage.get<number>('safeAreaBottom') ?? 0;
    const l = AppStorage.get<number>('safeAreaLeft') ?? 0;
    const r = AppStorage.get<number>('safeAreaRight') ?? 0;
    if (guard !== b) AppStorage.set<number>('safeAreaBottom', guard);
    if (left !== l) AppStorage.set<number>('safeAreaLeft', left);
    if (right !== r) AppStorage.set<number>('safeAreaRight', right);
  }

  /// 四项分别判等后写入（`top` 版，见 `writeIfChanged`）
  private static writeIfChangedAll(top: number, bottom: number, left: number, right: number): void {
    const t = AppStorage.get<number>('safeAreaTop') ?? 0;
    const b = AppStorage.get<number>('safeAreaBottom') ?? 0;
    const l = AppStorage.get<number>('safeAreaLeft') ?? 0;
    const r = AppStorage.get<number>('safeAreaRight') ?? 0;
    if (top !== t) AppStorage.set<number>('safeAreaTop', top);
    if (bottom !== b) AppStorage.set<number>('safeAreaBottom', bottom);
    if (left !== l) AppStorage.set<number>('safeAreaLeft', left);
    if (right !== r) AppStorage.set<number>('safeAreaRight', right);
  }

  /// **恢复状态栏时的乐观写入**：立刻把 `safeAreaTop` 写回记忆里的真值。
  /// 新口径下隐藏期间 `safeAreaTop` 根本没被改成 0 ⇒ 本方法多数时候走到"值相等、什么都不写"。
  /// 仍保留兜底两种边角：冷启动直进隐藏态（首帧可能还是初始 0）、隐藏期间横竖屏切换。
  static restoreTopOptimistic(): void {
    if (SafeArea.lastTop > 0 && SafeArea.top !== SafeArea.lastTop) {
      AppStorage.set<number>('safeAreaTop', SafeArea.lastTop);
    }
  }

  static init(): void {
    AppStorage.setOrCreate<number>('safeAreaTop', 0);
    AppStorage.setOrCreate<number>('safeAreaBottom', 0);
    AppStorage.setOrCreate<number>('safeAreaLeft', 0);
    AppStorage.setOrCreate<number>('safeAreaRight', 0);
  }
}