/// 子页标题栏配置 helper（普通函数，非 @Builder，避开 @Builder 闭包 this 绑定陷阱）
/// 复用首页的 scrollEffect(滚动模糊) + 材质 + 安全区避让配置，menu 传 [] 子页无菜单按钮。
/// HdsNavigationTitleBarOptions 与 HdsNavigation.titleBar 同类型，HdsNavDestination.titleBar 也用它。
/// 注意：Hds 枚举曾用数值字面量（release 无导出闪退——实为测试机 API 低于 @since）；
/// 2026-08-21 改回枚举（ScrollEffectType/hdsMaterial），兼容下限 6.1.0(23) 正常导出。
import { HdsNavigationTitleBarOptions, HdsNavigationMenuItemOptions, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';
import { ThemeManager } from './ThemeManager';
import { SettingsManager } from './SettingsManager';

/// 标题栏材质挡位（2026-09-24 接入设置挡位）：此前硬编码 ADAPTIVE（跟随系统策略）完全不
/// 读设置——用户调挡位后底栏变了标题栏不变。映射：0/1/2 直传 Hds EXQUISITE/GENTLE/SMOOTH
/// （与底栏 materialLevel 直传同口径），10=自适应 → ADAPTIVE（跟随系统）
const HDS_LEVEL_BY_SETTING: hdsMaterial.MaterialLevel[] = [
  hdsMaterial.MaterialLevel.EXQUISITE,
  hdsMaterial.MaterialLevel.GENTLE,
  hdsMaterial.MaterialLevel.SMOOTH,
];

/// lv 由调用方传入（宿主 @StorageLink 订阅挡位 → 变化触发 build 重跑 → titleBar 属性重应用，
/// 与 Index 主页同机制实时生效）。缺省 undefined 时兜底读 static（进页时构建一次的旧路径）
function hdsTitleBarLevel(lv: number): hdsMaterial.MaterialLevel {
  return (lv >= 0 && lv <= 2) ? HDS_LEVEL_BY_SETTING[lv] : hdsMaterial.MaterialLevel.ADAPTIVE;
}

/// 主页标题栏（HdsNavigation.titleBar 用）：MINI 标题 + 滚动渐变模糊 + 材质挡位跟随设置。
/// 主页通常无返回按钮（hideBackButton(true) 由 Index 挂）；右上角菜单由调用方按需
/// 往返回的 opts.content.menu.value 里追加（content 是可选字段，先判空再挂）。
export function buildHomeTitleBar(mainTitle: string, materialLevel: number = 10): HdsNavigationTitleBarOptions {
  return {
    content: {
      title: { mainTitle },
      menu: { value: [] },
    },
    style: {
      scrollEffectOpts: {
        enableScrollEffect: true,
        scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
      },
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.ADAPTIVE,
        materialLevel: hdsTitleBarLevel(materialLevel),
      },
      originalStyle: {
        backgroundStyle: { backgroundColor: '#00000000' },
        contentStyle: {
          titleStyle: {
            mainTitleColor: ThemeManager.colors.textPrimary,
            subTitleColor: ThemeManager.colors.textSecondary,
          },
        },
      },
      scrollEffectStyle: {
        backgroundStyle: {
          backgroundColor: ThemeManager.isDark ? '#CC000000' : '#CCFFFFFF',
          // 滚动模糊蒙层向下延伸高度（28：模糊带短，内容短不可滚动的页不盖内容）
          maskExtraHeight: 28,
        },
        contentStyle: {
          titleStyle: {
            mainTitleColor: ThemeManager.colors.textPrimary,
            subTitleColor: ThemeManager.colors.textSecondary,
          },
        },
      },
    },
    avoidLayoutSafeArea: true,
  } as HdsNavigationTitleBarOptions;
}

/// 带右上角操作按钮的子页标题栏（详情页用：多选/添加到歌单等）
/// actionIcon: sys.symbol.xxx 资源；onAction: 点击回调
/// backIconColor: 返回按钮颜色（**滚动后**：蒙层是封面主色 → 传 coverTextColor；默认主题色）
/// backIconColorTop: 返回按钮颜色（**顶部未滚动**：标题栏透明、按钮直接压封面顶部 →
///   传顶部条带对比色；不传则与滚动态同色。Hds 的 originalStyle/scrollEffectStyle 是两套
///   独立样式，才能做到"按钮颜色随它背后的实际像素变"）
/// actionComponentId: 右上角按钮的组件 id（API 20+）——Hds 把该 id 设到 icon 节点上，
///   `PromptAction.openMenu` 的 TargetInfo.id 可直接锚定**按钮本体**（菜单从按钮下方弹出），
///   避免自画 0×0 锚点手工算坐标弹到标题位置（2026-09-11 VipPage 实证）
export function buildDetailTitleBar(actionIcon: Resource, onAction: () => void,
  backIconColor: ResourceColor = ThemeManager.colors.textPrimary,
  backIconColorTop?: ResourceColor,
  actionComponentId?: string,
  materialLevel?: number): HdsNavigationTitleBarOptions {
  const lv: number = materialLevel ?? SettingsManager.materialLevel;
  return {
    content: {
      title: { mainTitle: '' },
      menu: {
        value: [
          {
            content: {
              icon: actionIcon,
              componentId: actionComponentId,
              action: onAction,
            },
          },
        ],
      },
    },
    style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          // ScrollEffectType.GRADIENT_BLUR（2026-08-21 改回枚举，曾用数值 2）
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        },
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.ADAPTIVE,
        materialLevel: hdsTitleBarLevel(lv),
      },
      originalStyle: {
        backgroundStyle: { backgroundColor: '#00000000' },
        contentStyle: {
          titleStyle: {
            // 用 ThemeManager.colors（与背景同一机制，绝对跟随应用主题），不依赖 sys.color 动态资源解析
            mainTitleColor: ThemeManager.colors.textPrimary,
            subTitleColor: ThemeManager.colors.textSecondary,
          },
          // 图标颜色（顶部态）：透明标题栏 → 返回/菜单都压在封面顶部 → 用顶部条带对比色
          backIconStyle: { iconColor: backIconColorTop ?? backIconColor },
          // 右上角菜单图标同色（Hds 默认走系统资源色，深/浅封面下可能对比不足→看不清）
          menuStyle: { iconColor: backIconColorTop ?? backIconColor },
        },
      },
      scrollEffectStyle: {
        backgroundStyle: {
          // 详情页专用：蒙层透明（只留模糊，不叠白/黑）——页面背景是封面主色，有色蒙层会突兀
          backgroundColor: '#00000000',
          maskExtraHeight: 64,
        },
        contentStyle: {
          titleStyle: {
            mainTitleColor: ThemeManager.colors.textPrimary,
            subTitleColor: ThemeManager.colors.textSecondary,
          },
          backIconStyle: { iconColor: backIconColor },
          menuStyle: { iconColor: backIconColor },
        },
      },
    },
    avoidLayoutSafeArea: true,
  } as HdsNavigationTitleBarOptions;
}

