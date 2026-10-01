# Icey-Harmony-Skill

个人鸿蒙开发 Skill 库 —— 存放可在 WorkBuddy / 任意 Agent 环境复用的 HarmonyOS 开发技能包。
目标：**换设备 clone 本库 → 拷回 `~/.workbuddy/skills/` → 经验与踩坑全部带回，减少试错。**

## 安装

整个 `<skill>/` 目录拷入 `~/.workbuddy/skills/` 即可（技能名 = 目录名）。
批量安装：

```bash
# Windows PowerShell
Get-ChildItem -Directory | Where-Object { $_.Name -notmatch '^\.' } |
  ForEach-Object { Copy-Item $_.FullName "$env:USERPROFILE\.workbuddy\skills\" -Recurse -Force }
```

## 技能索引（15 个）

### 基建 / 脚手架

| 技能 | 用途 |
| --- | --- |
| `harmony-app-template` **v1.3.9** | 基于 HarmonyAppTemplate 基建模板搭全新 App：38 条铁律 / 8 条工作流 / 坑点速查表 / 28 条 LSN。含 `references/`（W1~W8 可复制代码）+ `assets/template/`（可移植模板工程副本，编译全绿） |

### 编译 / 验证 / 排错

| 技能 | 用途 |
| --- | --- |
| `harmony-offline-verify` | 改完 ArkTS 后的**真编译验证**（DevEco 自带 hvigorw）、纯逻辑端到端验证、rawfile 定长二进制资产安全改动。含 `scripts/hvbuild.py`（跨设备自动探测 hvigorw） |
| `harmony-arkts-lint-fix` | ArkTS 严格模式编译错误（10505001 / arkts-no-any-unknown 等）系统性修复 + 真机 `undefined is not callable` / this 归属崩溃定位 |
| `harmony-screenshot-layer-forensics` | 用真机截图判定「图层/标签到底画没画出来」：按特征色掩膜 → 连通块聚类，把「看不到 X」拆成「没画」还是「不在视野/被挡」 |
| `harmony-log-probe-cleanup` | 清理遗留日志埋点/诊断日志，按唯一子串安全批量删改源码 |

### UI / 观感 / 交互

| 技能 | 用途 |
| --- | --- |
| `harmony-material-layer` | 沉浸光感完整落地方案：两套枚举口径、官方默认档表、四种 scope、封面色调材质、**挡位实时生效三件套**（@StorageLink / ForEach key 重建 / builder 传参） |
| `harmony-titlebar-menu` | 标题栏按钮弹出下拉菜单（Hds menu icon + `PromptAction.openMenu`），含 `bindMenu` 第二参 `placement`/`systemMaterial` 必传坑 |
| `harmony-side-drawer` | 手机端自研侧滑抽屉：`SheetType.SIDE` 不生效、跟手黏手、**全屏覆盖层阻塞命中测试**（页面点不动/列表滚不动） |
| `harmony-system-loading` | 首屏与加载态一律用系统 `LoadingProgress`，**禁自绘加载动画**（用户定案） |
| `harmony-symbol-outline-to-pixelmap` | 把系统符号（`sys.symbol.*`）画进 PixelMap / 离线位图（播控封面、通知图标、服务卡片、分享图） |
| `harmony-form-card` | 桌面服务卡片（Form Kit）：数据注入、卡片点按路由（FormLink）、独立进程读不到 AppStorage 等 |

### 能力接入 / 专项

| 技能 | 用途 |
| --- | --- |
| `harmony-reader-kit-integration` | 华为 Reader Kit（`readerCore.ReadPageComponent`）接入自研阅读 App：白屏、翻页裁切、单击不出工具栏、底色/字号不生效等踩坑清单 |
| `harmony-canvas-frame-pacing` | Canvas 全屏自绘（星图/地图/仪表）的帧率与跟手延迟诊断：先修打点（高精度时钟 + 累加口径），再用「调用数 ≤ 数据量上限」做数值体检 |
| `stellarium-hips-landscape` | Stellarium HiPS landscape（实拍地景全景）→ 离线烘焙成一张等距圆柱全景（RGBA + 天空透明），运行时一次纹理采样 |
| `stellarium-viewport-alignment` | 星图 App 视野/投影/网格口径对齐 Stellarium（移动端观感）：fov 按短边角解释 + 立体投影；含离线量取角尺度的证明法 |

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