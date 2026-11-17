---
name: harmony-context-menu
agent_created: true
description: HarmonyOS/ArkTS 长按/右键浮出操作菜单（bindContextMenu + Menu/MenuItem，带系统符号图标与危险项）的完整实现方案与踩坑。当需要给列表行做长按菜单、右键菜单、带图标的菜单、bandizip 式浮层菜单，或遇到 bindMenu 只有纯文本 / bindContextMenu 编译报 "No overload matches this call" / MenuItem 点击无反应 / 系统符号不显示 时使用。含配套的列表性能规范（LazyForEach + reuseId + cachedCount）与长任务模态进度。Icey-Archive（冰沙压缩）API 26 验证。
---

# Harmony 长按 / 右键浮出菜单（bindContextMenu 方案）

## 结论（先读）

| 需求 | 用哪个 |
|---|---|
| 菜单项要**图标**、危险项红字、分组 | `bindContextMenu` + `Menu(){ MenuItem() }` |
| 菜单只要**纯文本**、锚在组件上 | `bindMenu(MenuElement[])` |
| 标题栏右上角按钮弹菜单 | 另一个技能 `harmony-titlebar-menu`（openMenu 命令式） |
| 长任务的"正在处理"提示 | **全屏模态遮罩**（见本文末节），不要用底部条 |
| 一句话反馈（成功/失败） | `promptAction.showToast`，不要自绘浮层 |

**关键认知**：`bindContextMenu` 是**跟随手势位置弹出**的临时浮层（接近 Windows/Bandizip 右键）；
`bindMenu` 是**锚定在组件上**的常驻菜单——长列表滚动时观感更差。
PC(2in1) 上鼠标**右键等价于 LongPress**，所以 `ResponseType.LongPress` 一个就够，不必再绑 `RightClick`。

## 最小可用写法

```ets
Row() { /* 行内容 */ }
  .bindContextMenu(this.RowMenu, ResponseType.LongPress, this.menuOptions())

@Builder
RowMenu() {
  Menu() {
    ForEach(this.actionsOf(), (a: RowAction) => {
      MenuItem({
        // ⚠️ 系统符号必须用 symbolStartIcon，见下方坑 3
        symbolStartIcon: a.icon === null ? undefined : new SymbolGlyphModifier(a.icon),
        content: a.label,
      })
        .enabled(a.enabled)
        .contentFontColor(a.danger ? '#D93026' : ThemeManager.colors.textPrimary)
        // ⚠️ 点击必须用 .onClick，见下方坑 4
        .onClick(() => {
          a.action();
          try { this.getUIContext().getContextMenuController().close(); } catch (_) {}
        })
    }, (a: RowAction) => a.label)
  }
}

private menuOptions(): ContextMenuOptions {
  const o: ContextMenuOptions = {
    placement: Placement.Bottom,
    targetSpace: LengthMetrics.vp(4),   // 贴着目标弹出
    backgroundColor: ThemeManager.colors.cardBg,
    borderRadius: 12,                    // ⚠️ 这里不吃 LengthMetrics，见坑 5
    hapticFeedbackMode: HapticFeedbackMode.ENABLED,
  };
  return o;
}
```

## 五个已踩过的坑（都会导致编译失败或点了没反应）

### 坑 1：不能用三元表达式控制「是否显示」

```ets
// ❌ 编译失败：No overload matches this call
//    三元把 false 与 builder 的 void 返回合流成 `false | void`，两个重载都不匹配
.bindContextMenu(this.row.isDir ? false : this.RowMenu(), ResponseType.LongPress)

// ❌ 同样不行（isShown 重载第一个参数要 boolean）
.bindContextMenu(this.row.isDir ? false : this.RowMenu, this.RowMenu, opts)
```

**正解**：想「这一行不弹菜单」时，让 `RowMenu` 产出**空内容**（`actionsOf()` 返回空数组）。
`Menu()` 里没有任何 `MenuItem` 时系统不会弹出空浮层，无需条件判断。

### 坑 2：`bindContextMenu` 的第一个参数是 **builder 引用**，不是调用结果

```ets
.bindContextMenu(this.RowMenu, ...)    // ✅ 传 @Builder 方法本身
.bindContextMenu(this.RowMenu(), ...)  // ❌ 传的是调用结果（void）
```

### 坑 3：系统符号 `$r('sys.symbol.xxx')` 不能塞进 `startIcon`

`MenuItemOptions.startIcon` 的类型是 `ResourceStr`（只吃图片资源），
传系统符号**不会显示**。必须用 `symbolStartIcon: SymbolGlyphModifier`：

```ets
import { SymbolGlyphModifier } from '@kit.ArkUI';
symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash'))
```

