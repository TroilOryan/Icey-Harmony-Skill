/// 统一弹窗宿主：手机（窄屏）= bindSheet 底部弹窗；平板/二合一（宽屏）= **窗口级居中 dialog**。
/// 宽屏用 promptAction.openCustomDialog（窗口级，不受宿主组件位置影响——MediaListTile 等
/// 列表项内嵌场景也能全屏居中；bindSheet 无居中模式，SheetMode 只有 OVERLAY/EMBEDDED）。
/// 各处弹窗只传 show + 内容（内容自管标题结构），样式全局一致。
/// 用法：AppSheet({ show: this.show }) { SheetContainer({ title: 'xxx' }) { ... } }
import { ThemeManager } from '../../model/ThemeManager';
import { display, promptAction, LengthMetrics } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { SheetManager } from '../../services/SheetManager';

@Component
export struct AppSheet {
  /// 是否显示（父组件 @State 双向绑定；宽屏时 @Watch 驱动窗口 dialog 开/关）
  @Link @Watch('onShowChange') show: boolean;
  /// 高度配置（仅 bindSheet 用；宽屏 dialog 高度=内容自适应）
  @Prop detents: [SheetSize, (SheetSize)?, (SheetSize)?] = [SheetSize.FIT_CONTENT, SheetSize.LARGE];
  /// 右上角系统关闭按钮（仅 bindSheet 用）
  @Prop showClose: boolean = true;
  /// 是否允许手动关闭（默认 true；false=拦截蒙层点击/返回，仅由外部信号关闭——导入进度等场景）
  @Prop dismissible: boolean = true;
  /// 互斥分组（借鉴 DialogHub 弹窗栈思想）：同 group 的弹窗打开时自动关闭其他已打开的，
  /// 防同页多弹窗叠加（两层蒙层叠压）。默认 '' = 不参与互斥（嵌套弹窗安全：内层弹窗留空/换组）。
  /// 用法：Index 根级弹窗传 group='index'，页面级弹窗传 group='page:xxx'。
  @Prop group: string = '';
  /// App 退后台信号（版本号 +1 广播，EntryAbility.onBackground）：宽屏窗口 dialog 退后台不自动关，
  /// 回前台残留——这里统一关闭可手动关闭的弹窗（dismissible=false 的保留，如导入进度）
  @StorageLink('appBackgrounded') @Watch('onAppBackgrounded') appBackgrounded: number = 0;
  /// 关闭/消失额外回调（如新建歌单弹窗收起时重置输入态）
  onDismiss: () => void = () => {};
  /// 弹窗内容（标题结构由内容自管）
  @BuilderParam content: () => void;
  /// 宽屏窗口 dialog id（关闭用；-1 = 未打开）
  private dialogId: number = -1;
  /// 全局弹窗注册表条目 id（-1 = 未注册）
  private sheetId: number = -1;
  /// 重建信号（外部 +1）：宽屏 dialog 可能被系统组件（picker 等）顶掉/残留，
  /// bump 此信号让当前打开的 dialog 先关再开（无此场景可忽略不触发）
  @StorageLink('sheetReopen') @Watch('onReopen') sheetReopen: number = 0;

  aboutToAppear(): void {
    // 注册到全局弹窗管理（退后台关闭/同组互斥用）
    this.sheetId = SheetManager.register({
      group: this.group,
      dismissible: this.dismissible,
      close: () => this.close(),
    });
    // 宽屏且初始已显示：直接打开（@Watch 不回调初始值）
    if (this.isWideScreen() && this.show) this.openWideDialog();
    // 初始即显示的同组弹窗：关闭同组其他已打开的（防叠加）
    if (this.show && this.group) {
      SheetManager.closeGroup(this.group, this.sheetId);
    }
  }

  aboutToDisappear(): void {
    if (this.sheetId >= 0) {
      SheetManager.unregister(this.sheetId);
      this.sheetId = -1;
    }
    this.closeWideDialog();
  }

  /// App 退后台：关闭可手动关闭的弹窗（宽屏窗口 dialog 退后台不自动关，防回前台残留）
  onAppBackgrounded(): void {
    hilog.info(0x0000, 'AppSheet', `onAppBackgrounded show=${this.show} dismissible=${this.dismissible}`);
    if (this.show && this.dismissible) this.close();
  }

  /// 导入进度弹窗重建（选择器关闭后 dialog 可能被系统顶掉/残留）：仅当前已显示的宽屏 dialog 响应
  onReopen(): void {
    hilog.info(0x0000, 'AppSheet', `onReopen show=${this.show} wide=${this.isWideScreen()} dialogId=${this.dialogId}`);
    if (this.show && this.isWideScreen()) {
      this.closeWideDialog();
      // 等关闭完成再重开（避免同一帧关+开冲突）
      setTimeout(() => { this.openWideDialog(); }, 120) as number;
    }
  }

  /// 关闭（宽屏 dialog 由 onWillDismiss/外部信号触发；bindSheet 由 onDisappear 回调）
  private close(): void {
    this.show = false;
    this.onDismiss();
  }