/// 构建子页标题栏配置（界面/媒体库等带返回箭头的子页用）
/// mainTitle 子页标题；avoidLayoutSafeArea=true 内容自动避让状态栏（背景靠组件级 ignoreLayoutSafeArea 延伸）
/// transparentScrollMask=true：滚动蒙层去掉颜色叠加（只留模糊）——背景彩色（封面主色）时白/黑蒙层突兀，详情页/子页专用
/// maskExtraHeight：滚动蒙层向内容方向延伸高度（对齐媒体库 28）
/// scrollEffect：滚动模糊效果开关（默认开；SubPageScaffold 曾试关以消除遮挡，用户要求保留滚动模糊→保持开）
/// backIconColor: 返回按钮颜色（详情页按封面深浅传 coverTextColor；子页默认主题色）
/// backIconColorTop: 顶部未滚动时的返回按钮颜色（详情页压封面顶部，需按顶部条带取色；不传同色）
/// menuItems: 右上角标准 menu 项（2026-09-11 会员页菜单按钮；默认 [] 子页无菜单）
export function buildSubPageTitleBar(mainTitle: string, transparentScrollMask: boolean = false, maskExtraHeight: number = 28, scrollEffect: boolean = true, backIconColor: ResourceColor = ThemeManager.colors.textPrimary, backIconColorTop?: ResourceColor, menuItems?: HdsNavigationMenuItemOptions[],
  materialLevel?: number): HdsNavigationTitleBarOptions {
  const lv: number = materialLevel ?? SettingsManager.materialLevel;
  return {
    content: {
      title: { mainTitle },
      // 子页默认无菜单按钮；调用方传 menuItems 时透传（会员页菜单按钮）
      menu: { value: menuItems ?? [] },
    },
    style: {
        scrollEffectOpts: {
          enableScrollEffect: scrollEffect,
          // ScrollEffectType.GRADIENT_BLUR（2026-08-21 改回枚举，曾用数值 2）
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        },
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.ADAPTIVE,
        materialLevel: hdsTitleBarLevel(lv),
      },
      originalStyle: {
        backgroundStyle: { backgroundColor: '#00000000' },
        contentStyle: {
          titleStyle: {
            mainTitleColor: ThemeManager.colors.textPrimary,
            subTitleColor: ThemeManager.colors.textSecondary,
          },
          // 返回按钮颜色（顶部态）：透明标题栏压封面 → 顶部条带对比色（详情页由 DetailScaffold 传）
          backIconStyle: { iconColor: backIconColorTop ?? backIconColor },
          // 右上角菜单图标同色（2026-09-15：原缺失 → Hds 默认白色；深色封面上"图标白色"、
          // 与详情页 buildDetailTitleBar（已配 menuStyle）不同步。与返回按钮同色的黑白对比色）
          menuStyle: { iconColor: backIconColorTop ?? backIconColor },
        },
      },
      scrollEffectStyle: {
        backgroundStyle: {
          // 透明蒙层：滚动时只剩模糊（材质透出页面颜色），不叠加白/黑——详情页彩色封面背景下更干净
          backgroundColor: transparentScrollMask ? '#00000000' : (ThemeManager.isDark ? '#CC000000' : '#CCFFFFFF'),
          // 滚动模糊蒙层高度：详情页 28（内容顶部沉浸封面承接蒙层）；SubPageScaffold 子页传 0——
          // 子页内容顶部直接是卡片，蒙层向下延伸（无论透明与否，模糊带也是视觉遮挡）会盖住卡片顶部
          maskExtraHeight: maskExtraHeight,
        },
        contentStyle: {
          titleStyle: {
            mainTitleColor: ThemeManager.colors.textPrimary,
            subTitleColor: ThemeManager.colors.textSecondary,
          },
          backIconStyle: { iconColor: backIconColor },
          menuStyle: { iconColor: backIconColor },
        },
      },
    },
    avoidLayoutSafeArea: true,
  } as HdsNavigationTitleBarOptions;
}