`SymbolGlyphModifier` 的构造参数就是 `Resource`，正好吃 `sys.symbol.*`。

代价提醒：每项 `new SymbolGlyphModifier` 会多一次资源解析。
**纯文本菜单（无图标需求）就别加图标**——用户 Icey 2026-09-11 明确定过这条：
「menu这些都别加图标了 浪费资源」。只有**需要视觉区分类别/危险动作**时才用图标。

### 坑 4：MenuItem 的 `onChange` 不是点击回调

`MenuItem.onChange(callback: (selected: boolean) => void)` 是**选中态变化**
（配合 `selectIcon` 的单选语义）。写在 `onChange` 里点击**毫无反应**。

正解用 `.onClick(...)`（继承自 `CommonMethod`），并在里面主动关菜单：

```ets
try { this.getUIContext().getContextMenuController().close(); } catch (_) {}
```

不关的话浮层会留在屏幕上（尤其点击项本身不改变页面时，看起来像"卡住了"）。

### 坑 5：`ContextMenuOptions.borderRadius` 不吃 `LengthMetrics`

```ets
borderRadius: LengthMetrics.vp(12)   // ❌ Type 'LengthMetrics' is not assignable to
                                     //    'Length | BorderRadiuses | LocalizedBorderRadiuses'
borderRadius: 12                     // ✅
targetSpace: LengthMetrics.vp(4)     // ✅ targetSpace 才是 LengthMetrics
```

同一份配置里两个圆角/间距字段类型不同，容易一起写错。

## 数据驱动：不要往 @Builder 里塞 if/else

菜单项随行状态变化（已改动→撤销 / 已删除→恢复 / 是归档→作为归档打开）。
把这些判断放进 `@Builder` 会让模板分支爆炸且难维护。

**做法**：定义一个轻量类 + 父组件返回数组，`@Builder` 只做 ForEach。

```ets
export class RowAction {
  label: string = '';
  icon: Resource | null = null;   // null = 该行不显示图标
  danger: boolean = false;        // true → 红色文字
  enabled: boolean = true;
  action: () => void = () => {};
  constructor(label, icon, danger, enabled, action) { /* 逐字段赋值 */ }
}
```

父组件：

```ets
private actionsOf(row: EntryRow): RowAction[] {
  const items: RowAction[] = [];
  if (row.removed) {
    items.push(new RowAction('恢复', $r('sys.symbol.arrow_clockwise'), false, true, () => ...));
  } else {
    items.push(new RowAction('移除', $r('sys.symbol.trash'), /*danger*/true, true, () => ...));
  }
  return items;
}
```

ArkTS 注意：类字段**必须有初始化器**（`label: string = ''`），否则 `arkts-strict-property-initialization` 报错。
构造参数建议显式标类型，避免 `arkts-no-implicit-any`。

## 与危险操作确认弹窗配合

菜单里的「移除」不应该直接执行——先弹确认：

```ets
new RowAction('移除', $r('sys.symbol.trash'), true, true, () => { this.confirmRemove(path); })
```

确认弹窗用 `promptAction.showDialog({ buttons: [...] })`，
⚠️ 其 `buttons` 是**定长元组** `[Button, Button?, ...]`，动态数组无法赋值，
需要包一层工厂函数产出 `promptAction.Button` 字面量（见 `UiKit.dialogButton`）。

## 相关符号（已在本机 id_defined.json 核对存在）

`trash` `arrow_clockwise` `arrow_counterclockwise` `doc_zipper` `doc_zipper_fill`
`folder` `folder_fill` `doc_plaintext` `chevron_right` `xmark` `checkmark_circle_fill`
`exclamationmark_message` `info_circle` `archivebox` `archivebox_fill` `magnifyingglass`
`open_sidebar` `close_sidebar` `line_3_horizontal` `list_bullet` `square_and_arrow_down`

⚠️ 不存在的（不要写）：`sidebar_left` `tablecells` `textformat_size` `doc_on_doc` `square_and_arrow_up`
（查权威清单：`sdk/default/openharmony/toolchains/id_defined.json` 里 `type == 'symbol'` 的条目）

## 验证方式

```bash
# 编译（必须成功才算数）
hvigorw --mode module -p product=default -p module=entry@default -p buildMode=debug \
  default@CompileArkTS --no-daemon

# 真机安装 + 截图确认浮层样式
hdc install -r entry/build/default/outputs/default/entry-default-signed.hap
hdc shell "aa start -b <bundleName> -a EntryAbility"
hdc shell "snapshot_display -f /data/local/tmp/s.jpg"
MSYS_NO_PATHCONV=1 hdc file recv "/data/local/tmp/s.jpg" "./s.jpg"   # Git Bash 必须禁路径转换
```
---

