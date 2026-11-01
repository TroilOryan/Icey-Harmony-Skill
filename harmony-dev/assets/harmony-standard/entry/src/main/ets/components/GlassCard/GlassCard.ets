/// 玻璃卡片组件（设置项分组卡片）
/// 三级背景（优先级从高到低）：
///   1. **沉浸光感材质**（有生效壁纸 + API≥26）：`MaterialLayer` 承载层（Toggle 绕过法，
///      内容区 systemMaterial 的唯一合法途径）+ 透明底 + 无模糊
///   2. 有自定义背景但材质不可用：毛玻璃（backgroundBlurStyle COMPONENT_REGULAR）透出底层背景图
///   3. 无自定义背景：实色 cardBg（保证可读）
/// 用法：GlassCard() { 内容 }.margin({...})
/// 复用：AppearanceSettings / MediaLibrarySettings / MediaStatsPage 等子页的分组卡片
/// 材质与实色背景绝不共存，也不能叠 backgroundBlurStyle（材质自带模糊，双层会发灰）
import { ThemeManager } from '../../model/ThemeManager';
import { SettingsManager } from '../../model/SettingsManager';
import { MaterialLayer } from '../MaterialLayer/MaterialLayer';

@Component
export struct GlassCard {
  @BuilderParam content: () => void;
  /// 是否有自定义背景（有则毛玻璃/材质，无则实色）
  @StorageLink('settings_customBgUri') customBgUri: string = '';

  /// 沉浸光感是否接管背景：当前确有生效壁纸 + API≥26
  /// （无壁纸可模糊时材质无意义 → 回落毛玻璃，行为与接入前一致）
  private materialOn(): boolean {
    return this.customBgUri.length > 0 && SettingsManager.materialAvailable();
  }

  build() {
    // Stack 外壳：承载层（画材质）在下，内容在上。承载层用 matchParent 跟随外壳实测尺寸
    Stack() {
      // scope 'menu'：完整挡位阶梯（search 被反色夹薄会抹平挡位差异，见 MaterialLayer 注释）
      MaterialLayer({ layerRadius: 20, scope: 'menu', active: this.materialOn() })
      Column() {
        this.content()
      }
      .width('100%')
      .backgroundColor(this.materialOn() || this.customBgUri ? Color.Transparent : ThemeManager.colors.cardBg)
      .backgroundBlurStyle(this.materialOn() ? BlurStyle.NONE
        : (this.customBgUri ? BlurStyle.COMPONENT_REGULAR : BlurStyle.NONE))
      .borderRadius(20)
      // 卡片上下留白 6（无标题内容卡，缺标题行留白需更大）；左右统一 1
      .padding({ top: 6, bottom: 6, left: 1, right: 1 })
    }
    .borderRadius(20)
    .margin({ left: 16, right: 16, top: 12 })
    .clip(true)
  }
}
