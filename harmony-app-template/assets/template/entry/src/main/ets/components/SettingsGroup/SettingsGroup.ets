/// 设置分组卡片（对齐官方 NavigationSettings 的 SettingsGroup 样式）：
/// 圆角卡片（20）+ 内边距 4 + 项间 Divider（0.5，左缩进 52 对齐图标列）
/// 三级背景：沉浸光感材质（有生效壁纸 + API≥26，由 MaterialLayer 承载层绘制）>
/// 自定义背景毛玻璃（与 GlassCard 一致）> 实色 cardBg
/// 用法：SettingsGroup({ entries, onEntryTap })
/// ⚠️ 卡片**内部**的行分隔线一律用 `cardDivider`（比 divider 淡一档）——20% 级的 divider
/// 在玻璃卡片上会显成"一条条白线"（2026-09-13 用户反馈）
import { ThemeManager } from '../../model/ThemeManager';
import { SettingsManager } from '../../model/SettingsManager';
import { MaterialLayer } from '../MaterialLayer/MaterialLayer';
import { SettingItem } from '../SettingItem/SettingItem';

/// 分组条目数据（id 用于回调分发；icon/iconBg 为空则不显示图标）
export interface SettingsGroupEntry {
  id: string;
  title: string;
  subtitle: string;
  icon: string;
  iconBg: string;
}

@Component
export struct SettingsGroup {
  @Prop entries: SettingsGroupEntry[] = [];
  /// 当前选中项 id（宽屏左栏菜单高亮用；空 = 无选中）
  @Prop selectedId: string = '';
  /// 点击条目回调（传 id，由父组件分发到对应路由/动作）
  onEntryTap: (id: string) => void = (id: string) => {};
  /// 是否有自定义背景（有则毛玻璃/材质，无则实色 cardBg；与 GlassCard 同款判定）
  @StorageLink('settings_customBgUri') customBgUri: string = '';

  /// 沉浸光感是否接管背景：当前确有生效壁纸 + API≥26
  private materialOn(): boolean {
    return this.customBgUri.length > 0 && SettingsManager.materialAvailable();
  }

  build() {
    // Stack 外壳：承载层（画材质）在下，内容在上
    Stack() {
      // scope 'menu'：完整挡位阶梯（search 被反色夹薄会抹平挡位差异，见 MaterialLayer 注释）
      MaterialLayer({ layerRadius: 20, scope: 'menu', active: this.materialOn() })
      Column() {
        ForEach(this.entries, (item: SettingsGroupEntry, index: number) => {
          SettingItem({
            title: item.title,
            subtitle: item.subtitle,
            icon: item.icon,
            iconBg: item.iconBg,
            isSelected: this.selectedId === item.id,
            onTap: () => { this.onEntryTap(item.id); },
          })
          if (index < this.entries.length - 1) {
            Divider()
              .strokeWidth(0.5)
              .color(ThemeManager.colors.cardDivider)
              .margin({ left: 52, right: 8 })
          }
        }, (item: SettingsGroupEntry, index: number) => item.id + index)
      }
      .width('100%')
      .backgroundColor(this.materialOn() || this.customBgUri ? Color.Transparent : ThemeManager.colors.cardBg)
      // 材质自带模糊：叠加 backgroundBlurStyle 会发灰，必须 NONE 让位
      .backgroundBlurStyle(this.materialOn() ? BlurStyle.NONE
        : (this.customBgUri ? BlurStyle.COMPONENT_REGULAR : BlurStyle.NONE))
      .borderRadius(20)
      // 卡片内边距：上下 6、左右 1（2026-08-18 卡片体系统一：圆角 20 / 上下 6 / 左右 1；
      // 无标题卡片缺标题行留白，上下需更大避免紧凑）
      .padding({ top: 6, bottom: 6, left: 1, right: 1 })
    }
    .width('100%')
    .borderRadius(20)
    // 左右边距由父容器（ListItem padding）控制——width('100%') + margin 会溢出导致边距不生效
    .margin({ bottom: 16 })
    .clip(true)
  }
}
