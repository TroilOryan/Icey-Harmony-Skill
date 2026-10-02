# Icey-Harmony-Skill

个人鸿蒙开发 Skill 库 —— 存放可在 WorkBuddy / 任意 Agent 环境复用的 HarmonyOS 开发技能包。
目标：**换设备 clone 本库 → 拷回 `~/.workbuddy/skills/` → 经验与踩坑全部带回，减少试错。**

> **2026-10-03 起本库只有一个技能：`harmony-dev`（为鸿蒙开发赋能）。**
> 原先 18 个独立技能已合并进它的 `references/` 分册，入口只放「铁律骨架 + 任务路由表」，
> 按需加载，避免一次性把几十 KB 塞进上下文。旧的 18 个目录保留为**一行跳转壳**，兼容旧引用。

## 安装

**只需拷 `harmony-dev/` 一个目录**（技能名 = 目录名）：

```bash
# Windows PowerShell
Copy-Item .\harmony-dev "$env:USERPROFILE\.workbuddy\skills\" -Recurse -Force
```

```bash
# macOS / Linux
cp -r ./harmony-dev ~/.workbuddy/skills/
```

> 旧技能名（`harmony-sheet-panel` 等）如果已经装过，可以保留跳转壳，也可以直接删掉 ——
> 触发场景现在都由 `harmony-dev` 接管。**想干净的话只留 `harmony-dev` 即可。**

## 技能结构

```
harmony-dev/
├── SKILL.md            入口：11 条通用铁律 + 任务路由表（触发场景 → 该读哪册）+ 本机环境坑
├── references/         19 个领域分册（一字未删的实战沉淀）
├── scripts/            9 个可直接调用的诊断/构建脚本
└── assets/             TEMPLATE_MANIFEST.md + template/（56 文件可移植模板工程，编译全绿）
```

## 任务路由表（入口 SKILL.md 的摘要）

| 领域 | 读哪册 |
| --- | --- |
| **基建 / 脚手架** | `references/harmony-app-template.md`（38 条铁律 / 8 条工作流 / 坑点速查表 / 28 条 LSN）+ `references/harmony-app-template/workflows.md`（W1~W8 可复制代码）+ `assets/template/` |
| **编译 / 验证 / 排错** | `harmony-offline-verify.md`、`harmony-arkts-lint-fix.md`、`harmony-screenshot-layer-forensics.md`、`harmony-log-probe-cleanup.md`、`binary-asset-protocol.md` |
| **弹窗 / 菜单 / 抽屉** | `harmony-sheet-panel.md`、`harmony-titlebar-menu.md`、`harmony-side-drawer.md` |
| **观感 / 材质 / 背景** | `harmony-material-layer.md`、`harmonyos-arkts-custom-background.md`、`harmony-system-loading.md`、`harmony-symbol-outline-to-pixelmap.md` |
| **能力接入 / 专项** | `harmony-form-card.md`（两册合并）、`harmony-reader-kit-integration.md`、`harmony-canvas-frame-pacing.md`、`stellarium-viewport-alignment.md`、`stellarium-hips-landscape.md` |

### 分册清单（19 册）

| 分册 | 用途 |
| --- | --- |
| `harmony-app-template.md` | 鸿蒙 App 基建模板：38 条铁律 / 8 条工作流 / 坑点速查表 / 28 条 LSN（原 `harmony-app-template` v1.3.9） |
| `harmony-app-template/workflows.md` | W1~W8 工作流的可复制代码 |
| `harmony-app-template/file-map.md` | 模板文件职责表 |
| `binary-asset-protocol.md` | rawfile 定长二进制资产（星表/索引表/图数据）索引安全协议 |
| `harmony-offline-verify.md` | 真编译验证（DevEco 自带 hvigorw）、逻辑端到端验证、二进制资产安全改动 |
| `harmony-arkts-lint-fix.md` | ArkTS 严格模式编译错误系统性修复 + 真机 `undefined is not callable` / this 归属定位 |
| `harmony-screenshot-layer-forensics.md` | 真机截图判定「图层/标签到底画没画出来」（掩膜 + 连通块） |
| `harmony-log-probe-cleanup.md` | 清理遗留日志埋点/诊断日志，按唯一子串安全批量删改 |
| `harmony-sheet-panel.md` | 半模态弹窗 `bindSheet` 自绘标题带 + 边缘渐变模糊完整范式（本库最大分册，36 KB） |
| `harmony-titlebar-menu.md` | 标题栏按钮弹出下拉菜单（`PromptAction.openMenu`），含「菜单一律无分割线」定案 |
| `harmony-side-drawer.md` | 手机端自研侧滑抽屉：`SheetType.SIDE` 不生效、跟手黏手、全屏覆盖层阻塞命中 |
| `harmony-material-layer.md` | 沉浸光感 / 材质完整落地：档位方向、官方默认档表、四种 scope、Toggle 承载层完整性清单 |
| `harmonyos-arkts-custom-background.md` | 自定义背景（双槽位壁纸 + 模糊度）：选图落沙箱存 `file://`（禁 base64） |
| `harmony-system-loading.md` | 加载态一律系统 `LoadingProgress`，禁自绘加载动画（用户定案） |
| `harmony-symbol-outline-to-pixelmap.md` | 系统符号 `sys.symbol.*` 画进 PixelMap / 离屏位图 |
| `harmony-form-card.md` | 桌面服务卡片（Form Kit）：三件套、数据注入、刷新、FormLink、背板透明（原两册合并） |
| `harmony-reader-kit-integration.md` | 华为 Reader Kit 阅读内核接入：白屏、翻页裁切、单击不出工具栏 |
| `harmony-canvas-frame-pacing.md` | Canvas 全屏自绘的帧率与跟手延迟诊断（打点口径 + 成本模型） |
| `stellarium-hips-landscape.md` | Stellarium HiPS 实拍地景 → 离线烘焙等距圆柱全景 |
| `stellarium-viewport-alignment.md` | 星图视野/投影/网格口径对齐 Stellarium（fov 短边角 + 立体投影） |

