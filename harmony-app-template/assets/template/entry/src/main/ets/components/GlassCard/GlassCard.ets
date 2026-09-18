/// 玻璃卡片组件（设置项分组卡片）
/// 有自定义背景时：毛玻璃（backgroundBlurStyle COMPONENT_REGULAR）透出底层背景图
/// 无自定义背景时：实色 cardBg（保证可读）
/// 用法：GlassCard() { 内容 }.margin({...})
/// 复用：AppearanceSettings / MediaLibrarySettings / Settings 等设置页的分组卡片
import { ThemeManager } from '../../model/ThemeManager';

@Component
export struct GlassCard {
  @BuilderParam content: () => void;
  /// 是否有自定义背景（有则毛玻璃，无则实色）；由调用方传入或自动读 AppStorage
  @StorageLink('settings_customBgUri') customBgUri: string = '';

  build() {
    Column() {
      this.content()
    }
    .borderRadius(20)
    .margin({ left: 16, right: 16, top: 12 })
    .backgroundColor(this.customBgUri ? Color.Transparent : ThemeManager.colors.cardBg)
    .backgroundBlurStyle(this.customBgUri ? BlurStyle.COMPONENT_REGULAR : BlurStyle.NONE)
    // 卡片上下留白 6（无标题内容卡，缺标题行留白需更大）；左右统一 1
    .padding({ top: 6, bottom: 6, left: 1, right: 1 })
    .clip(true)
  }
}
