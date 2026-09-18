/// 设置项组件（对齐官方 NavigationSettings 的 ListItemView 样式）
/// 左侧图标（**鸿蒙官方符号** SymbolGlyph + 彩色圆角背景）+ 标题/副标题，
/// 右侧 trailing（箭头/开关/值/加载）
/// 高度基准 48（官方 ListItemView 高），带 subtitle 时自适应撑高
/// vipIcon/vipDisabled：会员功能皇冠与置灰（无会员体系可忽略不传）
///
/// 图标一律用**官方符号** `$r('sys.symbol.xxx')`，不自研 SVG 图标组件：
/// 符号随系统字体缩放、随主题自动配色、且零资源维护成本。
/// 符号名可在 `<DevEco>/sdk/default/openharmony/toolchains/id_defined.json` 里检索
/// `"type": "symbol"` 得到（本机 HarmonyOS 6.1.1 / API 24 共 4042 个可选）。
/// ⚠️ `$r('sys.symbol.xxx')` 是**编译期字面量**，不能用变量拼接 → 必须以 Resource 传入。
import { ThemeManager } from '../../model/ThemeManager';
import { AppSwitch } from '../AppSwitch/AppSwitch';

/// #RRGGBB → #AARRGGBB（alpha 0-255）。选中态背景等半透明场景用
function withAlpha(hex: string, alpha: number): string {
  const a = Math.max(0, Math.min(255, Math.round(alpha))).toString(16).padStart(2, '0');
  return hex.startsWith('#') && hex.length === 7 ? `#${a}${hex.substring(1)}` : hex;
}

@Component
export struct SettingItem {
  @Prop title: string = '';
  @Prop subtitle: string = '';
  /// 图标符号（如 `$r('sys.symbol.trash')`）——**编译期字面量**，不能用变量拼；
  /// 不传（null）= 不显示图标（子页面纯文字项）。
  /// 用非装饰成员：图标不会中途变化，无需状态观察（与下方 onTap 回调同一范式）。
  iconSymbol: Resource | null = null;
  @Prop iconBg: string = '#E60012';
  /// 会员功能：标题前显示小皇冠（**始终金色** #E6A23C——禁用样式靠整行透明度降低，图标不变色）
  @Prop vipIcon: boolean = false;
  /// 会员功能：未开通禁用样式（整行 0.45 透明度置灰；点击拦截 TODO 后续实现）
  @Prop vipDisabled: boolean = false;
  @Prop isSwitch: boolean = false;
  @Prop switchValue: boolean = false;
  /// 右侧当前值（label/value 模式，如封面形状"圆形"）；空则不显示
  @Prop value: string = '';
  /// 右侧加载态（如导入中）：显示转圈替代 value/箭头
  @Prop loading: boolean = false;
  /// 是否显示右侧箭头（官方 hasChevron；子页详情项默认 true）
  @Prop hasChevron: boolean = true;
  /// 菜单模式（Menu 下拉项）：右侧显示"值 + 下拉箭头"，点击弹 menu
  /// 注意：bindMenu 不能挂自定义组件外层（点击不生效），必须挂内部原生 Row——故菜单模式在组件内实现
  ///
  /// **配置化而非调用方塞 @Builder**（沿用 SheetContainer 的既有约定）：
  /// 跨组件传 @Builder（`menu: this.xxxMenu`）会丢失 builder 执行时的 this——
  /// builder 体内 `this.xxx()` 在**点击菜单项那一刻**抛 `undefined is not callable`，
  /// 同时 `.selected(this.xxx)` 恒为 false（选中打钩静默失效）。
  /// 2026-09-16 实机案例：「主题模式」菜单闪退（this 被重绑成 SettingItem 实例），
  /// 而同页「沉浸光感材质」菜单不崩——因其 builder 只调用模块级导入的 SettingsManager，不含 this。
  /// 故改为 @Prop 传选项/选中下标 + 普通函数属性传回调，Menu 在本组件内构建。
  @Prop withMenu: boolean = false;
  /// 菜单选项文案（父组件通常传模块级常量数组，引用稳定）
  @Prop menuOptions: string[] = [];
  /// 当前选中项下标（-1 = 无选中）；@Prop 保证父组件状态变更后重渲染
  @Prop menuSelected: number = -1;
  /// 菜单项点击回调（普通函数属性，回调内 this 指向父组件，行为正常）
  onMenuPick: (index: number) => void = (index: number) => {};
  /// 选中态（一多宽屏左栏菜单用）：选中项半透明主题色高亮（对齐官方 color_background_selected）
  @Prop isSelected: boolean = false;
  onTap: () => void = () => {};
  onSwitch: (v: boolean) => void = () => {};

  /// 空菜单默认值（非菜单模式不弹菜单）
  @Builder
  private emptyMenu() {}