## 技能自带脚本（`harmony-dev/scripts/`）

| 脚本 | 用途 |
| --- | --- |
| `hvbuild.py` | 跨设备自动探测 hvigorw，剥 ANSI、按 UTF-16/UTF-8 自适应解码，`compile` / `hap` 两个子命令 |
| `decode-log.py` | hvigor 日志转 UTF-8 |
| `arkts-static-check.mjs` | 无构建能力时的 ArkTS 静态预检（Cannot find name / not exported） |
| `bin-table-audit.mjs` | 定长二进制表索引体检 |
| `shot_forensics.py` | 真机截图图层取证（颜色掩膜 + 连通块聚类 + 定点放大） |
| `crop-bottom.py` / `lsdir.py` / `show.py` / `unzip-stellarium.py` | 像素量测 / 目录列举 / 写盘只回摘要 / Stellarium 包解压 |

## 本机环境坑（Windows + DevEco + WorkBuddy）

换设备最先踩的几条，先看这里能省几小时：

| 坑 | 结论 |
| --- | --- |
| **构建能力** | 本机**可以真编译**，别假设「没有 hvigor」。DevEco 自带 `tools\hvigor\bin\hvigorw.bat`，项目根一般**没有** wrapper。改完 ArkTS 先真编译再交付 |
| **PowerShell 不回显** | 工具不回显 stdout → 一律 `*> $env:TEMP\x.log` 重定向；产出文本用 **python 写 UTF-8**（`Out-File` 写的文本 Read 会判 binary） |
| **hvigor 日志编码** | 日志是 **UTF-16 + ANSI 色码**，Read 直接拒读（"binary file"）→ 用 python 转码后读。`scripts/hvbuild.py` 已封装 |
| **bash 缺 coreutils** | 本机 `bash` 常缺 `ls`/`grep`/`head`（command not found）→ 用 Glob / Grep / Read 专用工具，别走 bash |
| **编译错误条数** | hvigor 报的 `COMPILE RESULT` ERROR 条数**常比列出的多一条**，别以为只差那一条 |
| **同一文件禁止并行 Edit** | 并发 Edit **同一文件**时各自基于同一快照写盘、**后写覆盖前写**，且**每个都报 "Successfully edited"**。同文件多处改动必须**串行**；改完用 python 读字节复核 |
| **帧内计时** | 禁用 `Date.now()`（1ms 分辨率 > 单次 Canvas 调用 10~20µs，分段全读 0）→ 用 `systemDateTime.getUptime(TimeType.STARTUP, true) / 1e6` |
| **Git 提交信息** | 不要用 shell heredoc / `python -c` 内联写（反引号 `$` 被 shell 吃掉）→ Write 工具写到 `.workbuddy/cache/_msg.txt` 再 `git commit -F`，提交后 `git log -1 --format=%B` 复核 |

### 常用命令

```powershell
# 纯类型校验（约 20s，最常用）
& "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" --mode module `
  -p product=default -p module=entry@default -p buildMode=debug `
  default@CompileArkTS --no-daemon *> $env:TEMP\compile.log

# 完整打包（含签名，出可装真机的 hap）
& "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" --mode module `
  -p product=default -p module=entry@default -p buildMode=debug `
  assembleHap --no-daemon *> $env:TEMP\hap.log
```

> DevEco 安装在非常规目录时，设 `$env:DEVECO_HVIGORW` 指向 `hvigorw.bat` 即可，`hvbuild.py` 会优先读它。

## 与各项目的技能同步

各 HarmonyOS 项目（Icey-Player-Harmony / Icey-Reader / Icey-Stars / Icey-Days-Harmony）的
`.gitignore` 采用 `.workbuddy/*` + `!.workbuddy/skills/`，即**项目级 skills 随仓库版本化**。
本库是**用户级**总汇：项目里沉淀的新技能应同步回本库，避免散落。

### ⚠️ 同步铁律（2026-10-03 定案）

1. **同步前必须双向 diff**：`diff <远端> <本地> | grep '^<'`。
2. **远端独有行逐条判定** —— 是「本地更新」还是「本地丢失」；**丢失的先补回再覆盖**。
   （已实证：`harmony-material-layer` 的「Toggle 承载层完整性清单」一整节曾在本地丢失，
   盲目覆盖会静默抹掉远端积累。）
3. 同步后逐目录 `diff -rq` 复核 + **fresh clone 复验**。
4. 纳入范围：**仅用户自建**技能（`agent_created: true`）；
   第三方/官方包（`huawei-docs` / `reminds`）不纳入本库。