/// 光感卡片（沉浸光感材质承载）
///
/// 为什么承载层必须用 `ToggleType.Button`：
///   官方文档明确 —— `Checkbox` 未适配沉浸光感（设置后无效果）；
///   `Switch` 的材质参数只作为开启标记，实际用组件内部预设视觉，**只覆盖开关本体那一小片**；
///   只有 `Button` 的效果与 Button 组件一致（影响背景色/边框/阴影），
///   才能得到**一整块矩形材质**。
///
/// 五条属性缺一不可（逐条后果见注释），且分层必须是
///   `Stack { MaterialCardLayer(底) → 内容(上) }`
/// —— 材质**不采样同一 Stack 的兄弟节点**（采样的是组件背后的窗口内容），
///    内容画在材质之下会完全看不见。
import { ThemeManager } from '../../model/ThemeManager';
import {
  applyMaterialCarrier, materialActive, fallbackSurface,
  KEY_FORCE_MATERIAL,
} from '../../services/SystemMaterial';

/// 材质承载层：只负责画材质，不参与交互与无障碍
@Component
export struct MaterialCardLayer {
  /// 圆角（必须与外壳一致，否则卡片里会出现内嵌的小圆角描边）
  @Prop layerRadius: number = 20;
  /// 是否让材质自带投影（小尺寸芯片建议关，否则像"按钮背后顶了一层影子"）
  @Prop layerShadow: boolean = true;
  /// 「强制光感」开关的订阅值 —— 由组件自己订阅，保证拨开关后已画出的卡片重算材质
  @StorageLink(KEY_FORCE_MATERIAL) forceMaterial: boolean = true;

  /// ⚠️ 必须写成**方法调用**而非内联对象字面量：
  /// 属性读取发生在渲染期才登记得上依赖，切主题色/拨开关时才会重新求值；
  /// 写成内联字面量 → 已画出的组件不更新。
  private carrierModifier(): AttributeModifier<ToggleAttribute> {
    return {
      applyNormalAttribute: (instance: ToggleAttribute): void => {
        applyMaterialCarrier(instance, this.forceMaterial, false, false, this.layerShadow);
      },
    };
  }

  build() {
    Toggle({ type: ToggleType.Button, isOn: false })
      // ① 尺寸必须 matchParent：百分比按"父级可用尺寸"解析，卡片在列表里时可用高度是整列剩余空间，
      //    会把自己连同卡片一起顶大；matchParent 按父级**实测**尺寸解析，随内容走
      .width(LayoutPolicy.matchParent)
      .height(LayoutPolicy.matchParent)
      // ② 圆角与外壳一致：否则 Toggle 会画出自己的小圆角按钮图形，卡片里出现内嵌边框
      .borderRadius(this.layerRadius)
      // ③ 必须显式透明：不透明底色会垫在材质之下，叠出灰感甚至完全遮住材质
      .backgroundColor(Color.Transparent)
      // ④ 只是画布：不抢焦点、不参与无障碍、不吃点击
      .enabled(false)
      .focusable(false)
      .accessibilityLevel('no')
      .hitTestBehavior(HitTestMode.None)
      // ⑤ systemMaterial 必须放在所有样式属性**之后** → 用 attributeModifier 挂在链末
      .attributeModifier(this.carrierModifier())
  }
}

/// 光感卡片外壳：材质层 + 内容层（+ 不可用时的毛玻璃降级）
/// 用法：MaterialCard({ cardRadius: 20, cardMarginTop: 12 }) { Column() { ... }.padding(...) }
/// 注意：横向内缩由宿主 List 的 padding 提供，本组件**不带横向 margin**（LSN-014）
@Component
export struct MaterialCard {
  /// 卡片圆角（与内部元素圆角保持一致）
  @Prop cardRadius: number = 20;
  /// 顶部间距（卡片只留纵向间距，横向交宿主 List）
  @Prop cardMarginTop: number = 12;
  /// 底部间距（多数卡片用顶部间距；SettingsGroup 这类用底部 16）
  @Prop cardMarginBottom: number = 0;
  /// 材质是否自带投影
  @Prop cardShadow: boolean = true;
  /// 是否由调用方自持不透明背景（如渐变 hero 卡）—— 材质会被不透明底色盖住，白费，故跳过
  @Prop opaqueSurface: boolean = false;
  /// 整卡点击（如资产/心愿列表卡）；默认空实现，无副作用的卡片可不传
  onCardTap: () => void = () => {};
  @BuilderParam content: () => void;

  @StorageLink(KEY_FORCE_MATERIAL) forceMaterial: boolean = true;
  /// 主题版本号：切深浅色时重算降级底色
  @StorageLink('themeColorsVersion') themeColorsVersion: number = 0;

  private useMaterial(): boolean {
    return !this.opaqueSurface && materialActive(this.forceMaterial);
  }

  build() {
    Stack() {
      // ① 材质层（最底）
      if (this.useMaterial()) {
        MaterialCardLayer({ layerRadius: this.cardRadius, layerShadow: this.cardShadow })
      }
      // ② 内容层（在材质之上——材质不采样兄弟节点，内容必须在它上面才看得见）
      Column() {
        this.content()
      }
      .width('100%')
    }
    .width('100%')
    .borderRadius(this.cardRadius)
    .margin({ top: this.cardMarginTop, bottom: this.cardMarginBottom })
    .clip(true)
    // 降级路径：材质不可用时用**半透明**底色 + 毛玻璃
    // （不透明底色会把模糊整块盖住——这一步最容易漏）
    .backgroundColor(this.useMaterial() ? Color.Transparent : fallbackSurface(ThemeManager.isDark))
    .backgroundBlurStyle(this.useMaterial() ? BlurStyle.NONE : BlurStyle.Thin)
    .onClick(() => {
      this.onCardTap();
    })
  }
}
