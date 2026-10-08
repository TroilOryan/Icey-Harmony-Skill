/// 子页面设置分组卡片（GlassCard 同款毛玻璃 + 分组标题）：
/// - **标题在「卡片外面」**（2026-10-07 用户定案，参考系统「设置」页）：
///   结构 = `Column{ 标题; Stack(材质层 + 内容) }`，标题左缘与卡片左缘对齐。
///   ⚠️ 旧版标题画在**卡片内**顶部（`left:12` 对齐 SettingItem 行内距）——
///   那是"卡内"的定位基准，移到卡外后必须改成 0，否则标题比卡片右移 12、两边不齐。
///   ✅ 调用点零改动：`title` 语义不变。
/// - 左右 16 **用 `padding` 承载**（2026-10-07 修横向溢出）：根节点是 `.width('100%')` 的
///   `Column`，再配横向 `margin` 会溢出 32vp（铁律：`width('100%')` + 横向 margin = 溢出）；
///   纵向卡间距用 `margin({top:16})`（纵向无此问题，且 margin 更贴合"与上方的距离"语义）。
///   ⚠️ **横向内距由本组件自带**（对照：主页 `SettingsGroup` 是**靠父容器** padding 控制）
///   ⇒ **调用点不要再套左右 padding**，否则与本组件的 16 叠加成双倍内缩。
///   15 个调用点已核验：父容器均无左右 padding（2026-10-07 `grep` 全扫）。
/// - 项间分割线由调用方在项之间插入 Divider（Column 无 divider 属性，List 才有）：
///   Divider().strokeWidth(0.5).color(ThemeManager.colors.cardDivider).margin({ left: 12, right: 8 })
///   ⚠️ 卡片**内部**的行分隔线一律用比 `divider` 淡一档的 `cardDivider`——卡片底是半透明
///   材质/毛玻璃，20% 级的 divider 会"一条条白线压在玻璃上"（2026-09-13 用户反馈）
///   ⚠️ **只在项与项之间插**：分组最后一项之后严禁再插 Divider —— 卡片底部留白仅 3vp
///   （+末项自身 6vp），尾部多余的分割线会紧贴卡片圆角下边缘，视觉极不协调。
///   （2026-09-11 用户反馈「播放界面」分组尾部遗留分割线后定案）
/// - 三级背景：沉浸光感材质（有壁纸 + API≥26）> 自定义背景毛玻璃 > 实色 cardBg
/// - **卡间距 = 16vp，与设置主页 `SettingsGroup` 的 `.margin({bottom:16})` 严格一致**
///   （2026-10-06 定案：原先本组件 `top:12` ⇒ 卡间距 12，比主页窄 4vp，来回切换可见"挤了一下"）
/// - **卡片内边距 = 上下 6 / 左右 1**，同样与 `SettingsGroup` 恒定值一致
///   （2026-10-06 第二轮定案：原先按有无标题分档 3/6，有标题时比主页窄 3vp）
/// - **项间分割线左缩进两边不同且都是对的**：主页 `left:52`（项带图标 12+32+8 对齐文字列）、
///   子页 `left:12`（项无图标）。⚠️ 这是**唯一允许两边不同**的间距，改动前先确认目标页项有无图标。
/// 用法：SettingsGroupCard({ title: '分组标题' }) { SettingItem(...) Divider() SettingItem(...) }
/// title 为空则不渲染标题行（如媒体库导入页的无标题分组）
import { ThemeManager } from '../../model/ThemeManager';
import { SettingsManager } from '../../model/SettingsManager';
import { MaterialLayer } from '../MaterialLayer/MaterialLayer';

@Component
export struct SettingsGroupCard {
  /// 分组标题（空 = 不显示标题行）
  @Prop title: string = '';
  @BuilderParam content: () => void;
  /// 是否有自定义背景（有则毛玻璃/材质，无则实色）
  @StorageLink('settings_customBgUri') customBgUri: string = '';

  /// 沉浸光感是否接管背景：当前确有生效壁纸 + API≥26
  private materialOn(): boolean {
    return this.customBgUri.length > 0 && SettingsManager.materialAvailable();
  }