  /// 宽屏：show 变化驱动窗口级居中 dialog 开/关
  onShowChange(): void {
    hilog.info(0x0000, 'AppSheet', `onShowChange show=${this.show} wide=${this.isWideScreen()} dialogId=${this.dialogId}`);
    // 同组互斥：打开时关闭同 group 其他已打开的弹窗（防两层蒙层叠加）
    if (this.show && this.group) {
      SheetManager.closeGroup(this.group, this.sheetId);
    }
    if (!this.isWideScreen()) return;
    if (this.show) this.openWideDialog();
    else this.closeWideDialog();
  }

  private openWideDialog(): void {
    hilog.info(0x0000, 'AppSheet', `openWideDialog dialogId=${this.dialogId}`);
    try {
      promptAction.openCustomDialog({
        builder: () => { this.dialogBody(); },
        alignment: DialogAlignment.Center,
        autoCancel: this.dismissible,
        backgroundColor: Color.Transparent,
        maskColor: '#66000000',
        onWillDismiss: (action) => {
          if (this.dismissible) {
            this.close();
            action.dismiss();
          }
        },
      } as promptAction.CustomDialogOptions).then((id: number) => {
        this.dialogId = id;
      }).catch(() => { this.dialogId = -1; });
    } catch (_) {
      this.dialogId = -1;
    }
  }

  private closeWideDialog(): void {
    if (this.dialogId >= 0) {
      try { promptAction.closeCustomDialog(this.dialogId); } catch (_) {}
      this.dialogId = -1;
    }
  }

  /// 宽屏 dialog 内容：420vp 限宽透明容器——弹窗主体是内容卡片（SheetContainer 自带背景/圆角/阴影），
  /// 不做两层卡片嵌套（外层背景层会让左右/上下边距观感错乱 + 圆角变小）
  @Builder
  dialogBody() {
    Column() {
      this.content()
    }
    .width(420)
  }

  build() {
    // 手机（窄屏）：bindSheet 底部弹窗宿主（1×1 占位，配置集中；宽屏时 show 恒 false 不挂载）
    Stack() {}.width(1).height(1)
      .hitTestBehavior(HitTestMode.Transparent)
      .bindSheet(this.isWideScreen() ? false : this.show, this.sheetBuilder, {
        detents: this.detents,
        // 无 dragBar：拖拽关闭的系统回弹动画无法消除，用户决定去掉拖拽条
        dragBar: false,
        showClose: this.showClose,
        // 背景：实测 blurStyle（COMPONENT/BACKGROUND 均无效果）→ 取消模糊，
        // 恢复不透明主题色背景（稳定纯色弹窗，深色模式不露白）
        // 用 opaqueBackground：colors.background 在自定义背景时是半透明（背景图透出用），
        // 弹窗必须纯色不透明（用户要求），否则透过弹窗看到底层内容
        blurStyle: BlurStyle.NONE,
        backgroundColor: ThemeManager.opaqueBackground,
        shouldDismiss: (sheetDismiss: SheetDismiss) => {
          // dismissible=true：拖拽/蒙层关闭时**外部信号关闭**（show=false 触发 bindSheet
          // 走"状态变化关闭"动画）——系统拖拽关闭动画（松手回弹再滑出）无法消除，
          // 用 show 状态驱动关闭可跳过拖拽回弹
          if (this.dismissible) {
            this.show = false;
            this.onDismiss();
            sheetDismiss.dismiss();
          }
          // dismissible=false 拦截，只由外部信号关闭
        },
        onDisappear: () => {
          // dismissible=true（用户可关）：消失后**延迟同步** show=false——立即设会触发父重建，
          // 可能打断 bindSheet 关闭动画导致"回弹一下才关"。
          // ⚠️ 竞态保护：若延迟期间用户已重新打开弹窗（show=true），**不能再设 false**
          // （否则刚重开的新弹窗被自动关闭——"短时间再次点击就自动关闭"的根因）
          if (this.dismissible) {
            setTimeout(() => {
              if (!this.show) {
                this.show = false;
                this.onDismiss();
              }
            }, 300) as number;
          }
          // dismissible=false（外部信号驱动，如导入进度）：不在此设 show=false——
          // false→true 重开时旧实例的关闭动画也会触发 onDisappear，若覆盖会把父信号误置 false
        },
      })
  }

  @Builder
  sheetBuilder() {
    // 内容包 Scroll：**高度 'auto' 内容自适应**（面板=内容紧凑，任何屏幕）——滚动由
    // SheetContainer 卡片承担（卡片 maxHeight = 窗口高×0.55 统一限制，不判横竖屏）。
    // fadingEdge 上下渐变淡出
    Scroll() {
      this.content()
    }
    .width('100%')
    .height('auto')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .align(Alignment.Top)
    .fadingEdge(true, { fadingEdgeLength: LengthMetrics.vp(24) })
  }

  /// 宽屏判定：平板/二合一按设备类型（竖屏屏宽 vp 可能 <600 会误判成手机）；手机等按屏宽 ≥600vp
  private isWideScreen(): boolean {
    try {
      const t = deviceInfo.deviceType;
      if (t === 'tablet' || t === '2in1') return true;
      return px2vp(display.getDefaultDisplaySync().width) >= 600;
    } catch (_) {
      return false;
    }
  }
}
