# 标准工程副本（harmony-standard）

> **定位**：下一代「标准工程」v2 草案——从 Icey-Player-Harmony 提炼的**基建全集**（模型/服务/组件比
> `assets/template` v1.4 更完整）。2026-11-01 由 Harmony-Standard 会话的中断态抢救入库，**未替换** v1.4
> 模板（两者并存：v1.4 = 已验证的最小模板；本目录 = 组件更全的新一代骨架）。
> 来源会话的原文件夹已废弃（非 git 仓库、无第二副本），本副本为唯一留存。

## 编译状态

✅ **hmos-clt `default@CompileArkTS` 全绿**（2026-11-01，13 tasks / 4 executed；构建命令见
`references/harmony-offline-verify.md` §0c）。产物已核验（`layout/Index.ts` 含自检页符号，非假通过）。
依赖为**空**（`oh-package.json5` 无三方包，无 Hds——Index 自检页用原生 ArkUI 组件）。

## 与 `assets/template`（v1.4）的差异

| | v1.4 template | 本目录（standard） |
| --- | --- | --- |
| SettingsManager | 173 行 | **518 行**（单例 + init/waitReady 门闸 + 300ms 防抖 + saveNow + 自定义背景双槽位 + 材质全套） |
| SheetContainer | 123 行 | **620 行**（渐变模糊全套） |
| SafeArea | 40 行 | 165 行（挖孔合并/横屏） |
| ThemeManager | 106 行 | 180 行 |
| SubPageScaffold | 103 行 | 175 行 |
| 组件 | ConfirmSheet/MaterialCard/OptionSheet | **MaterialLayer / SettingItem / SettingsGroup / SettingsGroupCard / AppSwitch / GlassCard / MarqueeText / EmptyState / AppSheet / SheetContainer / SubPageScaffold / ArrayDataSource** |
| services | — | AppLogger / AppGlobalContext / ChangelogManager / FormatUtils / SheetManager / WindowHelper |
| model 增量 | — | **DeviceProfile**（设备形态） |

## 入库时修复的三处（源会话中断遗留，均已验证）

1. **`AppScope/resources/base/element/string.json` 缺失** ⇒ `app.json5` 的 `$string:app_name` 未定义，
   `CompileResource` 报 11211120。已从 v1.4 模板补入。
2. **EntryAbility 4 处静态调用改 `getInstance()`**：`init/waitReady/saveNow` 在 SettingsManager 里是
   **实例方法**（applyColorMode 才是静态），静态调用报 10505001 `Property 'init' does not exist on type
   'typeof SettingsManager'`。
3. **新建 `layout/Index.ets`**（App.ets 引用但文件缺失 ⇒ Rollup `Could not resolve "./layout/Index"`）：
   组件自检页（主题模式菜单 / 屏幕常亮开关 / 沉浸光感档位，全部走设置七件套 + @StorageLink 响应式）。
   ⚠️ 写它时踩了本库铁律：**自定义组件尾随闭包之后不能链式挂属性**（SettingsGroupCard 外包 Column 承接
   margin，见 `harmony-arkts-lint-fix.md`）。

## 未入副本的内容（均已确认无损）

- `SettingsManager.ets.source-ref`：提炼时的参照源，与 Icey-Player-Harmony 现版 `model/SettingsManager.ets`
  **字节一致**（原件在那边）。
- 空目录：`pages/`、`components/ChangelogSheet/`、`signing/`、`docs/`、`tools/`、`AppScope/.../element/`（空目录 git 无法跟踪）。
- 会话壳 `.dsh/` `.workbuddy/` `skill-sync/` 与构建产物 `entry/build/` `.hvigor/`。

## 使用方式

整目录拷出 → 改 `AppScope/app.json5` 的 `bundleName`/`versionName` → 用 `layout/Index.ets` 换成真实首页
（App.ets 的 `Index()` 挂载点、窗口广播/主题初始化全部不用动）→ 按 SettingsManager 文件头的
「新增设置项七件套」扩设置。
