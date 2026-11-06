/// 子页面设置分组卡片（GlassCard 同款毛玻璃 + 分组标题）：
/// - 标题在分组上方
/// - 项间分割线由调用方在项之间插入 Divider（Column 无 divider 属性，List 才有）：
///   Divider().strokeWidth(0.5).color(ThemeManager.colors.divider).margin({ left: 12, right: 8 })
/// - 自定义背景时毛玻璃透出背景图，无背景时实色 cardBg
/// 用法：SettingsGroupCard({ title: '分组标题' }) { SettingItem(...) Divider() SettingItem(...) }
/// title 为空则不渲染标题行（如媒体库导入页的无标题分组）
import { ThemeManager } from '../../model/ThemeManager';

@Component
export struct SettingsGroupCard {
  /// 分组标题（空 = 不显示标题行）
  @Prop title: string = '';
  @BuilderParam content: () => void;
  /// 是否有自定义背景（有则毛玻璃，无则实色；与 GlassCard 同款判定）
  @StorageLink('settings_customBgUri') customBgUri: string = '';

  build() {
    Column() {
      if (this.title) {
        Text(this.title)
          .fontSize(13)
          .fontColor(ThemeManager.colors.textSecondary)
          .width('100%')
          .padding({ left: 16, top: 12, bottom: 8 })
      }
      // 项列表（项间分割线由调用方插入 Divider）
      this.content()
    }
    .borderRadius(20)
    .margin({ left: 16, right: 16, top: 12 })
    .backgroundColor(this.customBgUri ? Color.Transparent : ThemeManager.colors.cardBg)
    .backgroundBlurStyle(this.customBgUri ? BlurStyle.COMPONENT_REGULAR : BlurStyle.NONE)
    // 卡片上下留白：无标题 6（缺标题行留白，上下需更大避免紧凑，如媒体库设置页）；
    // 有标题 3（标题行自带 top12/bottom8）；左右统一 1
    .padding({ top: this.title ? 3 : 6, bottom: this.title ? 3 : 6, left: 1, right: 1 })
    .clip(true)
  }
}