  build() {
    // **2026-10-07 用户要求：分组小标题移到「卡片外面」**（参考系统「设置/蓝牙」页风格）。
    //
    // 结构由 `Stack{ 材质层; Column{ 标题; 内容 } }` 改为
    // **`Column{ 标题; Stack{ 材质层; 内容 } }`** —— 标题不再属于卡片，而是卡片上方的独立行。
    // ✅ **调用点零改动**：`title` 的语义不变（16 个调用点、其中 1 处传空串不渲染标题）。
    //
    // ⚠️ 标题**左缘对齐卡片左缘**（不再用旧的 `left: 12`）：
    //   标题在卡片外时，卡片左缘 = 本组件根 Column 的内容左缘；
    //   若仍留 12，标题会比卡片右移 12、两边不齐（旧值 12 是"卡片内对齐 SettingItem 行内距"的口径，
    //   那是**卡内**的定位基准，移到卡外即失效）。
    //   ⇒ 卡片内的项文字左缘 = 卡片左缘 + 卡片 padding(1) + 项 padding(12)，
    //     标题在**卡片左缘**，与系统「设置」页的层级关系一致。
    Column() {
      if (this.title) {
        Text(this.title)
          .fontSize(13)
          .fontColor(ThemeManager.colors.textSecondary)
          .width('100%')
          // 顶部不留（与上方卡片已由外层 `margin top: 16` 隔开）；底部 8 = 标题与卡片的呼吸
          .padding({ left: 0, right: 0, top: 0, bottom: 8 })
      }

      // Stack 外壳：承载层（画材质）在下，内容在上
      Stack() {
        // scope 'menu'：完整挡位阶梯（search 被反色夹薄会抹平挡位差异，见 MaterialLayer 注释）
        MaterialLayer({ layerRadius: 20, scope: 'menu', active: this.materialOn() })
        Column() {
          // 项列表（项间分割线由调用方插入 Divider）
          this.content()
        }
        .width('100%')
        .backgroundColor(this.materialOn() || this.customBgUri ? Color.Transparent : ThemeManager.colors.cardBg)
        // 材质自带模糊：叠加 backgroundBlurStyle 会发灰，必须 NONE 让位
        .backgroundBlurStyle(this.materialOn() ? BlurStyle.NONE
          : (this.customBgUri ? BlurStyle.COMPONENT_REGULAR : BlurStyle.NONE))
        .borderRadius(20)
        // ⚠️ **卡片内边距必须与设置主页 `SettingsGroup` 一致 = 上下 6 / 左右 1**
        //   （2026-10-06 第二轮对齐）。标题已移出卡片 ⇒ 本值**不再受标题有无影响**，
        //   恒定 6/6/1/1。
        .padding({ top: 6, bottom: 6, left: 1, right: 1 })
      }
      .width('100%')
      .borderRadius(20)
      .clip(true)
    }
    .width('100%')
    // ⚠️⚠️ **左右 16 必须用 `padding`，不能用 `margin`**（2026-10-07 修横向溢出）：
    //   本轮把根节点从 `Stack`（**原本没有** `.width('100%')`，宽度靠自适应 ⇒ margin 之外仍等于
    //   父宽−32）换成 `Column` 并加了 `.width('100%')` ⇒ 此时再配 `margin({left:16,right:16})`
    //   **必然溢出**：真宽 = 100% + 32 > 父宽，卡片左右各出界 16vp。
    //   这正是本项目铁律「**`width('100%')` + 横向 `margin` 同时用 ⇒ 溢出**」的原样复现
    //   （`SheetContainer` 文件头同款结论）。
    //   ⇒ 横向改用 `padding`：padding 在**尺寸内层**（ArkUI `width` 是 border-box 语义）
    //     ⇒ 内容区 = 父宽 − 32，卡片自身仍 100% ⇒ **不溢出**。
    //   ⚠️ 判据：**要"收一点边"改 `padding`，不要改 `margin`**（padding 不溢出、不偏移）。
    .padding({ left: 16, right: 16 })
    // ⚠️ **卡间距必须与设置主页的 `SettingsGroup` 一致 = 16vp**（2026-10-06）：
    //   主页 `SettingsGroup.ets` 是 `.margin({ bottom: 16 })`。
    //   本组件的 `top: 16` 现在同时充当「上一张卡 → 本组标题」的间距
    //   （标题已移出卡片，外表看是"卡片间距"的一部分）。
    //   ⚠️ 纵向间距用 `margin` 是**对的**（纵向不存在"100% 溢出"问题，且 margin 更贴合
    //      "与上方元素的距离"语义）——横向才必须改用 padding。
    .margin({ top: 16 })
  }
}
