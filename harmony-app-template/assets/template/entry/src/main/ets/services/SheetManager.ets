/// 全局弹窗管理服务（借鉴 DialogHub 的弹窗栈/生命周期管理思想，轻量落地）
/// 解决的问题：
/// 1. 同页多弹窗叠加：同一 group 的弹窗打开时自动关闭其他已打开的（互斥），防两层蒙层叠压
/// 2. App 退后台弹窗残留：宽屏窗口级 dialog（promptAction）退后台不自动关，回前台残留——
///    由 AppSheet 监听 'appBackgrounded' 信号统一关闭（dismissible=false 的保留，如导入进度）
/// 3. 弹窗状态分散：AppSheet 统一向这里注册，可全局查询/关闭
///
/// 设计要点：
/// - group 默认 '' = 不参与互斥（向后兼容，嵌套弹窗场景安全：ConfirmSheet 嵌在 MediaActionSheet
///   内部时给不同的 group 或留空，不会被外层互斥关掉）
/// - 互斥只关"同 group"弹窗，不同 group / 空 group 互不影响
/// - close 回调由 AppSheet 注入（置 show=false + 触发 onDismiss），管理器不感知组件细节

/// 注册表条目：一个打开中的弹窗实例
export interface SheetEntry {
  /// 条目 id（register 分配；入参可不传）
  id?: number;
  /// 互斥分组（空串 = 不参与互斥）
  group: string;
  /// 是否可手动关闭（dismissible=false 的弹窗不随 App 退后台关闭，如导入进度）
  dismissible: boolean;
  /// 关闭回调（AppSheet 注入：show=false + onDismiss）
  close: () => void;
}

export class SheetManager {
  private static entries: SheetEntry[] = [];
  private static nextId: number = 1;

  /// 注册弹窗（AppSheet aboutToAppear 调），返回条目 id（unregister 用）
  static register(e: SheetEntry): number {
    const id = SheetManager.nextId++;
    const entry: SheetEntry = {
      id: id,
      group: e.group,
      dismissible: e.dismissible,
      close: e.close,
    };
    SheetManager.entries.push(entry);
    return id;
  }

  /// 注销弹窗（AppSheet aboutToDisappear 调）
  static unregister(id: number): void {
    const i = SheetManager.entries.findIndex((e: SheetEntry) => e.id === id);
    if (i >= 0) SheetManager.entries.splice(i, 1);
  }

  /// 关闭指定 group 的其他弹窗（互斥，exceptId 例外——自己正在打开不关自己）
  /// 仅关可手动关闭的（dismissible=true），防误关导入进度等强信号弹窗
  static closeGroup(group: string, exceptId: number): void {
    if (!group) return;
    for (const e of SheetManager.entries) {
      if (e.id !== exceptId && e.group === group && e.dismissible) {
        e.close();
      }
    }
  }

  /// 关闭所有可手动关闭的弹窗（App 退后台/页面销毁等场景）
  static closeAll(): void {
    const entries = [...SheetManager.entries];
    for (const e of entries) {
      if (e.dismissible) e.close();
    }
  }

  /// 当前打开（可手动关闭）的弹窗数，调试用
  static get openCount(): number {
    return SheetManager.entries.filter((e: SheetEntry) => e.dismissible).length;
  }
}
