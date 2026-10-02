# 工作流代码库（harmony-app-template）

> 主文件：SKILL.md §3。本文件放**可直接复制使用**的完整代码。
> 所有路径以 `<ETS>` = `entry/src/main/ets` 简写。

---

## W1：从模板新建项目

> 模板**随 Skill 自带**，换机器无需另外找工程。路径 = `<skill>/assets/template/`。

```bash
# 1. 复制内置模板到新工程目录（务必复制，不要就地改模板副本）
cp -r <skill>/assets/template <新工程根>
cd <新工程根>

# 2. 【必做，否则编译失败】按 SKILL.md 附录 C 修 D1~D4 四个已知缺陷
#    D1  SettingsManager.getInstance() → 改静态直调（8 处）
#    D2  EntryAbility.ets 补 import { WindowHelper }
#    D3  SettingsManager.init() 补 handedness / materialLevel 的 getSync 读回
#    D4  entry 模块 layered_image 引用缺失的 background/foreground → 补图或删 entry 级 json

# 3. 改应用身份（两处必改）
#    AppScope/app.json5:  bundleName / vendor / versionCode / versionName
#    AppScope/resources/base/element/string.json: app_name

# 4. DevEco Studio 打开新工程 → 自动关联 SDK → build
```

> 💡 内置副本已排除 10MB 的可选图标字体（`rawfile/fonts/sficons_harmony.ttf`）——
> SFIcon 走 SVG 渲染，模板代码对它零引用，不影响构建。需要时从原工程拷回即可。
> 完整清单见 `../../assets/TEMPLATE_MANIFEST.md`。

`AppScope/app.json5`：

```json5
{
  "app": {
    "bundleName": "com.yourcompany.yourapp",
    "vendor": "yourcompany",
    "versionCode": 1,
    "versionName": "1.0.0",
    "icon": "$media:layered_image",
    "label": "$string:app_name"
  }
}
```

### 裁剪清单（不需要就删）

| 要删的能力 | 删哪里 |
|---|---|
| 迷你播放条 | `layout/Index.ets` 的 `miniBar: {...}` 整个配置块 + `miniBarPlaceholder()` + `tabBarCollapsed` 相关判断 |
| 自定义背景 / 毛玻璃 | `GlassCard` / `SettingsGroup` / `SettingsGroupCard` / `SubPageScaffold` 里的 `customBgUri` 判定（保留实色分支） |
| 更新日志 | `services/ChangelogManager.ets` + `AboutPage` 对应 SettingItem + `EntryAbility` 的 init 调用 + `rawfile/changelog.txt` |
| 运行日志 | `services/AppLogger.ets` + `AboutPage` 日志弹窗 + `EntryAbility.init`（注意 SettingsManager 内部也在用 AppLogger，删之前先 grep） |
| 文件授权 | `services/FilePermission.ets` + `module.json5` 的 `FILE_ACCESS_PERSIST` 权限 |
| 图标字体 | `rawfile/fonts/sficons_harmony.ttf`（约 10MB，SFIcon 走 SVG 不依赖它） |

> ⚠️ 删任何 service 前先 `grep -rn "<ServiceName>" <ETS>/` 确认没有跨模块引用。

---

## W2：新增底部 Tab

只改 `layout/Index.ets` 三处：

```typescript
const TAB_COUNT = 3;                                    // ① +1（建议 2 < N ≤ 5）
private readonly tabTitles: string[] = ['首页', '发现', '设置'];  // ② 加标题
```

```typescript
// ③ 在 HdsTabs 内插入新 TabContent（放在「设置」之前）
TabContent() {
  DiscoverTab({ themeVersion: this.themeColorsVersion })
}
.backgroundColor(Color.Transparent)                      // 必须显式透明（铁律 #15）
.tabBar(this.TabItemBuilder(1, SFIcons.sf_tab_discover,
  SFIcons.sf_tab_discover_fill, '发现'))
```

并调整后续 Tab 的 index（0/1/2 连续）。`TabItemBuilder` 已内置选中态双图标 + 折叠态只显图标，无需改动。

### W2+：底栏中央「+」FAB 按钮（HdsTabs 标准方案，LSN-010）

需求：「+」按钮内嵌底栏正中央，点击弹新增弹窗（不切页）。**禁止**隐藏自带 bar + 自绘底栏 + Stack 叠加（用户已否决此方案）。

