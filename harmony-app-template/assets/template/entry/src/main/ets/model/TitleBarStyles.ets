/// 子页标题栏配置 helper（普通函数，非 @Builder，避开 @Builder 闭包 this 绑定陷阱）
/// 复用首页的 scrollEffect(滚动模糊) + 材质 + 安全区避让配置，menu 传 [] 子页无菜单按钮。
/// HdsNavigationTitleBarOptions 与 HdsNavigation.titleBar 同类型，HdsNavDestination.titleBar 也用它。
/// 注意：Hds 枚举曾用数值字面量（release 无导出闪退——实为测试机 API 低于 @since）；
/// 2026-08-21 改回枚举（ScrollEffectType/hdsMaterial），兼容下限 6.1.0(23) 正常导出。
import { HdsNavigationTitleBarOptions, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';
import { ThemeManager } from './ThemeManager';

/// 带右上角操作按钮的子页标题栏（详情页用：多选/添加到歌单等）
/// actionIcon: sys.symbol.xxx 资源；onAction: 点击回调
/// backIconColor: 返回按钮颜色（详情页按封面深浅传 coverTextColor；默认主题色 textPrimary）
export function buildDetailTitleBar(actionIcon: Resource, onAction: () => void,
  backIconColor: ResourceColor = ThemeManager.colors.textPrimary): HdsNavigationTitleBarOptions {
  return {
    content: {
      title: { mainTitle: '' },
      menu: {
        value: [
          {
            content: {
              icon: actionIcon,
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
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
      },
      originalStyle: {
        backgroundStyle: { backgroundColor: '#00000000' },
        contentStyle: {
          titleStyle: {
            // 用 ThemeManager.colors（与背景同一机制，绝对跟随应用主题），不依赖 sys.color 动态资源解析
            mainTitleColor: ThemeManager.colors.textPrimary,
            subTitleColor: ThemeManager.colors.textSecondary,
          },
          // 返回按钮颜色：详情页按封面深浅传 coverTextColor（深背景白/浅背景深）
          backIconStyle: { iconColor: backIconColor },
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
        },
      },
    },
    avoidLayoutSafeArea: true,
  } as HdsNavigationTitleBarOptions;
}

/// 构建首页（tab 主页）标题栏配置：大标题 + 滚动渐变模糊 + ADAPTIVE 材质。
/// materialLevel：沉浸光感材质挡位（0强/1平衡/2弱/10自适应；设置项联动传值）
/// hasMenu：是否需要右上角操作按钮（需要时调用方自己构造 menu 对象替换，参考 Index）
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
        materialLevel: materialLevel,
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

/// 构建子页标题栏配置（界面/媒体库等带返回箭头的子页用）
/// mainTitle 子页标题；avoidLayoutSafeArea=true 内容自动避让状态栏（背景靠组件级 ignoreLayoutSafeArea 延伸）
/// transparentScrollMask=true：滚动蒙层去掉颜色叠加（只留模糊）——背景彩色（封面主色）时白/黑蒙层突兀，详情页/子页专用
/// maskExtraHeight：滚动蒙层向内容方向延伸高度（对齐媒体库 28）
/// scrollEffect：滚动模糊效果开关（默认开；SubPageScaffold 曾试关以消除遮挡，用户要求保留滚动模糊→保持开）
/// backIconColor: 返回按钮颜色（详情页按封面深浅传 coverTextColor；子页默认主题色）
export function buildSubPageTitleBar(mainTitle: string, transparentScrollMask: boolean = false, maskExtraHeight: number = 28, scrollEffect: boolean = true, backIconColor: ResourceColor = ThemeManager.colors.textPrimary): HdsNavigationTitleBarOptions {
  return {
    content: {
      title: { mainTitle },
      // 子页无菜单按钮
      menu: { value: [] },
    },
    style: {
        scrollEffectOpts: {
          enableScrollEffect: scrollEffect,
          // ScrollEffectType.GRADIENT_BLUR（2026-08-21 改回枚举，曾用数值 2）
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        },
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.ADAPTIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
      },
      originalStyle: {
        backgroundStyle: { backgroundColor: '#00000000' },
        contentStyle: {
          titleStyle: {
            mainTitleColor: ThemeManager.colors.textPrimary,
            subTitleColor: ThemeManager.colors.textSecondary,
          },
          // 返回按钮颜色：详情页按封面深浅传 coverTextColor（深背景白/浅背景深）
          backIconStyle: { iconColor: backIconColor },
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
        },
      },
    },
    avoidLayoutSafeArea: true,
  } as HdsNavigationTitleBarOptions;
}
