/// 通用底部弹窗容器（bindSheet 内容用）
/// 参照 AppearanceSettings 的 coverSheetBuilder 样式：标题居中 + 卡片包裹内容 + 背景同页面
/// 用 @BuilderParam content 传弹窗内容（卡片内的选项/进度等）
/// 用法：bindSheet(this.show, this.sheetBuilder, {...})，sheetBuilder 里 <SheetContainer title='...'>{ 内容 }</SheetContainer>
/// 2026-08-13 新增 plain 无卡片模式：内容区不套 cardBg 卡片（背景透明 + 24 外边距），
/// 由调用方自己管理卡片布局（多卡片弹窗如 AddMediaSheet 搜索卡+列表卡分开时用）
import { ThemeManager } from '../../model/ThemeManager';
import { LengthMetrics } from '@kit.ArkUI';

@Component
export struct SheetContainer {
  @Prop title: string = '';
  /// 标题右侧附加文本（2026-08-28 更新日志用：版本号 v1.0.1 放标题旁边，次级色同行）。
  /// 空串不显示——不影响其他弹窗
  @Prop titleExt: string = '';
  /// 无卡片模式：内容区不套 cardBg 卡片，调用方自管卡片（多卡片弹窗）
  @Prop plain: boolean = false;
  /// 标题行右侧编辑按钮（2026-09-03 媒体信息用）——**配置化而非调用方塞组件**：
  /// ArkUI 尾随 lambda 只允许一个 @BuilderParam（加第二个 @BuilderParam 会让全部
  /// 调用点编译报错），所以按钮画在容器内、用 @Prop 开关控制。
  /// 位置在宿主系统关闭按钮**左侧**（margin right 留出系统按钮空间），不替代/不关闭系统按钮
  @Prop titleEditIcon: boolean = false;
  onTitleEdit: () => void = () => {};
  /// 窗口横竖屏（Index 广播）——**竖屏按以前方案 / 横屏按现在方案（2026-08-21 定案）**：
  /// 竖屏（含阔折叠展开，宽高接近判竖屏）：卡片**不限高**，内容自适应紧凑（Scroll auto
  /// 不撑满——曾因 Scroll '100%' + maxHeight 限制把内容少的弹窗撑到 440vp 高）；
  /// 横屏（短边≈360）：卡片限高 → 卡片内 Scroll 滚动看全。
  @StorageLink('windowIsLandscape') windowIsLandscape: boolean = false;
  /// 窗口高度（vp，Index 广播）——横屏卡片限高基准
  @StorageLink('windowHeight') windowHeight: number = 0;
  @BuilderParam content: () => void;

  /// 卡片最大高度（vp）：
  /// 横屏 = 窗口高×0.55（360→198，卡片内 Scroll 滚动看全）；
  /// 竖屏 = 窗口高×0.75（2026-08-21 修复：原 10000 不限高 → 内容超出屏幕时卡片被撑高、
  /// Scroll 'auto' 无可滚空间 → 看不到也滚不动。限高后 Scroll 高度被钳制 → 内容多可滚动；
  /// 内容少时 Scroll 'auto' 仍自适应紧凑，不撑满）
  private cardMaxHeight(): number {
    const h = this.windowHeight > 0 ? this.windowHeight : 600;
    const ratio = this.windowIsLandscape ? 0.55 : 0.75;
    return Math.max(h * ratio, 180);
  }

  build() {
    Column() {
      // 标题（字号对齐应用标题栏 20）——左上角对齐（left 24 与卡片 margin 对齐）；
      // 负 margin 上移（dragBar 保留在顶部，标题行上移到与右上关闭按钮同一水平线垂直居中）
      // titleExt（版本号等）紧跟标题右侧，次级色 + 与标题间空格；
      // titleEditIcon：编辑按钮推到行最右（系统关闭按钮左侧——margin right 避让，不重叠）
      Row() {
        Text(this.title)
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeManager.colors.textPrimary)
        if (this.titleExt.length > 0) {
          Text(' ' + this.titleExt)
            .fontSize(13)
            .fontColor(ThemeManager.colors.textSecondary)
            .margin({ left: 4 })
        }
        if (this.titleEditIcon) {
          Blank()
          Row() {
            SymbolGlyph($r('sys.symbol.square_and_pencil'))
              .fontSize(14)
              .fontColor([ThemeManager.colors.textPrimary])
          }
          .width(30)
          .height(30)
          .borderRadius(15)
          .backgroundColor(ThemeManager.isDark ? '#262626' : '#F0F0F0')
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          // 避让宿主系统关闭按钮（bindSheet 圆底关闭约 48vp 区域，dialog 无关闭留 8）
          .margin({ right: 40 })
          .onClick(() => { this.onTitleEdit(); })
        }
      }
      .width('100%')
      .height(48)
      .padding({ left: 24, right: 24, top: 0, bottom: 0 })
      .margin({ top: 16 })
      .alignItems(VerticalAlign.Center)

      if (this.plain) {
        // 无卡片模式：透明内容区（24 外边距统一），卡片由调用方自管
        Column() {
          this.content()
        }
        .width('100%')
        .padding({ left: 24, right: 24 })
        .margin({ top: 24, bottom: 24 })
      } else {
        // 内容卡片（四周 24 外边距统一 + 4 内边距，圆角 16）——弹窗主体（不加阴影）
        // **卡片 = 滚动区域**：横屏限高 → 卡片内 Scroll '100%' 受限滚动看全；
        // 竖屏不限高 → Scroll 'auto' 内容自适应紧凑（'100%' 引用未定高度会撑满 maxHeight，
        // 竖屏内容少弹窗过高的根因）。fadingEdge 上下渐变淡出，内容顶对齐
        Column() {
          Scroll() {
            this.content()
          }
          .width('100%')
          .height(this.windowIsLandscape ? '100%' : 'auto')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.None)
          // 内容顶对齐（卡片受限撑满时防止内容垂直居中）
          .align(Alignment.Top)
          .fadingEdge(true, { fadingEdgeLength: LengthMetrics.vp(24) })
        }
        .backgroundColor(ThemeManager.colors.cardBg)
        .borderRadius(16)
        .border({ width: 0.5, color: ThemeManager.colors.divider })
        .padding(4)
        .margin({ left: 24, right: 24, top: 24, bottom: 24 })
        // 卡片 maxHeight：横屏受限（滚动）/ 竖屏不限制（内容自适应）
        .constraintSize({ maxHeight: this.cardMaxHeight() })
      }
    }
    .width('100%')
    // 根高度=内容（不撑满）：竖屏面板=内容紧凑
    .backgroundColor(Color.Transparent)
  }
}
