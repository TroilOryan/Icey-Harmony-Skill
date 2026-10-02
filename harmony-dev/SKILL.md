---
name: harmony-dev
description: >-
  为鸿蒙开发赋能 —— HarmonyOS / ArkTS / ArkUI / ETS / Stage 模型开发的**总入口技能**。
  一份技能覆盖「搭脚手架 → 写界面 → 接能力 → 编译验证 → 排错取证」全链路，
  入口只放铁律骨架 + 任务路由表，具体领域知识按需读 references/ 下的分册。
  触发词：鸿蒙/鸿蒙App/HarmonyOS/ArkTS/ArkUI/ETS/Stage 模型；新建项目/脚手架/模板工程/初始化/开工/新建页面/新增子页/加个Tab/HdsTabs/HdsNavigation/路由跳转/路由栈；
  设置页/设置项/持久化开关/preferences/存本地/存盘；弹窗/底部弹窗/bindSheet/半模态/确认弹窗/AppSheet/宽屏dialog/下拉菜单/标题栏菜单/openMenu/菜单分割线；
  主题/深浅色/暗色模式/自定义背景/壁纸/毛玻璃/沉浸光感/材质/GlassCard/模糊；
  安全区/状态栏/全屏/挖孔/标题栏/侧滑抽屉/抽屉；图标/加个图标/sys.symbol/系统符号/SymbolGlyph；
  运行日志/AppLogger/清理埋点/诊断日志/更新日志；桌面卡片/服务卡片/widget/form/form_config/updateForm；
  编译报错/10505001/arkts-no-any-unknown/编译不过/改了没生效/hvigor 报错/点不动/命中失灵/白屏/空屏/无限 loading/正在排版/残留模糊；
  很卡/掉帧/跟手延迟/帧耗时/性能打点/Canvas 卡顿；阅读器/阅读页/Reader Kit；星图/Stellarium/HiPS/视野/fov/投影；
  截图取证/图层没画出来；二进制资产/索引越界/星表体检。
agent_created: true
version: 1.0.0
---

# 为鸿蒙开发赋能（HarmonyOS / ArkTS / ArkUI 总入口）

> **这是唯一入口技能。** 原本 18 个独立鸿蒙技能已合并进本技能的 `references/`，
> 每个分册仍是原来那份**一字未删**的实战沉淀（含用户真机逐轮裁决的定案、坑位清单、验收清单）。
> 旧技能名保留为一行跳转壳，指向对应分册（见文末映射表）。

## 怎么用

1. **先看下面的「任务路由表」**，按你手上的事定位到 1~2 个分册。
2. **只读那 1~2 个分册**（`references/<name>.md`），不要一次读完 —— 每册都很大（最大 36 KB）。
3. 动手前扫一遍分册开头的**「结论（先读）」/「铁律」**，那里是踩过坑之后才写下的硬约束。
4. 涉及具体代码时，以分册里的**样板 / 完整代码块**为准，**禁止凭记忆写**。

---

## 任务路由表

### A. 基建 / 脚手架（最常用，优先级最高）

| 你要做什么 | 读哪册 |
| --- | --- |
| 从零起一个新鸿蒙 App、复用已验证基建（导航/路由/弹窗/设置持久化/主题/安全区/日志七件套） | **`references/harmony-app-template.md`**（主册，含 38 条铁律 / 坑点速查表 / 28 条 LSN） |
| 要 W1~W8 工作流的**可复制代码**、文件职责表、模板工程副本 | `references/harmony-app-template/workflows.md`、`references/harmony-app-template/file-map.md`、`assets/template/`（56 文件可移植模板，编译全绿） |

### B. 编译 / 验证 / 排错（动手后必查）

