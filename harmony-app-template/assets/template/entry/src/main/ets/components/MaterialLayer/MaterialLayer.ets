/// **沉浸光感承载层（MaterialLayer）—— Toggle 绕过法**
///
/// 为什么需要它：`systemMaterial` / `uiMaterial.ImmersiveMaterial`（API 26+）**不是通用属性**。
/// 官方把组件分成两类，只有
///   ① **按钮与选择类**（Button / Select / Toggle / Slider / ChipGroup / SegmentButton）→ 页面内**任意区域**生效
///   ② 其余组件（Column / Row / Text / Image…）→ 只在 Navigation/NavDestination 标题栏
///      或 `barPosition = BarPosition.End` 的横向 TabBar 内生效
/// 内容区里给 Column 直接挂材质 → 日志 `Material inactive: out of scope`，**静默失效**（不报错）。
///
/// 绕过原理：用一个 `ToggleType.Button` 当"看不见的画布"去画材质，内容作为**兄弟节点叠在它之上**。
/// Toggle 属于第 ① 类，任意位置可用。（普通 `Button` 官方也支持，但真机实测不渲染，
/// 同尺寸 `ToggleType.Button` 正常 —— 故一律只走 Toggle。）
///
/// 用法（放进 Stack，承载层在前、内容在后）：
/// ```
/// Stack() {
///   if (this.materialOn()) {
///     MaterialLayer({ layerRadius: 20 })
///   }
///   Column() { /* 内容 */ }
/// }
/// ```
///
/// 五条硬约束（少一条材质就画不出来/出问题，摘自 Downloads/1.md）：
///   ① `LayoutPolicy.matchParent`：不能用 `width('100%')` —— Stack 子节点的百分比按**父级可用尺寸**
///      解析，会把卡片撑大；matchParent 按父级**实测尺寸**解析，随内容走
///   ② `borderRadius` 必须与外壳一致，否则 Toggle 自带的按钮图形（小圆角+描边）会内嵌出来
///   ③ `backgroundColor(Color.Transparent)`：材质视觉层级在 backgroundColor **之下**，
///      任何不透明底色都会把它盖死
///   ④ `enabled(false)` + `focusable(false)` + `accessibilityLevel('no')` + `hitTestBehavior(None)`：
///      承载层只是画布，不能抢焦点/点击/无障碍朗读
///   ⑤ `systemMaterial` 必须放在**所有样式属性之后**（材质不采样同 Stack 的兄弟节点，
///      且会被后设的 border/shadow 覆盖）
///
/// ⚠️ API<26：`SettingsManager.materialFor()` 返回 undefined（属性忽略，不崩）；
/// 调用方以 `materialOn()` 直接不渲染本层，卡片走毛玻璃/实色兜底。
import { SettingsManager } from '../../model/SettingsManager';
import uiMaterial from '@ohos.arkui.uiMaterial';

@Component
export struct MaterialLayer {
  /// 圆角：**必须与外壳卡片一致**，否则卡片四角会露出材质自己的小圆角
  @Prop layerRadius: number = 20;
  /// 是否渲染（false = 无壁纸/低版本 → 直接不画，卡片走兜底色）
  @Prop active: boolean = true;
  /// 材质档位场景：'search'（薄，卡片/浮动工具）| 'menu'（厚，菜单/小按钮）| 'sheet'（最厚，弹窗）。
  /// ⚠️ 用 string 而非 `MaterialScope` 联合类型——ArkTS 的 @Prop 不接受字符串字面量联合类型
  /// ⚠️ **默认 'search' 是坑（2026-09-24 全局审计定案）**：search 档会被「光感自动反色」
  /// 夹薄 → 挡位差异被抹平（调强/调弱无感）。**卡片类调用必须显式传 'menu'**（设置卡片
  /// 体系既定档）；浮在列表内容上的小组件传 'system'（对齐 Hds 底栏）。当前全部调用点
  /// 已显式传 scope，新增调用点勿漏
  @Prop scope: string = 'search';
  /// **封面色调（可选，2026-09-15 保存按钮光感优化）**：非空时材质用该主色半透明着色，
  /// 取代系统深浅着色（systemMaterialColor），让光感底色跟随封面（页面主色调）。
  /// 调用方配 `textColorOnBackground(该色)` 的文字色（浅底深字/深底浅字）。
  @Prop tintColor: string = '';
  /// **沉浸光感挡位（2026-09-24 改实时跟随）**：订阅挡位，变化时**销毁重建承载 Toggle**
  /// （ForEach key 重建）——systemMaterial 换新材质对象挂同一节点不重应用（09-15 实时
  /// 重建失败的根因），节点重建是唯一可靠手法（与 MiniBarCollapsedCover 封面 key 重建
  /// 同模式）。硬重启已随之移除：底栏（@StorageLink 直传）本就实时，卡片实时后全局一致
  @StorageLink('settings_materialLevel') materialLevel: number = 10;

  /// 实际材质对象（档位/着色与搜索框同源，见 SettingsManager.materialFor）
  private layerMaterial(): uiMaterial.ImmersiveMaterial | undefined {
    if (this.tintColor.length >= 7) {
      // 封面色调模式：材质着 user 封面主色（半透明显色），关闭自动反色（文字色由调用方按亮度自控）
      return SettingsManager.materialTinted('menu', this.tintColor);
    }
    // **自适应挡 = 跟随系统策略（2026-09-24 二次修正）**：官方《组件适配沉浸光感》系统策略
    // 默认档——Navigation 标题栏 = ULTRA_THIN(0)。此前"系统裸材质"实际落在 ImmersiveOptions
    // 默认 REGULAR(2)，比标题栏厚两档，用户实测"自适应卡片明显比标题栏更不透明"即此根因
    // → 显式取 ULTRA_THIN 对齐标题栏观感
    if (this.materialLevel === 10) {
      return SettingsManager.materialSystem(0);
    }
    // 'system'：跟随系统策略的裸材质（无场景档位、无着色）
    if (this.scope === 'system') {
      return SettingsManager.materialFor('system');
    }
    if (this.scope === 'menu') {
      return SettingsManager.materialFor('menu');
    }
    if (this.scope === 'sheet') {
      return SettingsManager.materialFor('sheet');
    }
    return SettingsManager.materialFor('search');
  }

  build() {
    // ForEach key = 挡位：挡位变化 → 旧 Toggle 销毁、新 Toggle 全新挂载（材质必然重应用）。
    // ⚠️ 不能只靠 build 重跑换材质对象——systemMaterial 属性对同节点换对象不重应用
    ForEach([this.materialLevel], (lv: number) => {
      if (this.active) {
        Toggle({ type: ToggleType.Button, isOn: false })
          // ① 跟随父级实测尺寸（百分比会把卡片撑大）
          .width(LayoutPolicy.matchParent)
          .height(LayoutPolicy.matchParent)
          // ② 圆角与外壳一致
          .borderRadius(this.layerRadius)
          .padding(0)
          // ③ 必须显式透明：不透明底色会盖在材质之上
          .backgroundColor(Color.Transparent)
          // ④ 只当画布：不参与交互/焦点/无障碍
          .enabled(false)
          .focusable(false)
          .accessibilityLevel('no')
          .hitTestBehavior(HitTestMode.None)
          // ⑤ 材质放最后
          .systemMaterial(this.layerMaterial())
      }
    }, (lv: number) => `mlv-${lv}-${this.active ? 1 : 0}`)
  }
}
