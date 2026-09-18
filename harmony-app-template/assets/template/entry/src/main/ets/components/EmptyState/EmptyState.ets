/// 空状态占位组件（原项目 empty.png + 提示文字）
/// 用法：EmptyState({ message: '还没有音乐' })
import { ThemeManager } from '../../model/ThemeManager';

@Component
export struct EmptyState {
  /// 提示文字
  @Prop message: string = '暂无数据';
  /// 副提示文字（可选）
  @Prop subMessage: string = '';
  /// 图片宽高（vp）
  @Prop imgSize: number = 120;
  /// 是否撑满父容器高度（居中显示）
  @Prop fill: boolean = false;
  /// 顶部留白（vp，详情页列表空状态用）
  @Prop paddingTop: number = 0;

  build() {
    Column() {
      Image($r('app.media.empty'))
        .width(this.imgSize)
        .height(this.imgSize)
        .objectFit(ImageFit.Contain)
        .margin({ bottom: 12 })
      Text(this.message)
        .fontSize(15)
        .fontColor(ThemeManager.colors.textPrimary)
        .fontWeight(FontWeight.Medium)
      if (this.subMessage.length > 0) {
        Text(this.subMessage)
          .fontSize(13)
          .fontColor(ThemeManager.colors.textSecondary)
          .margin({ top: 4 })
      }
    }
    .width('100%')
    .height(this.fill ? '100%' : 'auto')
    .padding({ top: this.paddingTop })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
