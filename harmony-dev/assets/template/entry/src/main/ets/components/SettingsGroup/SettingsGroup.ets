/// 设置分组卡片（对齐官方 NavigationSettings 的 SettingsGroup 样式）：
/// 圆角卡片（16）+ 内边距 4 + 项间 Divider（0.5，左缩进 52 对齐图标列）
/// 自定义背景时毛玻璃（与 GlassCard 一致）：卡片透明 + backgroundBlurStyle 透出背景图
/// 用法：SettingsGroup({ entries, onEntryTap })
import { ThemeManager } from '../../model/ThemeManager';
import { SettingItem } from '../SettingItem/SettingItem';

/// 分组条目数据（id 用于回调分发；iconSymbol 不传则不显示图标）
/// iconSymbol 用**官方符号** `$r('sys.symbol.xxx')`（编译期字面量，不能用变量拼接）
export interface SettingsGroupEntry {
  id: string;
  title: string;
  subtitle: string;
  iconSymbol?: Resource;
  iconBg: string;
}

@Component
export struct SettingsGroup {
  @Prop entries: SettingsGroupEntry[] = [];
  /// 当前选中项 id（宽屏左栏菜单高亮用；空 = 无选中）
  @Prop selectedId: string = '';
  /// 点击条目回调（传 id，由父组件分发到对应路由/动作）
  onEntryTap: (id: string) => void = (id: string) => {};
  /// 是否有自定义背景（有则毛玻璃，无则实色 cardBg；与 GlassCard 同款判定）
  @StorageLink('settings_customBgUri') customBgUri: string = '';

  build() {
    Column() {
      ForEach(this.entries, (item: SettingsGroupEntry, index: number) => {
        SettingItem({
          title: item.title,
          subtitle: item.subtitle,
          iconSymbol: item.iconSymbol ?? null,
          iconBg: item.iconBg,
          isSelected: this.selectedId === item.id,
          onTap: () => { this.onEntryTap(item.id); },
        })
        if (index < this.entries.length - 1) {
          Divider()
            .strokeWidth(0.5)
            .color(ThemeManager.colors.divider)
            .margin({ left: 52, right: 8 })
        }
      }, (item: SettingsGroupEntry, index: number) => item.id + index)
    }
    .width('100%')
    // 自定义背景：透明 + 毛玻璃透出背景图；无背景：实色 cardBg（保证可读）
    .backgroundColor(this.customBgUri ? Color.Transparent : ThemeManager.colors.cardBg)
    .backgroundBlurStyle(this.customBgUri ? BlurStyle.COMPONENT_REGULAR : BlurStyle.NONE)
    .borderRadius(20)
    // 左右边距由父容器（ListItem padding）控制——width('100%') + margin 会溢出导致边距不生效
    .margin({ bottom: 16 })
    // 卡片内边距：上下 6、左右 1（2026-08-18 卡片体系统一：圆角 20 / 上下 6 / 左右 1；
    // 无标题卡片缺标题行留白，上下需更大避免紧凑）
    .padding({ top: 6, bottom: 6, left: 1, right: 1 })
  }
}
