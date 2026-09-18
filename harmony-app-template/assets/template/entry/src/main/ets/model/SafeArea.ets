/// 安全区避让高度（全屏布局 setWindowLayoutFullScreen 后，UI 需手动避让状态栏/导航条）
/// 由 EntryAbility 开全屏后从 window.getWindowAvoidArea 取值写入 AppStorage
/// UI 读 SafeArea.top / SafeArea.bottom / SafeArea.left / SafeArea.right 加 padding
/// 竖屏：top=状态栏、bottom=导航条；横屏：状态栏在左右 → left/right 有值（挖孔同区域）

export class SafeArea {
  /// 状态栏高度（vp）
  static get top(): number {
    return AppStorage.get<number>('safeAreaTop') ?? 0;
  }

  /// 导航条高度（vp）
  static get bottom(): number {
    return AppStorage.get<number>('safeAreaBottom') ?? 0;
  }

  /// 左避让宽度（vp，横屏状态栏/挖孔在左时）
  static get left(): number {
    return AppStorage.get<number>('safeAreaLeft') ?? 0;
  }

  /// 右避让宽度（vp，横屏状态栏/挖孔在右时）
  static get right(): number {
    return AppStorage.get<number>('safeAreaRight') ?? 0;
  }

  static set(top: number, bottom: number, left: number = 0, right: number = 0): void {
    AppStorage.set<number>('safeAreaTop', top);
    AppStorage.set<number>('safeAreaBottom', bottom);
    AppStorage.set<number>('safeAreaLeft', left);
    AppStorage.set<number>('safeAreaRight', right);
  }

  static init(): void {
    AppStorage.setOrCreate<number>('safeAreaTop', 0);
    AppStorage.setOrCreate<number>('safeAreaBottom', 0);
    AppStorage.setOrCreate<number>('safeAreaLeft', 0);
    AppStorage.setOrCreate<number>('safeAreaRight', 0);
  }
}
