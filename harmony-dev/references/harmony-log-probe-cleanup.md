> **分册：`harmony-log-probe-cleanup`** ｜ 原独立技能 `harmony-log-probe-cleanup`，2026-10-03 合并进 `harmony-dev`。
> 触发场景见入口 `SKILL.md` 的路由表。

# 日志埋点清洗 + 安全批量源码删改

解决两件事：**哪些日志该删**（口径），**怎么删不会删错**（手法 + 验证）。

## 一、判定口径（先分类再动手）

不要一刀切。**分三类**：

| 类别 | 处理 | 例子 |
|---|---|---|
| **埋点（删）** | 帧级/手势级/动画级路径、一次性 bug 排查 dump、纯执行流 trace | `onPanUpdate` 每帧、`onAreaChange`、`onScrollFrameBegin`、`onBarStyleChange`、Hds `onMiniBarAnimation*`、16ms Ticker 的"每 500ms 打一行"、旋转 33ms tick 的 30° 分桶、启动耗时 `t0/t1/t2`、"我走到这了/值是多少" |
| **业务事件 / 异常（留）** | 用户可见事件的成败与状态 | 导入/登录/购买/兑换/权限结果、切歌/seek/播放状态、错误与警告 |
| **其它通道（留）** | 不进用户导出日志、成本极低 | `hilog.*`、`console.*` |

**为什么"影响性能"这话成立**：
- `debugOn=false` 时每条仍要 **hilog + 环形缓冲 push + 遍历订阅者**（日志页开着还会触发重渲染）。
- `debugOn=true`（调试模式实时落盘）时**每条一次 `openSync/writeSync/closeSync` 同步 IO** —— 手势期直接卡。
- 最恶劣的是**为一条日志引入真实 I/O**：例如封面组件在**每次切歌**都 `createImageSource + getImageInfo` 读一次文件头。这类"日志"必须优先删。

**排查完必须整链删掉**，否则留下悬空引用/死代码：
1. 日志行（含多行模板字符串的**全部续行**）
2. `@Watch('xxx')` 装饰器（若回调体只剩日志，连回调方法一起删）
3. 节流字段（`lastXxxLog` / `rotateLogBucket` / `vLastScrollDir` / `lastXxxWidthLog`）
4. worker/共享接口里的**纯诊断字段**（如 `RawMediaData.coverDebug`）及其所有赋值点
5. 不再使用的 `import`（**必查**：删完 `grep -c AppLogger <file>` 应为 0）

⚠️ 删 `@Watch` 时保留 `@StorageLink('xxx')` 本身（版本号类 StorageLink 负责"对象被原地改也触发重渲染"，`@Watch` 只是回调，删回调不影响渲染）。

## 二、批量删改手法：唯一子串 → 行号 → 行窗

**不要用长段精确文本锚点。** 用 Python 脚本，结构：

1. **读取**：`io.open(path, 'r', encoding='utf-8', newline='')` → 若 `'\r\n' in raw` 则 `raw.replace('\r\n','\n')` 做匹配，写回时 `'\n'.replace('\n','\r\n')`（**ArkTS/ETS 文件多为 CRLF**）。
2. **定位**：`[i for i,l in enumerate(lines) if matcher in l]`，**断言 `len(hits) == 1`**（不唯一就是在选锚点选错了）。
3. **删除**：记录 `(start_idx, count)`，全部按原始行号收集后**从后往前**删（或用 `marked` dict 一次性重建，顺序无关，更稳）。
4. **替换**：`marked[i] = new_line`，与删除同表应用。
5. **校验与落盘分离**：先跑完所有断言的"干跑"，**全部通过才写文件**；任何断言失败 → 一个字节都不落盘（否则会出现"改了一半"）。

### 三个真会踩的坑

1. **锚点末行是长行的前缀** → `count=0`。例：锚点收在 `// **滚动帧计数（2026-09-09 二段）**`，而文件里该行后面还有 `：真实滚动 = onScrollFrameBegin…`。**锚点必须是完整行**，或者干脆改用"唯一子串定位 + 行窗"。
2. **窗口长度没算多行语句的续行** → 留下**孤立续行**（语法错）。`AppLogger.info('X',` 的模板字符串常跨 **2–7 行**；删之前先确认这段到底占几行。
3. **窗口长度多算** → 把**功能代码整块吞掉**。例：想删 `const changed = …; if (changed) { log }`，结果窗口盖住 `if (xOk && yOk) { a = b; c = true; }` → 只剩悬空的 `} else if`，级联爆 **556 个** ArkTS error（症状：`The struct 'X' must have at least and at most one 'build' method` + 后面一片 `Cannot find name`）。

**教训**：行窗越"顺手"越危险。能用**整行替换**（`marked[i] = new`）就别用窗口；必须用窗口时，窗口内每一行都要能解释。

## 三、验证清单（缺一不可）

```bash
# 1) 被删的非日志/非注释行必须逐条能解释（真实功能行应一条都没有）
git diff -U0 | grep "^-" | grep -v "^---" | grep -v "AppLogger" | grep -v "^\-\s*//" | grep -v "^-$"

# 2) 孤立续行 / 悬空括号自查
grep -n "^\s*\`.*);$" <changed files>

# 3) 构建（HarmonyOS：项目根通常无 hvigorw.js，用 DevEco 内的）
MSYS_NO_PATHCONV=1 DEVECO_SDK_HOME='…\DevEco Studio\sdk' \
  node "…/DevEco Studio/tools/hvigor/bin/hvigorw.js" assembleHap --mode module -p product=default --no-daemon
# release：加 -p product=release -p buildMode=release
# 只看 BUILD SUCCESSFUL / ArkTS:ERROR；CLI 增量构建可能打印 UP-TO-DATE 但产物已刷新 → 以产物时间戳为准
```

4. **产物反查（决定性）**：解包 HAP 里的 `ets/modules.abc`，按 UTF-8 字节搜已删日志的特征串，应 **0 命中**；对仍命中的串要**看上下文**再下结论（`Startup` 可能来自 `checkVipExpiredOnStartup` 方法名、`MetadataReader` 可能来自类名）。

```python
import io, zipfile
z = zipfile.ZipFile('entry/build/release/outputs/default/entry-default-signed.hap')
data = z.read('ets/modules.abc')
for s in ['vBarStyle: mini=', 'panMode=', 'LyricWord']:
    print(s, s.encode('utf-8') not in data)
```

5. **临时脚本清理**：用 Python `os.remove` 删临时脚本，**不要用 shell `rm`**。之后 `git status --short` 核对改动面。
6. UI/时序敏感项交给真机验证，**不要代做真机测试**：构建通过 + 产物时间戳刷新即可交付。
