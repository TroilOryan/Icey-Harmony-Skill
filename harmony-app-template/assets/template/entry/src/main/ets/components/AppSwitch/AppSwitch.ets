/// 统一开关组件（替换系统 Toggle——Toggle 在本 SDK 滑块渲染偏移/溢出轨道）
/// 视觉：圆角轨道（开=主题色 accent / 关=占位灰）+ 白色滑块（带阴影），切换 200ms 滑动
/// 完全自绘，无系统组件渲染 bug；全项目开关统一走这里
import { ThemeManager } from '../../model/ThemeManager';

@Component
export struct AppSwitch {
  /// 开关状态
  @Prop isOn: boolean = false;
  onToggle: (v: boolean) => void = () => {};
  /// 轨道宽高（vp）
  private static readonly W: number = 46;
  private static readonly H: number = 26;
  /// 滑块尺寸与边距（vp）
  private static readonly KNOB: number = 20;
  private static readonly PAD: number = 3;

  /// 滑块水平位移：关=0（贴左，margin PAD 3vp），开=W-KNOB-2*PAD=20（贴右）
  private knobOffset(): number {
    return this.isOn ? AppSwitch.W - AppSwitch.KNOB - AppSwitch.PAD * 2 : 0;
  }

  build() {
    Stack() {
      // 轨道（圆角胶囊）
      Row()
        .width(AppSwitch.W)
        .height(AppSwitch.H)
        .borderRadius(AppSwitch.H / 2)
        .backgroundColor(this.isOn ? ThemeManager.colors.accent : ThemeManager.colors.placeholderBg)

      // 滑块（白色小圆 + 阴影，靠左，开态右移）
      Column()
        .width(AppSwitch.KNOB)
        .height(AppSwitch.KNOB)
        .borderRadius(AppSwitch.KNOB / 2)
        .backgroundColor('#FFFFFF')
        .shadow({ radius: 3, color: '#40000000', offsetX: 0, offsetY: 1 })
        .margin(AppSwitch.PAD)
        .translate({ x: this.knobOffset() })
        // 隐式动画：isOn 变化时滑块平滑滑动
        .animation({ duration: 200, curve: Curve.EaseOut })
    }
    .width(AppSwitch.W)
    .height(AppSwitch.H)
    .alignContent(Alignment.Start)
    .onClick(() => { this.onToggle(!this.isOn); })
  }
}
