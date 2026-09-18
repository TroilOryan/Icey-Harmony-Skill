/// 全局路由单例：持有 NavPathStack，供任意深层组件 push/pop 子页。
/// Tab 页/深层组件不直接持有 Index 的 pathStack，用单例避免层层透传。
/// Index.aboutToAppear 调 setPathStack 注入；不放 AppStorage（NavPathStack 是运行时路由栈）。
/// NavPathStack / NavPathInfo 是 ArkUI 全局类型（无需 import）。
import { promptAction } from '@kit.ArkUI';

/// 路由名常量（与 Index.navDestinationBuilder 的 name 分发对应；按需增删）
export const ROUTE_HOME_DETAIL = 'homeDetail';
export const ROUTE_SETTINGS_SUB = 'settingsSub';
export const ROUTE_ABOUT = 'about';

export class AppRouter {
  private static instance: AppRouter = new AppRouter();
  private pathStack: NavPathStack = new NavPathStack();
  /// 最近一次 push 的 param（同步内存，避免 @StorageProp 初始值时序问题：子页 aboutToAppear 读此）
  private lastParam: Object | null = null;

  static getInstance(): AppRouter {
    return AppRouter.instance;
  }

  /// Index 注入真实的 NavPathStack（HdsNavigation 构造用的那个）
  setPathStack(stack: NavPathStack): void {
    this.pathStack = stack;
  }

  getPathStack(): NavPathStack {
    return this.pathStack;
  }

  /// 取最近一次 push 的 param（子页 aboutToAppear 读，比 @StorageProp 可靠）
  static getLastParam(): Object | null {
    return AppRouter.getInstance().lastParam;
  }

  /// push 子页（可选参数；无参传 null）
  /// 防路由栈无限叠加：栈中已有相同页面（同 name；有参页要求参数相同）→ toast 提示 + 不 push
  push(name: string, param?: Object): void {
    if (this.checkDuplicate(name, param)) {
      promptAction.showToast({ message: '页面已打开', duration: 1500 });
      return;
    }
    AppRouter.getInstance().lastParam = param !== undefined ? param : null;
    const info = new NavPathInfo(name, param !== undefined ? param : null);
    this.pathStack.pushPath(info);
  }

  /// 检查栈中是否已有相同页面（name + 参数）：返回 true 表示重复（应拦截）
  private checkDuplicate(name: string, param?: Object): boolean {
    const names = this.pathStack.getAllPathName();
    const paramVal = param !== undefined && param !== null ? `${param}` : null;
    for (let i = 0; i < names.length; i++) {
      if (names[i] !== name) continue;
      const p = this.pathStack.getParamByIndex(i) as Object | undefined;
      const existVal = p !== undefined && p !== null ? `${p}` : null;
      // 无参页面：同名即重复；有参页面：同参才重复
      if (paramVal === null) return true;
      if (existVal === paramVal) return true;
    }
    return false;
  }

  /// pop 栈顶子页
  pop(): void {
    this.pathStack.pop();
  }

  /// pop 到指定栈深度
  popTo(index: number): void {
    this.pathStack.popToIndex(index);
  }

  /// 替换栈顶子页（不增加深度）
  replace(name: string, param?: Object): void {
    const info = new NavPathInfo(name, param !== undefined ? param : null);
    this.pathStack.replacePath(info);
  }
}
