/// 全局 UIAbilityContext 持有（2026-08-27 播控中心唤醒修复）
/// 背景：Insight Intent 后台冷启动执行器（IntentExecutor）需要 UIAbilityContext 才能
/// 初始化 AVSession/后台播放链路，但 InsightIntentContext 不提供 context 获取。
/// 官方后台冷启动时序：系统**先创建 UIAbility（EntryAbility.onCreate 执行）再调用
/// executor.onExecuteInUIAbilityBackgroundMode**——故 EntryAbility.onCreate 存入，
/// executor 读取必然有值。
/// 对齐 media-provider demo 的 GlobalContext 模式（demo: GlobalContext.setObject(CONTEXT)）。
import common from '@ohos.app.ability.common';
import { window } from '@kit.ArkUI';

export class AppGlobalContext {
  private static ctx: common.UIAbilityContext | null = null;
  /// 主窗口 WindowStage（2026-09-22 桌面歌词）：createSubWindow 必须从 WindowStage 发起，
  /// EntryAbility.onWindowStageCreate 存入，DesktopLyricManager 读取
  private static stage: window.WindowStage | null = null;

  static setContext(ctx: common.UIAbilityContext): void {
    AppGlobalContext.ctx = ctx;
  }

  static getContext(): common.UIAbilityContext | null {
    return AppGlobalContext.ctx;
  }

  static setWindowStage(stage: window.WindowStage): void {
    AppGlobalContext.stage = stage;
  }

  static getWindowStage(): window.WindowStage | null {
    return AppGlobalContext.stage;
  }
}