# 配套规范（同一轮实战沉淀，Icey-Archive 2026-11-17）

## 一、千项级列表性能：三件事缺一不可

| 手段 | 代码 | 作用 |
|---|---|---|
| `LazyForEach` | `LazyForEach(ds, (row) => {...}, (row) => row.id)` | 只建视口 + 缓存区节点 |
| `reuseId` | `ListItem() {...}.reuseId('archive_entry')` | **组件复用**：滚动时回收重建，节点数压到视口量级 |
| `cachedCount` | `.cachedCount(6)` | 预建缓存区条数；太小滚动白屏，太大费内存 |

只写 LazyForEach **不算做完**——缺 `reuseId` 时每滚一屏都要新建组件实例
（1296 条目的层实测明显掉帧，加 reuseId 后顺滑）。

配套视觉（都只是一行）：
```ets
.edgeEffect(EdgeEffect.Spring)   // 弹簧回弹
.chainAnimation(true)            // 联动链条动画
.fadingEdge(true)                // 上下边缘渐隐（暗示还有内容）
```

## 二、长任务用**全屏模态遮罩**，不要底部条

为什么：解压 16 MB 要数秒，期间若用户还能点列表，会**重复触发同一操作**
（实测：卡住时连点几下「作为归档打开」，之后一串 toast 一起冒出来）。

```ets
// 状态驱动：store 只维护三个 AppStorage 键
AppStorage.setOrCreate<boolean>('archiveProgressShow', true);
AppStorage.setOrCreate<string>('archiveProgressText', '正在解压嵌套归档…');
AppStorage.setOrCreate<number>('archiveProgressValue', 0);  // -1 = 不确定态转圈

// UI 层（Index 最外层）用 bindContentCover 呈现 → 盖住标题栏和 tabBar
.bindContentCover(this.progressShow, this.progressOverlay(), {
  modalTransition: ModalTransition.NONE,
})
```

⚠️ **不要试图在普通类里用 `promptAction.openCustomDialog` 弹进度**：
它的 `builder` 参数要求 `CustomBuilder`（组件内 `@Builder`），普通类拿不到该能力
（`wrapBuilder(X)` 返回的是 `WrappedBuilder`，类型不匹配；`X(...).builder()` 也不是合法调用）。
更彻底的做法就是 `bindContentCover` + 状态键，UI 层渲染。

**最短展示时长**：关掉遮罩前保证至少显示 420ms，否则"闪一下就没"会让用户以为没执行。

## 三、成千上万张图的缩略图：中心队列 + 并发闸门

批量生成缩略图**必须**限并发，否则 `LazyForEach` 首帧会连续创建上千行、
每行都触发一次解压 → 任务把线程池打满 + 内存暴涨 → 页面直接卡死
（实测进入 1291 个 png 的层整页冻结，抓栈停在 `listRows`）。

**不要用"行内定时器重试"**：次数定小了覆盖不全（实测滚一屏只有 3 个出图），
定大了就是上千个并发定时器。正解是**中心队列**：

```ets
private static jobs: ThumbJob[] = [];
private static running: number = 0;

static request(name, loader, done) {
  if (cached) return done(cached);
  if (inflight.has(k) || isQueued(name)) return;
  jobs.push({key, name, loader, done});
  this.pump();                    // 按 MAX_CONCURRENT(=2) 持续消化
}
static cancel(name) { /* 行滚走时移除请求，不做无用功 */ }
static clearQueue() { /* 换层时清空：旧位置的图没人要了 */ }
```

配套两个必须做的筛选：
- **后缀白名单**（jpg/png/webp…）——归档里绝大多数成员不是图片，先筛掉绝不尝试解码
- **大小上限**（如 4 MB）——大图解码收益不值得等待

## 四、每层目录 = 独立路由页（对齐系统文件管理）

不要再"一个页面 + if 切当前层"，改为**每进一层 push 一个 NavDestination**：

**收益**：
- 返回手势/返回键**由 HdsNavigation 栈自动 pop**，不用手写 `onBackPress`，
  也不会漏掉侧滑返回、`popToIndex` 等路径（手动维护状态必然漏）
- 每层有独立标题栏，可直接显示当前目录名
- 层生命周期清晰

```ets
// 分发
@Builder
navDestinationBuilder(name: string, param: Object) {
  if (name === ROUTE_BROWSER) {
    HdsNavDestination() {
      ArchiveBrowserPage({ dirTitle: (param as BrowserParam).title })
    }
    .titleBar(buildSubPageTitleBar((param as BrowserParam).title))
    .titleMode(100)                 // HdsNavDestinationTitleMode.MINI
    .ignoreLayoutSafeArea([0], [0])
    .onBackPressed((): boolean => {
      // true = 拦截本次返回（如需弹"合并/丢弃"确认，用户选完自己 pop）
      return store.confirmLeaveOnBack();
    })
  }
}
```