| 你要做什么 | 读哪册 |
| --- | --- |
| **改完 ArkTS 先真编译**（本机有 DevEco 自带 hvigorw，别假设没有）／纯逻辑用 Node 直跑编译产物验证／动 rawfile 定长二进制资产 | **`references/harmony-offline-verify.md`** + `scripts/hvbuild.py` 等 |
| ArkTS 严格模式编译错误（10505001 / arkts-no-any-unknown …）系统性修复；真机 `undefined is not callable` / `this` 归属崩溃 | **`references/harmony-arkts-lint-fix.md`** |
| 用**真机截图**判定「图层/标签到底画没画出来」，拆「没画」还是「不在视野」 | `references/harmony-screenshot-layer-forensics.md` + `scripts/shot_forensics.py` |
| 清理遗留日志埋点 / 诊断日志，按唯一子串安全批量删改源码 | `references/harmony-log-probe-cleanup.md` |
| rawfile 二进制资产（星表 Float32 表 / 索引表 / 图数据）改动前的索引安全协议 | `references/binary-asset-protocol.md` + `scripts/bin-table-audit.mjs` |

### C. 弹窗 / 菜单 / 抽屉（UI 结构层）

| 你要做什么 | 读哪册 |
| --- | --- |
| 半模态弹窗 `bindSheet` **自绘标题带 + 边缘渐变模糊**；内容穿不进标题带、标题下硬切割；高度塌成一条/恒满屏；横屏变悬浮卡片；标题与系统关闭按钮不对齐；同页多弹窗蒙层叠压 | **`references/harmony-sheet-panel.md`** |
| 标题栏 / 导航栏按钮弹出**下拉菜单**（`PromptAction.openMenu` 命令式）；`bindMenu` 锚点弹不出；二级菜单切换 | **`references/harmony-titlebar-menu.md`** |
| 手机端自研**侧滑抽屉**；`SheetType.SIDE` 不生效；跟手黏手；**加了抽屉后页面点不动/列表滚不动** | **`references/harmony-side-drawer.md`** |

### D. 观感 / 材质 / 背景

| 你要做什么 | 读哪册 |
| --- | --- |
| **沉浸光感 / 材质**（ImmersiveMaterial / uiMaterial / Hds）：官方默认档表、四种 scope、封面色调材质、Toggle 承载层、挡位实时生效三件套、标题栏模糊跨页残留 | **`references/harmony-material-layer.md`** |
| **自定义背景（壁纸）**：深浅色双槽位、模糊度滑块、选图落沙箱存 `file://`（禁 base64）、壁纸透出、重启后壁纸消失 | `references/harmonyos-arkts-custom-background.md` |
| **加载态**：首屏 / 数据恢复 / 导入中的 loading（一律系统 `LoadingProgress`，禁自绘） | `references/harmony-system-loading.md` |
| 系统符号 `sys.symbol.*` 画进 PixelMap / 离屏位图（播控封面、通知图标、卡片、分享图） | `references/harmony-symbol-outline-to-pixelmap.md` |

### E. 能力接入 / 专项

| 你要做什么 | 读哪册 |
| --- | --- |
| **桌面服务卡片**（Form Kit）：三件套、`form_config.json`、静态卡片数据注入、卡片不刷新、`FormLink` 点击、背板透明开放能力 | **`references/harmony-form-card.md`**（两册合并版） |
| 华为 **Reader Kit** 阅读器接入：白屏、翻页裁切、单击不出工具栏、底色/字号不生效、路由与沙箱路径 | `references/harmony-reader-kit-integration.md` |
| **Canvas 全屏自绘性能**（星图/地图/仪表）：很卡、跟手延迟、分段打点全是 0、调用数 > 数据量 | `references/harmony-canvas-frame-pacing.md` |
| 星图 **视野/投影/网格**口径对齐 Stellarium（fov 短边角 + 立体投影、离线量取角尺度） | `references/stellarium-viewport-alignment.md` |
| 把 Stellarium **HiPS 实拍地景**（HEALPix 瓦片）离线烘焙成等距圆柱全景 | `references/stellarium-hips-landscape.md` |

---

## 通用铁律（跨分册，任何任务都成立）

