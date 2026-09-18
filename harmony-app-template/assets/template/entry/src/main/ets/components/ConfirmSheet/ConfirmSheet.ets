/// 二次确认弹窗（公共组件）——对齐 HarmonyOSComponentUXExamples 的「操作确认弹出框」（ActionDialog）
/// 实现：CustomContentDialog（@kit.ArkUI 系统 Dialog）+ CustomDialogController
/// - 确认按钮 role: ButtonRole.ERROR（系统红色 danger）；取消 TEXTUAL
/// - @ComponentV2（CustomContentDialog 需 V2 环境；UI 放 @Builder 方法，contentBuilder 只转发调用）
/// 用法：ConfirmSheet({ show, onDismiss, title, message, confirmText, danger, onConfirm })
import { ThemeManager } from '../../model/ThemeManager';
import { CustomContentDialog } from '@kit.ArkUI';

@ComponentV2
export struct ConfirmSheet {
  /// 弹窗显示（父组件状态单向传入；show=true → 打开 Dialog）
  @Param show: boolean = false;
  /// 关闭回调（任何方式关闭后通知父组件复位 show=false）
  @Event onDismiss: () => void = () => {};
  /// 标题（默认"确认"）
  @Param title: string = '确认';
  /// 提示内容
  @Param message: string = '';
  /// 确认按钮文案（默认"确认"）
  @Param confirmText: string = '确认';
  /// 确认按钮是否 danger（role=ButtonRole.ERROR 系统红色）；默认 false
  @Param danger: boolean = false;
  /// 兼容保留（Dialog 是系统单层弹窗，天然互斥，此字段忽略）
  @Param group: string = '';
  /// 确认回调（取消/关闭不回调）
  @Event onConfirm: () => void = () => {};
  private controller: CustomDialogController | undefined = undefined;

  /// show 变化 → 重建 Dialog（取最新 title/message）并打开
  @Monitor('show')
  onShowChange(): void {
    if (this.show) {
      this.controller?.close();
      this.controller = new CustomDialogController({
        builder: CustomContentDialog({
          primaryTitle: this.title,
          contentBuilder: () => {
            this.buildContent();
          },
          buttons: [
            {
              value: '取消',
              buttonStyle: ButtonStyleMode.TEXTUAL,
              action: () => { this.closeDialog(); },
            },
            {
              value: this.confirmText,
              // danger → 系统红色 ERROR 角色按钮（对齐范例 ActionDialog）
              role: this.danger ? ButtonRole.ERROR : ButtonRole.NORMAL,
              action: () => {
                this.closeDialog();
                this.onConfirm();
              },
            },
          ],
        }),
        autoCancel: true,
        alignment: DialogAlignment.Center,
      });
      this.controller.open();
    }
  }

  @Builder
  buildContent(): void {
    Column() {
      Text(this.message)
        .fontSize(14)
        .fontColor(ThemeManager.colors.textSecondary)
        .width('100%')
        .lineHeight(20)
        .textAlign(TextAlign.Start)
    }
    .width('100%')
  }

  /// 宿主 build（@ComponentV2 必需；Dialog 由 controller 驱动，此处 0 尺寸占位）
  build() {
    Column().width(0).height(0)
  }

  private closeDialog(): void {
    this.controller?.close();
    this.onDismiss();
  }
}