⚠️ **路由 param 绝不能放大数据**：`NavPathInfo` 的 param 会被路由栈长期持有
（18 MB 的归档字节塞进去直接吃满内存，且栈回退时不释放）。
只带展示用的字符串（目录名 + 去重 key），业务状态全部留在单例 store 里。

⚠️ 去重检查别用 `${param}` 比较对象——永远得到 `[object Object]`，
会导致所有目录都被判成"重复"。要么传带 `key` 的类并比较 `key`，
要么干脆不做去重（目录导航本来就该允许同名不同层）。

## 五、面包屑：做成胶囊条，别裸写文字

裸 `Text` 贴在标题栏下会显得像"没做完的草稿"。参照系统文件管理的做法：

```ets
Row() {
  Scroll() { Row({ space: 6 }) { SymbolGlyph(folder_fill); Text(crumb) } }
    .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).layoutWeight(1)
}
.height(36)
.padding({ left: 12, right: 12 })
.backgroundColor(isDark ? '#1C1C1E' : '#F2F3F5')
.borderRadius(18)        // 胶囊
```

要点：**包在圆角容器里** + **横向可滚**（长路径不换行不挤压）+ 单行省略。
右侧不要再放"上一层"按钮——返回手势/返回键已能做，冗余。

## 六、顶部避让：统一由容器 padding 承担

踩过两次：
- **面包屑不能作为 Stack 浮层**贴在标题栏上（会落进标题栏内部，与大标题重叠）
- **单个页面里多处各算留白**必然打架

正解：内容根 `Column` 统一 `.padding({ top: SafeArea.top + 56 })`
（56 = MINI 标题栏高度），面包屑与列表都在这层 padding 之下自然排布。
**Stack 的子组件不支持 `layoutWeight`**（不参与 Flex 分配），高度必须显式 `height('100%')`，
否则"打开成功、toast 正常、页面一片空白"。

## 七、图片成员直接渲染 PixelMap，不要导出临时文件

图片已经在内存里（刚解压出来），最短路径是直接交给 `Image` 组件：

```ets
const src = image.createImageSource(bytes.buffer.slice(byteOffset, byteOffset + byteLength));
this.image = await src.createPixelMap({
  desiredSize: { width: 1600, height: 1600 },   // 限边长，避免 4K 图吃满内存
  desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
});
await src.release();   // 必须释放，它持有 native 资源

// 渲染
Image(this.image).width('100%').constraintSize({ maxHeight: 360 }).objectFit(ImageFit.Contain)
```

不要去"写临时文件 → 拉起系统图库"：多一次写盘 + 跨应用跳转，还得分神清理临时文件。
图片预览不受文本的 `MAX_EDIT_BYTES` 限制（解码目标尺寸已限死，内存可控）。

## 八、系统分享用 ShareKit，不是 CoreFileKit

```ets
import { systemShare } from '@kit.ShareKit';   // ⚠️ 不是 @kit.CoreFileKit
const data = new systemShare.SharedData({ utd: 'general.plain-text', content: '...' });
new systemShare.ShareController(data).show(ctx, {
  previewMode: systemShare.SharePreviewMode.DETAIL,
  selectionMode: systemShare.SelectionMode.SINGLE,
});
```
导错 Kit 会报 `has no exported member 'systemShare'`（它在 HMS 扩展 `@hms.collaboration.systemShare`）。

## 九、调试真机的省时做法（避免来回点屏幕）

用 `uitest` 精确点击 + 自动化脚本，别靠肉眼估坐标：

```bash
# 1. dump 布局，取元素真实 bounds
hdc shell "uitest dumpLayout -p /data/local/tmp/d.json"
MSYS_NO_PATHCONV=1 hdc file recv "/data/local/tmp/d.json" ./d.json
# 2. 从 bounds 算中心点，再点
hdc shell "uitest uiInput click <x> <y>"
# 3. 截图（必须禁路径转换，否则 Git Bash 会把 /data/... 当 Windows 路径）
hdc shell "snapshot_display -f /data/local/tmp/s.jpg"
MSYS_NO_PATHCONV=1 hdc file recv "/data/local/tmp/s.jpg" ./s.jpg
```

关键：**bounds 才是可信坐标**，标题栏高度/状态栏高度随设备与通知图标变，
硬编码 y 坐标必然点空（点空后常见后果是把通知栏拉下来，误判成"应用没响应"）。
