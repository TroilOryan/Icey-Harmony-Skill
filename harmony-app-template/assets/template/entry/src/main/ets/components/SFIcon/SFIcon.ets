/// 图标组件：用从图标库提取的 SVG（fluentui/sficon）渲染
/// SVG 放 resources/base/media（play.svg 等），Image 渲染，fillColor 动态变色
/// SVG 由 tools/export_icons.py 从图标库 ttf 提取生成（归一化 0~24，黑色填充）
import { SFIcons } from './sficon_names';

export { SFIcons } from './sficon_names';

@Component
export struct SFIcon {
  /// 图标资源名（SFIcons.sf_play 等，对应 resources/base/media/<name>.svg）
  @Prop name: string = '';
  @Prop fontSize: number = 24;
  @Prop fontColor: ResourceColor = Color.White;

  build() {
    Image($r(`app.media.${this.name}`))
      .width(this.fontSize)
      .height(this.fontSize)
      .fillColor(this.fontColor)
  }
}