```typescript
const ADD_TAB_INDEX: number = 2;  // 「+」占位页签 index（N+1 页签中的正中位）

// ① HdsTabs 内：空 TabContent 占位，tabBar 返回红钮 builder
TabContent() {
}
.backgroundColor(Color.Transparent)
.tabBar(this.AddButtonBuilder())

// ② HdsTabs 属性链：拦截切换 + 点击弹窗
.onChange((index: number) => { this.currentIndex = index; })
.onContentWillChange((currentIndex: number, comingIndex: number): boolean => {
  return comingIndex !== ADD_TAB_INDEX;   // false = 阻止切到「+」
})
.onTabBarClick((index: number) => {
  if (index === ADD_TAB_INDEX) { this.openAddSheet(); }
})

// ③ 红钮页签项（44vp 圆钮；padding 必须与 TabItemBuilder 同级——
//    其他项 padding({bottom:4}) 使重心偏上，红钮不带会低 2vp；仍差 1vp 则上 6）
@Builder
AddButtonBuilder() {
  Column() {
    Row() {
      SFIcon({ name: SFIcons.sf_plus, fontSize: 22, fontColor: '#FFFFFF' })
    }
    .width(44).height(44).borderRadius(22)
    .backgroundColor(ThemeManager.colors.accent)
    .justifyContent(FlexAlign.Center)
    .shadow({ radius: 8, color: '#33000000', offsetY: 2 })
  }
  .width('100%').height(56)
  .justifyContent(FlexAlign.Center)
  .alignItems(HorizontalAlign.Center)
  .padding({ bottom: 6 })
}
```

**注意**：① TabContent 数变化后，**所有按 index 取值的地方**同步改：后续页签的 `TabItemBuilder(index)` 参数（选中高亮靠 `currentIndex===index`）+ **`tabTitles` 数组**（标题栏 `tabTitles[currentIndex]`，占位 index 填空串——漏补则后段标题错位/末项越界）；改完 `grep -rn "currentIndex\]\|TabItemBuilder("` 全查一遍；② 自带 bar 需恢复标准悬浮配置（`barMode(BarMode.Fixed)` + `barHeight(56)` + `barOverlap(true)` + `barFloatingStyle`），不能再 `barHeight(0)`。

---

## W3：新增子页 + 路由（四步）

### ① 建页面组件 `pages/subPages/XxxPage.ets`

```typescript
import { SafeArea } from '../../model/SafeArea';
import { ThemeManager } from '../../model/ThemeManager';
import { SubPageScaffold } from '../../components/SubPageScaffold/SubPageScaffold';
import { SettingsGroupCard } from '../../components/SettingsGroupCard/SettingsGroupCard';
import { SettingItem } from '../../components/SettingItem/SettingItem';

@Component
export struct XxxPage {
  build() {
    SubPageScaffold({ title: '页面标题' }) {
      List({ space: 0 }) {
        // 顶部留白（禁硬编码 112）
        ListItem() { Blank().height(SafeArea.top + 64).width('100%') }

        ListItem() {
          SettingsGroupCard({ title: '分组名' }) {
            Column() {
              SettingItem({
                title: '设置项一',
                subtitle: '说明文字（最多两行）',
                onTap: () => { /* TODO */ },
              })
              // 项间分隔线手动插（Column 无 divider 属性）
              Divider()
                .strokeWidth(0.5)
                .color(ThemeManager.colors.divider)
                .margin({ left: 12, right: 8 })
              SettingItem({ title: '设置项二', onTap: () => {} })
            }
            .width('100%')
          }
        }

        // 尾部留白
        ListItem() { Blank().height(SafeArea.bottom + 40).width('100%') }
      }
      .layoutWeight(1)                                   // 铁律 #05：不用 height('100%')
      .width('100%')
      .scrollBar(BarState.Off)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      .edgeEffect(EdgeEffect.Spring)
      .backgroundColor(Color.Transparent)
    }
  }
}
```

### ② 加路由常量 `model/AppRouter.ets`

```typescript
export const ROUTE_XXX = 'xxx';
```

### ③ 加分发 `layout/Index.ets`

```typescript
@Builder
navDestinationBuilder(name: string, param: Object) {
  if (name === ROUTE_HOME_DETAIL) {
    HomeDetailPage()
  } else if (name === ROUTE_XXX) {          // ← 新增
    XxxPage()
  } else if (name === ROUTE_SETTINGS_SUB) {
    SettingsSubPage()
  } else if (name === ROUTE_ABOUT) {
    AboutPage()
  }
}
```

