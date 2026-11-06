/// 通用懒加载数据源（LazyForEach 专用）
/// 为什么需要：ArkUI List/Grid 用 ForEach 时仍会**全量**构建每个 item 的 UI 描述 + 数据变化**全量 diff**，
/// 4000+ 项时主线程卡顿（导入 4000 首闪退的因子之一）；LazyForEach 按需创建视口附近的 item，大数据量必须使用。
/// 用法：
///   this.ds.load(items)  —— 数据/顺序变化时调用（内部 notifyDataReload，LazyForEach 重建）
///   this.ds.reload()     —— 数据未变但 item 依赖的外部状态变了（如切歌后 isActive 高亮刷新，
///                           LazyForEach 的已渲染 item 不会随组件重建自动重新求值参数，必须手动重建）
export class ArrayDataSource<T> implements IDataSource {
  private items: T[] = [];
  private listeners: DataChangeListener[] = [];

  /// 整体替换数据并通知重建
  load(items: T[]): void {
    this.items = items;
    this.notifyDataReload();
  }

  /// 数据未变，仅通知 LazyForEach 重建已渲染 item
  reload(): void {
    this.notifyDataReload();
  }

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): Object {
    return this.items[index] as Object;
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const i = this.listeners.indexOf(listener);
    if (i >= 0) {
      this.listeners.splice(i, 1);
    }
  }

  private notifyDataReload(): void {
    for (const l of this.listeners) {
      l.onDataReloaded();
    }
  }
}
