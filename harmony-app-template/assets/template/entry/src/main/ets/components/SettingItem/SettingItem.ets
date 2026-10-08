/// 设置项组件（对齐官方 NavigationSettings 的 ListItemView 样式）
/// 左侧图标（SFIcon SVG，彩色圆角背景）+ 标题/副标题，右侧 trailing（箭头/开关/值/加载）
/// 高度基准 48（官方 ListItemView 高），带 subtitle 时自适应撑高
/// 会员功能：vipIcon=true 时标题前加小皇冠（已开通金色/未开通灰），vipDisabled=true 整行置灰禁用样式
import { ThemeManager } from '../../model/ThemeManager';
import { SettingsManager } from '../../model/SettingsManager';
import { SFIcon, SFIcons } from '../SFIcon/SFIcon';

/// 给 #RRGGBB 加透明度（alpha 0~255）→ #AARRGGBB
/// 内联而非引 CoverColorExtractor：那份实现依赖本项目没有的 Media 模型（封面取色专用），
/// 仅为这一处 60/255 的透明度不值得引入 541 行依赖。
function withAlpha(hex: string, alpha: number): string {
  if (hex.length < 7) return hex;
  const a = Math.max(0, Math.min(255, Math.floor(alpha))).toString(16).padStart(2, '0');
  return `#${a}${hex.substring(1)}`;
}

@Component
export struct SettingItem {
  @Prop title: string = '';
  @Prop subtitle: string = '';
  /// 副标题最大行数（默认 2；声明类长文案放宽，如媒体库权限说明）
  @Prop subtitleLines: number = 2;
  /// 图标资源名（SFIcons.sf_xxx，对应 SVG 文件）；子页面项不传图标
  @Prop icon: string = '';
  @Prop iconBg: string = '#E60012';
  /// 会员功能：标题前显示小皇冠（**始终金色** #E6A23C——禁用样式靠整行透明度降低，图标不变色）
  @Prop vipIcon: boolean = false;
  /// 会员功能：未开通禁用样式（整行 0.45 透明度置灰；点击拦截 TODO 后续实现）
  @Prop vipDisabled: boolean = false;
  /// 只读声明项（2026-09-15 媒体库权限说明）：不可点击但**不置灰**（置灰=禁用，只读≠禁用）
  @Prop isReadonly: boolean = false;
  /// **通用禁用**（2026-10-02 第十三轮新增）：整行置灰 + **完全退出命中测试** + 菜单不弹。
  /// 与 `vipDisabled`（会员语义，带皇冠/引导）区分：本字段是"**条件性不可用**"的通用表达，
  /// 无会员语义、不引导。首个消费方 = 「样式二下禁用封面形状」（`CoverShapePicker`）。
  /// ⚠️ 用手法同 `vipDisabled`：`.hitTestBehavior(HitTestMode.None)`（节点**及子树**退出命中）
  ///   + 行 onClick 提前 return + `.opacity(0.45)`。
  ///   只在 onChange/onClick 里 return 挡不住——**子组件（Toggle/菜单锚点）的内部态已翻转**，
  ///   而父组件不重渲染 ⇒ 停在错误的视觉态（Toggle 那条踩坑的通用形态）。
  @Prop disabled: boolean = false;
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
  @Prop withMenu: boolean = false;
  /// 菜单 Builder（withMenu 时必传，如 this.xxxMenu）
  /// 默认值必须是 @Builder 函数（ArkTS 限制：@BuilderParam 只能用 @Builder/@LocalBuilder 初始化）
  @BuilderParam menu: () => void = this.emptyMenu;
  /// 选中态（一多宽屏左栏菜单用）：选中项半透明主题色高亮（对齐官方 color_background_selected）
  @Prop isSelected: boolean = false;
  onTap: () => void = () => {};
  onSwitch: (v: boolean) => void = () => {};

  /// 空菜单默认值（非菜单模式不弹菜单）
  /// ⚠️ **`@Builder` 绝不能带访问修饰符**（2026-10-08 实测）：写 `private emptyMenu()` 会让
  ///   解析器在装饰器行直接中断（首个错误报 `Identifier expected`，随后文件后半段连锁爆出
  ///   几十条 `';' expected` / `':' expected` 假语法错），排查成本极高。
  ///   对比：普通成员函数 `private vipColor()` 带 private 完全合法，只有 `@Builder` 不行。
  @Builder
  emptyMenu() {}