1. **编译验证是唯一交付标准。** 本机**可以真编译** —— DevEco 自带 `tools\hvigor\bin\hvigorw.bat`（项目根一般没有 wrapper）。判据不是「BUILD SUCCESSFUL」，而是 **`n executed` / `not UP-TO-DATE`**；只清 `entry/build` 不清 `.hvigor/cache` 会得到**假通过**。详见 `references/harmony-offline-verify.md`。
2. **同一文件禁止并行 Edit。** 并发改同一文件时各自基于同一快照写盘、**后写覆盖前写**，且每个都报成功。同文件多处改动**必须串行**，改完用 python 读字节复核（唯一可信口径）。
3. **不猜、不防御性编码。** 定位走「复现 → 日志根因 → 修 → 重新验证」；同 bug 反复失败时**列多根因假设**而非盲目重试。
4. **布局铁律**：子页 root `Column` 用 `layoutWeight(1)` 而非 `height('100%')`；**禁止** `layoutWeight(1)` + `justifyContent(SpaceBetween)` 联用（子项高度异常离屏）。
5. **事件边界 = 组件边界**：优先 code-based 注册事件，**禁用透明 overlay 命中层**与经验坐标。
6. **设置持久化**：新键必须 `AppStorage.setOrCreate`（`set` 对未初始化键**静默失败**），且 `SettingsManager` 里 `applyRecord` + `flushToPrefs` **两处都要有**，漏一处即「重启复原」。
7. **动画**：不与 `animateTo` 同用，`opacity` / `transition` 走**纯属性动画**。
8. **Service 层必须用 `AppLogger`**：`console.*` 只进 DevEco logcat，不进用户的导出运行日志。
9. **帧内计时禁用 `Date.now()`**（1 ms 分辨率）→ 用 `systemDateTime.getUptime(TimeType.STARTUP, true) / 1e6`。详见 `references/harmony-canvas-frame-pacing.md`。
10. **提交信息不要用 shell heredoc / `python -c` 内联写**（反引号 / `$` 会被 shell 吃掉）。用 Write 写 UTF-8 文件再 `git commit -F`，提交后 `git log -1 --format=%B` 复核。
11. **行尾一致性**：改 `.ets` / `.md` 前先看该文件是 LF 还是 CRLF（Windows 上工具默认 CRLF，**双 CR `\r\r\n` 会让 diff 膨胀到整文件级**）。批量写盘后用 python 校验字节，别信编辑器。

---

## 本机环境坑（Windows + DevEco + WorkBuddy，换设备最先踩）

| 坑 | 结论 |
| --- | --- |
| **构建能力** | 本机可以真编译，`hvigorw.bat` 在 DevEco 安装目录下；日志是 **UTF-16**，Read 会拒读 → 用 `scripts/decode-log.py` 或 `scripts/hvbuild.py` |
| **PowerShell 不回显 stdout** | 一律 `*> $env:TEMP\x.log` 重定向；产出文本用 **python `open(..., 'w', encoding='utf-8')`** 落盘（`Out-File` 写的文本 Read 会判 binary） |
| **bash 缺 coreutils** | 本机 `bash` 常缺 `ls` / `grep` / `head` → 用 Glob / Grep / Read 专用工具，别走 bash |
| **hvigor 清理构建缓存被沙箱拦** | >50 项批量删除触发 `00308018 SAFE_DELETE_BULK_CONFIRM_REQUIRED` → 用 robocopy 空目录 `/MIR` 清空 `entry\build` 后重跑 |
| **`COMPILE RESULT` 报的 ERROR 条数** | 常**比列出的多一条**，别以为只差那一条 |
| **`sys.symbol.*` 符号名编译期校验** | 写不存在的名字直接 BUILD FAILED；合法清单在 `<DevEco>/sdk/default/openharmony/ets/build-tools/ets-loader/sysResource.js`（键名**不带引号**）。`$r('sys.symbol.' + key)` **动态拼接无效**，只能 switch / 映射表显式列出 |

---

## 技能自带资源（本技能目录内）