同时在 Index 顶部 import 新页面。

### ④ 调用

```typescript
AppRouter.getInstance().push(ROUTE_XXX);              // 无参
AppRouter.getInstance().push(ROUTE_XXX, { id: '123' }); // 带参
AppRouter.getInstance().pop();                        // 返回
```

子页读参数：

```typescript
aboutToAppear(): void {
  const p = AppRouter.getLastParam() as Record<string, string> | null;
  const id = p ? p['id'] : '';
}
```

> AppRouter 内置**重复页拦截**：栈中已存在同 name（带参页还要求同参）→ toast「页面已打开」且不重复入栈。

---

## W4：新增持久化设置项（五步，漏③重启必丢）

以布尔开关 `mySwitch` 为例，改 `model/SettingsManager.ets`：

```typescript
// ① KEY 常量
const MY_SWITCH_KEY = 'settings_mySwitch';

// ② SettingsRecord 字段 + 默认值
interface SettingsRecord {
  mySwitch: boolean;
  /* ... */
}
private static rec: SettingsRecord = {
  mySwitch: false,
  /* ... */
};

// ③ 【最容易漏】init() 里读回
r.mySwitch = SettingsManager.pref.getSync(MY_SWITCH_KEY, r.mySwitch) as boolean;

// ④ fillAppStorage() 回填
AppStorage.setOrCreate<boolean>('settings_mySwitch', SettingsManager.rec.mySwitch);

// ⑤ setter
static setMySwitch(v: boolean): void {
  SettingsManager.rec.mySwitch = v;
  AppStorage.setOrCreate<boolean>('settings_mySwitch', v);
  SettingsManager.save(MY_SWITCH_KEY, v);
}
```

UI 侧：

```typescript
@StorageLink('settings_mySwitch') mySwitch: boolean = false;

SettingItem({
  title: '我的开关',
  subtitle: '持久化，重启保持',
  isSwitch: true,
  switchValue: this.mySwitch,
  onSwitch: (v: boolean) => { SettingsManager.setMySwitch(v); },
})
```

**自检**：`grep -n "MY_SWITCH_KEY" model/SettingsManager.ets` 应 ≥ 2 处（定义 + setter），
`grep -n "mySwitch" model/SettingsManager.ets` 应 ≥ 5 处。

> ⚠️ 调用范式铁律：`SettingsManager` 是**纯静态类**，写 `SettingsManager.setMySwitch(v)`，
> **不要**写 `SettingsManager.getInstance()`（模板模板版里存在 8 处这种误写，见 SKILL.md 缺陷 D1）。

---

## W5：新增弹窗（三选一）

### A. 通用底部弹窗（推荐，自动适配宽屏）

```typescript
import { AppSheet } from '../../components/AppSheet/AppSheet';
import { SheetContainer } from '../../components/SheetContainer/SheetContainer';

@State showXxxSheet: boolean = false;

// build() 内：
AppSheet({ show: this.showXxxSheet, group: 'page:xxx' }) {
  SheetContainer({ title: '弹窗标题' }) {
    Column() {
      SettingItem({ title: '选项一', onTap: () => { this.showXxxSheet = false; } })
    }
    .width('100%')
  }
}
```

参数要点：
- `group`：同组互斥（根级用 `'index'`，页面级用 `'page:xxx'`）；嵌套弹窗**留空或换组**
- `dismissible: false`：不可手关闭（导入进度等，仅由外部 `show=false` 关闭），且退后台不自动关
- `detents`、`showClose` 仅 bindSheet 生效；宽屏走 420vp 居中 dialog

### B. 二次确认（危险操作）

```typescript
@State showConfirm: boolean = false;

ConfirmSheet({
  show: this.showConfirm,
  title: '删除',
  message: '删除后不可恢复，确认继续？',
  confirmText: '删除',
  danger: true,                                  // 红色 ERROR 按钮
  onConfirm: () => { /* 执行 */ },
  onDismiss: () => { this.showConfirm = false; },
})
```

### C. 选项列表

