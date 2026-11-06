/// 跑马灯文本（基于鸿蒙内置 Marquee 组件，since 8）
/// 内容超出容器宽度时水平滚动（start 控制启停，loop≤0 无限循环，delay 延迟启动）
/// 文本宽用 Visibility.Hidden 的隐藏 Text 测量（保留布局 onAreaChange 可靠触发），超宽才滚，短文本静止
/// 切歌/文本更新：Marquee 默认 MarqueeUpdateStrategy.DEFAULT 会自动重置位置并重启滚动，
/// 无需手动 start false→true（start 不能重启"已完成"的滚动，但 src 更新由策略接管）
/// 外部接口：text / fontSize / fontColor / fontWeight
@Component
export struct MarqueeText {
  /// 文本内容（变化时重新评估超宽）
  @Prop @Watch('onTextChange') text: string = '';
  @Prop fontSize: number = 15;
  @Prop fontColor: string = '#000000';
  @Prop fontWeight: number = FontWeight.Normal;
  /// 是否滚动（文本宽 > 容器宽）
  @State shouldScroll: boolean = false;
  private containerW: number = 0;
  private textW: number = 0;
  private readonly DELAY_MS: number = 2000;

  /// 文本变化：src 更新由 Marquee DEFAULT 策略自动重启滚动，这里只重算是否超宽
  onTextChange(): void {
    this.evaluate();
  }

  private evaluate(): void {
    this.shouldScroll = this.text.length > 0 && this.containerW > 0 && this.textW > this.containerW;
  }

  build() {
    Stack() {
      // 测宽用（Visibility.Hidden：保留布局确保 onAreaChange 触发，不可见）
      Text(this.text)
        .fontSize(this.fontSize)
        .fontWeight(this.fontWeight)
        .visibility(Visibility.Hidden)
        .onAreaChange((o: Area, n: Area) => {
          if (Math.abs(Number(n.width) - this.textW) > 0.5) {
            this.textW = Number(n.width) || 0;
            this.evaluate();
          }
        })

      // 内置 Marquee：超宽才滚，无限循环，延迟启动
      Marquee({
        start: this.shouldScroll,
        src: this.text,
        loop: 0,
        delay: this.DELAY_MS,
      })
        .fontSize(this.fontSize)
        .fontColor(this.fontColor)
        .fontWeight(this.fontWeight)
        .width('100%')
        .onAreaChange((o: Area, n: Area) => {
          if (Math.abs(Number(n.width) - this.containerW) > 0.5) {
            this.containerW = Number(n.width) || 0;
            this.evaluate();
          }
        })
    }
    .width('100%')
  }
}