  /// 会员皇冠色：**始终金色**（禁用靠整行 opacity 降低，图标颜色不变）
  /// 统一取 ThemeManager.vipGold——与海报菜单皇冠同一色（2026-09-08 统一 VIP 标识）
  private vipColor(): ResourceColor {
    return ThemeManager.vipGold;
  }

  build() {
    Row() {
      // 左侧图标（SFIcon 在圆形彩色背景上，白色图标）；icon 为空则不显示（子页面项无图标）
      // 圆形：borderRadius = 宽高一半（对齐官方设置列表圆形图标风格）
      if (this.icon) {
        Stack() {
          SFIcon({ name: this.icon, fontSize: 16, fontColor: '#FFFFFF' })
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
            SFIcon({ name: SFIcons.sf_crown, fontSize: 15, fontColor: this.vipColor() })
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
            // 描述行数可配（超长才省略）——默认 2 行，声明类长文案放宽
            .maxLines(this.subtitleLines)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 右侧
      if (this.isSwitch) {
        // **官方 Toggle 组件（2026-09-09 用户定案）**：AppSwitch 自绘版退役——
        // 当年替换原因（Toggle 滑块渲染偏移/溢出轨道）在当前 SDK 已不复现。
        // 样式：ToggleType.Switch（胶囊滑块开关，iOS 同款）+ selectedColor 主题色；
        // 未开通会员：只读（显示当前值但不可切换，2026-08-16 真实拦截）
        Toggle({ type: ToggleType.Switch, isOn: this.switchValue })
          .selectedColor(ThemeManager.colors.accent)
          // **未开通会员：整棵 Toggle 退出命中测试**（2026-10-02 修复用户报
          // 「没有开启会员的情况下 会员功能的开关是可以被切换打开的」）
          // ⚠️ 旧版只在 onChange 里 `return` —— 挡不住：Toggle 的**内部态已经翻转**，
          //    而 `isOn` 绑的是 @Prop `switchValue`（值没变）→ 父组件不重渲染、
          //    @Prop 不回写 → 开关停在"已打开"的错误视觉（且没有对应功能实现）。
          //    HitTestMode.None = 节点**及其子树**都不参与命中测试（Transparent 只穿透
          //    自身、内部滑块仍会吃到触摸）→ 触摸落到父行，行 onClick 对 vipDisabled
          //    已提前 return，等效"完全点不动"。视觉仍由下方 opacity 置灰，无观感变化。
          .hitTestBehavior(this.vipDisabled ? HitTestMode.None : HitTestMode.Default)
          .onChange((isOn: boolean) => {
            if (this.vipDisabled) { return; }
            this.onSwitch(isOn);
          })
          .opacity(this.vipDisabled ? 0.45 : 1)
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
          // 沉浸光感（2026-09-08）：菜单走 MenuOptions.systemMaterial，跟随全局挡位
          // ⚠️ API 26 坑：传 systemMaterial 后菜单走 system-styled 渲染路径，未显式设置
          // placement 时锚定退化为默认位置（不按绑定组件 BottomLeft 锚定，2026-09-08 真机回归：
          // 菜单"在前面出现"而不是点击位置）→ 必须显式 placement 修复锚定
          .bindMenu(this.vipDisabled || this.disabled ? this.emptyMenu : this.menu,
            { placement: Placement.BottomLeft, systemMaterial: SettingsManager.materialFor('menu') })
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
    .opacity(this.vipDisabled || this.disabled ? 0.45 : 1)
    // 通用禁用：整行（含子树）退出命中测试——比"只在 onClick return"可靠（子组件内部态不会翻转）
    .hitTestBehavior(this.disabled ? HitTestMode.None : HitTestMode.Default)
    .onClick(() => {
      if (this.vipDisabled || this.isReadonly || this.disabled) return; // 会员未开通/只读声明/通用禁用：点击拦截
      if (!this.isSwitch) this.onTap();
    })
  }
}