```typescript
private optionController: CustomDialogController = new CustomDialogController({
  builder: OptionSheet({
    title: '选择音质',
    options: [
      { label: '标准', selected: this.quality === 0, onTap: () => { this.setQuality(0); } },
      { label: '高清', selected: this.quality === 1, onTap: () => { this.setQuality(1); } },
    ],
  }),
  autoCancel: true,
  alignment: DialogAlignment.Bottom,
});
// this.optionController.open();
```

> ⚠️ OptionSheet 内的 label/selected 是**快照**（`@CustomDialog` 不会自动刷新），
> 每次 open 前需重建 controller 取最新值（参考 `ConfirmSheet` 的 `@Monitor('show')` 写法）。

---

## W6：新增图标

```bash
# 1. SVG 放 ETS 同级资源目录
cp my_icon.svg <entry>/src/main/resources/base/media/my_icon.svg
```

SVG 要求：`viewBox="0 0 24 24"`，路径归一化在 0~24，fill 用黑色（由 `fillColor` 动态变色）。

```typescript
// 2. components/SFIcon/sficon_names.ets 加一行
static readonly sf_my_icon: string = 'my_icon';
```

```typescript
// 3. 使用
SFIcon({ name: SFIcons.sf_my_icon, fontSize: 22, fontColor: ThemeManager.colors.tabBarActive })
```

Tab 图标必须**两套**（常态 + 填充态），例如 `tab_music.svg` / `tab_music_fill.svg`。
系统符号另有一套： `SymbolGlyph($r('sys.symbol.chevron_right'))`，优先用它做箭头等通用图形。

---

## W7：接入自定义背景 / 毛玻璃

```typescript
// 主题侧：让 background 变半透明由背景图透出
ThemeManager.applyThemeMode(themeMode, systemColorMode, true /* hasCustomBg */, customBgIsLight);
AppStorage.setOrCreate<string>('settings_customBgUri', uri);
AppStorage.setOrCreate<boolean>('customBgLoaded', true);
```

卡片容器已内置判定，**新增卡片照抄即可**（不要写自己的判断逻辑）：

```typescript
.backgroundColor(this.customBgUri ? Color.Transparent : ThemeManager.colors.cardBg)
.backgroundBlurStyle(this.customBgUri ? BlurStyle.COMPONENT_REGULAR : BlurStyle.NONE)
```

命名/圆角体系统一：**圆角 20，上下 padding 6（有标题 3），左右 1，`.clip(true)`**。

---

## W8：排障（五层模型）

```
第 1 层 源码：改的文件是不是实际渲染的那个？（grep 类名/关键词确认唯一来源）
第 2 层 编译产物/缓存：safe-delete → 删 <entry>/build/default/cache/default/default@CompileArkTS，
                       前台串行 --no-daemon 重建
第 3 层 工具：DevEco 打开的是不是这个目录？设备上装的是不是最新包？
第 4 层 环境：SDK compatibility 与目标设备 API 是否匹配（模板 23~26）
第 5 层 改动本身：是否违反了 §2 某条铁律？（布局类问题优先查 #05~#14）
```

### 现象 → 根因速查

| 现象 | 优先排查 |
|---|---|
| 页面底部溢出 / 内容出屏 | 铁律 #05（height 100%）、#06（layoutWeight+SpaceBetween） |
| 顶部一条白/黑带 | 铁律 #11~#14 四处配套缺其一 |
| 卡片贴着标题栏 / 被模糊带压住 | #08 留白写法错、#14 maskExtraHeight 过大 |
| 自定义背景「发灰」「被压暗」 | #15 Hds 逐层缺透明 |
| 弹窗能看见底层内容 | #20 用了半透明 background 而非 opaqueBackground |
| 主题切换后界面不变 | #19 没订阅 themeColorsVersion |
| 开关重启回默认 | LSN-003 五步漏了 init 读回 |
| hvigor `[safe-delete]` | #37 清缓存 + 串行重建 |
| 「页面已打开」toast 但没跳转 | AppRouter 重复页拦截生效（预期行为，不是 bug） |

---

## 通用收尾检查（每个工作流都要做）

1. 前台串行构建一次（`hvigorw ... --no-daemon`），**禁止并行构建**
2. 真机安装运行，用 `hilog` 过滤模块 TAG 验证
3. `grep -rn` 确认改动涉及的模式在所有引用处都同步了（LSN-001）
4. 更新 `rawfile/changelog.txt`；若随版本发布，同步 `AppScope/app.json5` 的 versionCode + versionName