  /// 菜单内容：由 menuOptions / menuSelected 在本组件内配置化构建
  /// 选中态与点击回调都在本组件内解析，父组件只提供数据 + 回调，不传 @Builder
  @Builder
  private menuBuilder() {
    Menu() {
      ForEach(this.menuOptions, (opt: string, idx: number) => {
        MenuItem({ content: opt })
          .selected(this.menuSelected === idx)
          .onChange(() => {
            this.onMenuPick(idx);
          })
      }, (opt: string, idx: number) => `${idx}-${opt}`)
    }
  }

  /// 会员皇冠色：**始终金色**（禁用靠整行 opacity 降低，图标颜色不变）
  private vipColor(): ResourceColor {
    return '#E6A23C';
  }

  build() {
    Row() {
      // 左侧图标（官方符号，白色，置于圆形彩色底上）；未传 iconSymbol 则不显示（子页面纯文字项）
      // 圆形：borderRadius = 宽高一半（对齐官方设置列表圆形图标风格）
      if (this.iconSymbol !== null) {
        Stack() {
          SymbolGlyph(this.iconSymbol)
            .fontSize(16)
            .fontColor(['#FFFFFF'])
        }
        .width(32)
        .height(32)
        .borderRadius(16)
        .backgroundColor(this.iconBg)
        .alignContent(Alignment.Center)
        .margin({ right: 12 })
      }

      // 标题（会员功能前缀小皇冠，图标与标题一行）+ 副标题
      Column() {
        Row({ space: 5 }) {
          if (this.vipIcon) {
            SymbolGlyph($r('sys.symbol.crown'))
              .fontSize(15)
              .fontColor([this.vipColor()])
          }
          Text(this.title)
            .fontSize(16)
            .fontColor(ThemeManager.colors.textPrimary)
            .fontWeight(FontWeight.Medium)
        }
        .alignItems(VerticalAlign.Center)
        if (this.subtitle) {
          Text(this.subtitle)
            .fontSize(12)
            .fontColor(ThemeManager.colors.textSecondary)
            .margin({ top: 2 })
            // 描述允许两行，超长才省略（设置项文案较长时避免一行挤爆）
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 右侧
      if (this.isSwitch) {
        // 统一开关组件（系统 Toggle 滑块渲染偏移/溢出轨道，改自绘 AppSwitch）
        // 未开通会员：只读（显示当前值但不可切换，2026-08-16 真实拦截）
        AppSwitch({
          isOn: this.switchValue,
          onToggle: (v: boolean) => {
            if (this.vipDisabled) return;
            this.onSwitch(v);
          },
        })
      } else if (this.loading) {
        // 加载态（如导入中）：右侧转圈反馈，替代 value/箭头
        LoadingProgress()
          .width(18).height(18)
          .color(ThemeManager.colors.textSecondary)
          .margin({ right: 6 })
      } else if (this.value) {
        if (this.withMenu) {
          // 菜单模式：当前值 + 下拉箭头（点击锚点），bindMenu 挂原生 Row（挂自定义组件外层不弹）
          // 未开通会员：不绑菜单（点击无反应，真实拦截）
          Row({ space: 4 }) {
            Text(this.value)
              .fontSize(14)
              .fontColor(ThemeManager.colors.textSecondary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            SymbolGlyph($r('sys.symbol.arrowtriangle_down_fill'))
              .fontSize(12)
              .fontColor([ThemeManager.colors.textSecondary])
          }
          .padding({ left: 8, top: 6, bottom: 6 })
          .bindMenu(this.vipDisabled ? this.emptyMenu : this.menuBuilder)
        } else {
          // label/value 模式：显示当前值（点击弹窗选择），无箭头
          Text(this.value)
            .fontSize(14)
            .fontColor(ThemeManager.colors.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ right: 4 })
        }
      } else if (this.hasChevron) {
        // 箭头：官方 chevron_right symbol（替代原 '>' 文本）
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(24)
          .fontColor([ThemeManager.colors.textSecondary])
      }
    }
    .width('100%')
    // 高度基准 48（官方 ListItemView），带 subtitle 时自动撑高，不被固定高度裁剪
    .constraintSize({ minHeight: 48 })
    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
    .borderRadius(12)
    // 选中态：半透明主题色背景（alpha 60 ≈ 24%）
    .backgroundColor(this.isSelected
      ? withAlpha(ThemeManager.colors.accent, 60)
      : Color.Transparent)
    // 未开通会员禁用样式（整行置灰）；2026-08-16 真实拦截（不再仅样式）
    .opacity(this.vipDisabled ? 0.45 : 1)
    .onClick(() => {
      if (this.vipDisabled) return; // 未开通会员：点击拦截
      if (!this.isSwitch) this.onTap();
    })
  }
}