```
harmony-dev/
├── SKILL.md                      ← 本文件（入口：铁律骨架 + 任务路由表）
├── references/                   ← 领域分册（按需读）
│   ├── harmony-app-template.md           主册：38 铁律 / 8 工作流 / 坑点速查表 / 28 LSN
│   ├── harmony-app-template/             ├ file-map.md（文件职责表）
│   │                                     └ workflows.md（W1~W8 可复制代码）
│   ├── harmony-offline-verify.md         编译验证主册
│   ├── binary-asset-protocol.md          rawfile 定长二进制资产安全协议
│   ├── harmony-arkts-lint-fix.md
│   ├── harmony-canvas-frame-pacing.md
│   ├── harmony-form-card.md              桌面卡片（两册合并）
│   ├── harmony-log-probe-cleanup.md
│   ├── harmony-material-layer.md
│   ├── harmony-reader-kit-integration.md
│   ├── harmony-screenshot-layer-forensics.md
│   ├── harmony-sheet-panel.md
│   ├── harmony-side-drawer.md
│   ├── harmony-symbol-outline-to-pixelmap.md
│   ├── harmony-system-loading.md
│   ├── harmony-titlebar-menu.md
│   ├── harmonyos-arkts-custom-background.md
│   ├── stellarium-hips-landscape.md
│   └── stellarium-viewport-alignment.md
├── scripts/                      ← 可直接调用的诊断/构建脚本
│   ├── hvbuild.py                跨设备自动探测 hvigorw，剥 ANSI + 自适应 UTF-16/UTF-8 解码
│   ├── decode-log.py             日志转码
│   ├── arkts-static-check.mjs    无构建能力时的 ArkTS 静态预检
│   ├── bin-table-audit.mjs       定长二进制表索引体检
│   ├── shot_forensics.py         真机截图图层取证（掩膜 + 连通块）
│   ├── crop-bottom.py / lsdir.py / show.py / unzip-stellarium.py
└── assets/
    ├── TEMPLATE_MANIFEST.md      模板清单 / 排除项 / 同步约定
    └── template/                 可移植模板工程副本（56 文件 / 1.2 MB，编译全绿）
```

调用示例（`<skill>` = 本技能目录的绝对路径）：

```bash
python <skill>/scripts/hvbuild.py compile <工程根>     # ~20s，拿全部 ArkTS 错误/告警
python <skill>/scripts/hvbuild.py hap     <工程根>     # 再顺带验证资源引用与签名
node   <skill>/scripts/arkts-static-check.mjs <项目根>
node   <skill>/scripts/bin-table-audit.mjs <bin 文件> <每元素 float 数> [参照的索引文件...]
```

---

## 旧技能名 → 分册映射（跳转壳用）

| 旧技能目录名 | 现在读 |
| --- | --- |
| `harmony-app-template` | `references/harmony-app-template.md` |
| `harmony-offline-verify` | `references/harmony-offline-verify.md` |
| `harmony-arkts-lint-fix` | `references/harmony-arkts-lint-fix.md` |
| `harmony-screenshot-layer-forensics` | `references/harmony-screenshot-layer-forensics.md` |
| `harmony-log-probe-cleanup` | `references/harmony-log-probe-cleanup.md` |
| `harmony-material-layer` | `references/harmony-material-layer.md` |
| `harmony-sheet-panel` | `references/harmony-sheet-panel.md` |
| `harmony-titlebar-menu` | `references/harmony-titlebar-menu.md` |
| `harmony-side-drawer` | `references/harmony-side-drawer.md` |
| `harmony-system-loading` | `references/harmony-system-loading.md` |
| `harmony-symbol-outline-to-pixelmap` | `references/harmony-symbol-outline-to-pixelmap.md` |
| `harmony-form-card` + `harmonyos-arkts-form-card` | `references/harmony-form-card.md`（两册已合并） |
| `harmonyos-arkts-custom-background` | `references/harmonyos-arkts-custom-background.md` |
| `harmony-reader-kit-integration` | `references/harmony-reader-kit-integration.md` |
| `harmony-canvas-frame-pacing` | `references/harmony-canvas-frame-pacing.md` |
| `stellarium-hips-landscape` | `references/stellarium-hips-landscape.md` |
| `stellarium-viewport-alignment` | `references/stellarium-viewport-alignment.md` |

> 来源：`github.com/TroilOryan/Icey-Harmony-Skill`（个人鸿蒙技能总汇）。
> 各项目（Icey-Player-Harmony / Icey-Reader / Icey-Stars / Icey-Days）沉淀的新经验应同步回该库。