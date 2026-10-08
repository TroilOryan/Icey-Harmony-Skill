/// 通用选择弹窗（label/value 项点击弹出，选项列表 + 选中态）
/// 用 @CustomDialog，调用方用 OptionSheetController 管理。选项点击回调 onSelect。
import { ThemeManager } from '../../model/ThemeManager';

/// 选项
export interface OptionItem {
  label: string;
  /// 是否当前选中（显示勾号）
  selected: boolean;
  /// 选中回调
  onTap: () => void;
}

@CustomDialog
export struct OptionSheet {
  /// 弹窗标题
  title: string = '';
  /// 选项列表
  options: OptionItem[] = [];
  /// 弹窗控制器（@CustomDialog 自动注入）
  controller: CustomDialogController;

  build() {
    Column() {
      // 标题
      Text(this.title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeManager.colors.textPrimary)
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 20, bottom: 12 })

      // 分隔线
      Divider().color(ThemeManager.colors.divider).strokeWidth(0.5)

      // 选项列表
      ForEach(this.options, (opt: OptionItem, index: number) => {
        Row() {
          Text(opt.label)
            .fontSize(15)
            .fontColor(ThemeManager.colors.textPrimary)
            .layoutWeight(1)

          // 选中态勾号
          if (opt.selected) {
            Text('✓')
              .fontSize(16)
              .fontColor(ThemeManager.colors.accent)
          }
        }
        .width('100%')
        .height(48)
        .padding({ left: 20, right: 20 })
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          opt.onTap();
          this.controller.close();
        })

        // 选项间分隔线（非最后一项）
        if (index < this.options.length - 1) {
          Divider().color(ThemeManager.colors.divider).strokeWidth(0.5)
        }
      }, (opt: OptionItem, index: number) => index.toString())
    }
    .width('80%')
    .backgroundColor(ThemeManager.colors.cardBg)
    .borderRadius(16)
    .clip(true)
  }
}
