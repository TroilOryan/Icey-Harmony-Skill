> **分册：`harmony-arkts-lint-fix`** ｜ 原独立技能 `harmony-arkts-lint-fix`，2026-10-03 合并进 `harmony-dev`。
> 触发场景见入口 `SKILL.md` 的路由表。

# HarmonyOS ArkTS 严格模式编译错误修复

## 触发场景
- DevEco 构建报大量 ArkTS Compiler Error / hvigor Rollup Error
- 从 Flutter/Web 移植到 HarmonyOS 时报错风暴
- 成片诡异级联错误（UI component cannot be used / Cannot find name xxx）
- **真机运行时崩溃**：`TypeError: undefined is not callable` / `Cannot read property of undefined`，
  尤其"打开某个弹窗/菜单立刻闪退"（多为 `this` 归属问题，见 @Builder 规则）

## 核心诊断原则
1. **先找根错误，级联后清**：成片 10505001/10905236（如 "Row cannot be used"、"Cannot find name margin"、"Scroll only one child"）几乎都是某文件/某组件**先发生编译错**的级联。用 `grep -oP "At File: E:[^ ]+" buildlog.txt` 按文件统计，先修每个文件的**第一个非级联错误**（尤其自定义组件自身文件，如 GlassCard.ets 失败会污染所有调用页）。
2. 每次让用户在 DevEco 重跑拿新日志，不要凭旧日志反复猜。

## 已知 API 铁律（本 SDK 已验证，按官方文档）
### 颜色
- `Color($r('app.color.x'))` **非法** → 直接用 `$r('app.color.x')`（Resource 可被 .fontColor/.backgroundColor 接受）。`Color` 只是枚举，无构造调用。
- `blendOpacity` **在 Resource 和 ColorMetrics 上都不存在** → 在 base/dark 的 `resources/{base,dark}/element/color.json` 里定义带 alpha 的资源色（#AARRGGBB，如 92%→#EA+原色、12%→#1F+原色），代码用 `$r('app.color.card_bg_92')`。
- `ColorMetrics`（@kit.ArkUI）只有 `resourceColor/blendColor` 等，无 blendOpacity。

### cryptoFramework（@kit.CryptoArchitectureKit）
- 摘要：`createMd('SHA256')`（**无 createHash**）；`md.update/digest` 均 async 需 `await`。
- HMAC：`createMac('SHA256')`（**无 createHmac**）；`createSymKeyGenerator('HMAC')`；`convertKey` 返回 `Promise<SymKey>` 需 `await`；`mac.init/update` 需 `await`；`mac.doFinal()` **无参**，`await` 返回 `DataBlob`。
- 对称：`createCipher('AES256|GCM|PKCS7')`；`cipher.init/doFinal` async。
- 随机：`createRandom().generateRandomSync(16)` 返回 **`DataBlob`**（`{data: Uint8Array}`）→ `await` 后取 `.data`。
- `GcmParamsSpec`：字段 `iv/authTag/aad` 类型均为 **`DataBlob`**（需 `{ data: xxx }` 包装），且 **`aad` 必填**。
- `util.Base64Helper().decode()` 返回 **`Promise<Uint8Array>`**（需 await）。
- `utf8ToBytes`：`new Uint8Array(buffer.Buffer)` 报 ArrayBufferLike 不兼容 → `new Uint8Array(buf.buffer)`。
- 类型注解：`cryptoFramework.DataBlob/SymKey/SymKeyGenerator/Cipher/GcmParamsSpec/Mac` 可用；**`Hash` 不存在**（应为 Md，建议不写注解靠推断）。

### @Builder 规则（最易踩）
- **@Builder 方法体内禁止声明变量**（const/let）→ 报 10905209 "Only UI component syntax can be written here"。把计算移到**普通 private 方法**，在 UI 表达式里调用（方法调用 OK，如 `Text(this.buttonLabel())`）。
- **@Builder 方法体内禁止裸表达式语句**（连无声明的副作用调用、如埋点 `PerfProbe.bump('x');` 也不行）→ 报 **10905204** `'PerfProbe.bump('x');' does not meet UI component syntax`。⚠️ **错误码与上一条不同**（10905204 vs 10905209），别照错码找错方向。副作用要放**普通方法**或 `.then`/箭头回调里（2026-09-11 加性能埋点时实测）。
- **`@BuilderParam content` 的箭头里只能调 @Builder 方法，不能内联 UI 组件**（如 `content: (): void => { Row() {...} }`）→ 会炸 Rollup "Unexpected token"。正确：`content: (): void => { this.xxxContent(); }`，内容放独立 @Builder。
- **🔴 跨组件传 `@BuilderParam` 必须「箭头包一层」，禁止裸方法引用**（2026-09-15 真机闪退，**运行时**错误不是编译错误）——
  症状：`TypeError: undefined is not callable`，打开弹窗/展开菜单即闪退，栈落在 builder 体内**第一个 `this.方法()`**的位置。
  ```ts
  ✅ content: (): void => { this.formContent(); }   // 箭头 → 词法 this = 本组件
  ❌ content: this.formContent                       // 裸引用 → this 被换成接收方组件
  ```
  **根因**：ArkUI 转译器把**接收方组件**里的调用写成 `this.content.bind(this)()`，`this` 是接收方
  → 裸传的方法体内 `this.previewH` / `this.formTab` 全指向接收方（无此成员）。箭头**忽略 `.bind`**、保留词法 this。
  尾随闭包不受影响（转译后本身就是箭头），所以「多 @BuilderParam 改具名传参」那一轮最易引入。
  唯一豁免：builder 体**零 `this` 引用**时裸传安全（菜单类 onClick 全用模块级/静态调用即可，这也是 Player 「menu 内禁止 `this.方法`」的由来）。
  自查：`grep -n "content: this\.\|topContent: this\.\|cardHeader: this\.\|sheetSlot: this\."`（有命中即 bug）。
- **🔴 `bindMenu` / 其他 `@Builder` 闭包内的 `this` 未绑定 → 真机 `undefined is not callable` 闪退**
  （2026-09-14 CoverShapePicker 实证：`shapeMenu` 的 `MenuItem.onClick` 写死 `this.applyShape(card.value)`，
  `bindMenu` 的 Menu 闭包内 this 未绑定 → `this.applyShape` undefined → 点下拉瞬间闪退；日志：崩溃前一条是 `MenuItem CLK`）。
  判据：**日志出现「打开菜单/下拉瞬间闪退 + `xxx is not callable`」= 先怀疑闭包内 `this.方法`**。
  修复：菜单项 onClick 一律改调**模块级函数或静态方法**（`applyShapeFromMenu(value)`，逻辑与组件内方法一致：
  写设置 + 联动更新 AVSession）；组件树内（网格卡片 onClick 等）this 正常，不动。
  项目先例：AppearanceSettings 的 themeMenu/materialMenu 注释记载同一坑（bindMenu 闭包内 this 未绑定、
  组件方法 `this.applyTheme` 真机 undefined 闪退），其 9 处 withMenu 的 onClick 全走模块级函数/静态方法，
  唯 CoverShapePicker 漏改 —— **新增任何 bindMenu 菜单项，onClick 一律模块级函数/静态方法**。
- **🔴 `@Builder` 的「按值传递参数」是快照 —— 由状态算出来的值绝不能当参数传**（2026-09-16 实测：
  设置项下拉"选了之后内容变了、但下拉标签文本不变"，无任何报错，属**静默 UI 不刷新**类）：
  官方口径：**按值传递时状态变量的改变不会引起 `@Builder` 内部的 UI 刷新**。
  ```ts
  ❌ this.dropValueSmall(this.notebookLabel(), this.notebookItems())   // 值在调用点就算好 → 冻结在首帧
  ✅ @Builder notebookDrop() { Text(this.notebookLabel()) … }           // 值在 builder 体内现读
  ```
  参数只留**静态事实**（字段名、候选数组、下标这类不随状态变的东西）。
  ⚠️ 同族坑：`@Builder` 以值快照收「选中态」（`dirItem(label, selected)` 收 `selected`）→ 选中不切换，
  必须在体内读 `this.selectedXxx`。区分：这是**值快照**问题；下面那条是**宿主组件不重建**问题 ——
  两个症状都是"UI 不动"，但一个靠"值改成体内读"、一个靠"build() 链里内联引用一次"。
- **⚠️ `@BuilderParam` 里的状态，要「宿主组件 build 内联引用」一次才重建**（铁律 #34）：
  builder 经 @BuilderParam 交给子组件渲染时，宿主不重建就不会带上新值（表现为"点 tab 没反应"）。
  做法：`build()` 末尾挂一次内联读，如 `.opacity(this.formTab >= 0 ? 1 : 1)`。
- **调 `this` 归属类问题时，别猜——读本机构建缓存里的转译产物**（保留注释、可读）：
  `<module>/build/default/cache/default/default@CompileArkTS/esmodule/debug/entry/src/main/ets/**/*.ts`。
  它直接给出 ArkUI 生成的真实调用形态（`.bind(this)()` / `previewArea(parent = null)` / 尾随闭包→箭头），
  比翻文档快且确定；栈里的 `文件:行:列` 也能与转译产物逐行对上，用于定位「哪个 `this.方法()` 是第一个炸的」。
- `alignSelf` 只接受 **ItemAlign**（Start/Center/End），**不接受 HorizontalAlign/VerticalAlign**。
- **类体内不能声明 `const`/`let`**（报 10505001 `A class member cannot have the 'const' keyword`）：
  模块级常量一律写在 class **外面**（缩进也要对齐模块级，别留在类的方法之间）。
  ⚠️ 写进类体后不仅这两行报错，**引用它的地方还会连带 `Cannot find name 'XXX'`** ——
  看到「10505001 ×N + Cannot find name ×M」混在一起，先查这几个名字是不是被塞进了某个 class 体内
  （2026-09-16 实测：3 个常量误入 class → 该模块整体编译失败，整个 HAP 出不来）。

### 组件/属性
- **自定义组件的成员名不能与「通用属性方法」重名**（报 10505001 `Property 'x' in type 'Foo' is not assignable to the same property in base type 'CustomComponent'`）→ 改名（如 `size`→`iconSize`、`tabIndex`→`formTab`），同步改所有引用点。
  - 范围比「size/width/height」大得多：基类链带**全部通用属性方法**——`CommonMethod` / `CommonShapeMethod` / `ScrollableCommonMethod`（本 SDK `openharmony/ets/component/common.d.ts` 实测 **255 个**），含 `tabIndex`（焦点顺序，`:18815`）/ `key` / `id` / `opacity` / `animation` / `onClick` / `focusable` / `backgroundColor` / `border` / `margin` / `padding` / `zIndex` … 一律避开。
  - **判定口径（别一刀切改名）**：只查「该名字是不是某个 `*Attribute` / `CommonMethod` 类里声明的**方法**」。
    - 只是某接口的**字段**（`title`、`color`、`x`、`y`）→ **不冲突**，可放心用。
    - 落在**专用 Attribute** 上的名字（如 `tabBar` 只在 `tab_content.d.ts` 的 `TabContentAttribute`）→ **不冲突**，自定义组件里叫 `tabBar()` / `tabItem()` 的 @Builder 合法。
  - 自查脚本（逐行跟踪 `declare class|interface` 归属，只收属性类的 4 空格方法声明，再与 `@State/@Prop/@Link/...` 成员名求交集）：
    能在改名前一次性查出全仓潜在撞名，避免「改完一版 → 用户 Build → 又报一个」的往返。
    注意**第一版容易假阳性**：若把 common.d.ts 里所有 `^\s{4}(\w+)[:?]`**字段**也收进来，会误报出 `title`/`color`/`x`/`y`；务必限定在方法 + 属性类。
- 匿名对象字面量必须对应**声明的 interface/class**（10605038）→ 定义接口；动态字段用点访问（`params.icon=`），禁止 `params['icon']`（10605029）。
- interface 实例**不能传给 `Record<string, X>` 参数**（缺索引签名）→ http helper 的 query/body 参数类型改 `Object`，内部 `as Record<string, Object>`；或函数返回类型用具体接口（如 `Promise<HuaweiParseResult | null>`）。
- 路由页必须有 `@Entry`（main_pages.json 已列但文件缺 → 10905402）。
- **🔴 卡片/表单页的模块级变量名会跨文件撞**（2026-09-16 实测，报 10505001
  `Cannot redeclare block-scoped variable 'NUM_OFFSET_Y'`，报错**指向两个不同文件**）：
  `entry/src/main/ets/widget/pages/` 下的卡片页（`form_config.json` 的 src 指向的 `@Entry` 文件）
  **不各自独立作用域** —— A 页与 B 页各写一次 `const NUM_OFFSET_Y = 2` 就撞。同类名：
  `TODAY_RED` / `DATA_BLOCK_W` / `COLS`（同项目里 4x4 卡片也各有一份，只是当次错误列表截断没全报）。
  ⇒ 卡片页模块级常量**一律带卡片后缀**（`NUM_OFFSET_Y_1X2`），或把常量挪进组件内部。
  ⚠️ 这类错误**不在宿主文件里**，改"设置/宿主"需求时极易漏看 —— 收尾必须真跑一次构建。

## 静默失效与命中排查（编译通过但运行不对）

> 这类问题**编译零报错、日志无异常**，只能靠"看编译产物 + 按 zIndex/覆盖层列清单"定位。本工程（Icey-Reader）
> 已各栽过一轮，结论固化如下。项目专属内容（双内核/导入管线/数据模型）不在此列，见其 `docs/`。

### 1. 🔴 struct 内禁用 `get` 访问器（命中率最高，2026-10-06 实证）
- **症状**：派生值取到 `undefined`（`fontSize(undefined)` ⇒ 整行/整块不渲染）/ 参与运算变 `NaN`
  （`scrollToIndex(NaN)` ⇒ 动作静默失效，目录不定位、进度上报坏值）。
- **根因**：ArkTS 把 `.ets` 编译成 `.ts` 时，**手写 `get` 访问器被整段丢弃**（@Prop 自动 getter 保留、
  普通方法保留、手写 `get` 一个都不留）。
- **修法**：派生值一律写**私有方法**（`this.xxx()`）或提前算进**普通成员**。
- **历史中招**：`BookCover.cellSize/colCount/titleX/titleY`、`ReaderKitPage.tocIndex`（目录不定位）、
  `ReaderPage.currentChapterIndex`（进度上报坏值）。
- **自查**：`grep -rn "get [a-zA-Z_]" entry/src/main/ets --include=*.ets`（struct 内手写 getter 应无命中）。

### 2. 🔴 自定义组件调用点的通用属性会生成合成节点 `__Common__`（吃命中）
- **症状**：父组件里给组件内部节点设了 `HitTestMode.None`，那块仍吃点击；**只写了 `padding` 的留白带**
  成了命中终点。
- **根因**：`TtsSubtitle({...}).padding({bottom:96})` 编译后生成 `__Common__` 合成节点包住组件，
  **合成节点无 hitTestBehavior 设置（默认 Default = 自身响应 + 阻止兄弟）** ⇒ 它的 padding 区也是命中区，
  组件**内部**的 None 管不到调用点这一层。
- **修法（两条缺一不可）**：① 不需要时**门控渲染**让该层根本不存在（`if (this.ttsOn)`）；
  ② 调 `zIndex` 让该接收命中的层**排在被吃命中的层之上**。
- **实例**：阅读页底栏 7 按钮全灭 —— 字幕层调用点 padding(96) 盖住底栏(88)，且字幕层 `zIndex(3)` > 菜单层 `zIndex(2)`。

### 3. `hitTestBehavior` 语义（不递归）
| 取值 | 自身 | 子节点 | 兄弟 |
|---|---|---|---|
| `Default` | 响应 | 响应 | **阻止** |
| `Block` | 响应 | **阻止**（连同自己按钮） | 阻止（相对父容器） |
| `Transparent` | 响应 | 响应 | 不阻止 |
| `None` | 不响应 | 不响应 | 不阻止 |
- `Block` 的"阻止兄弟"是**相对父容器** ⇒ 必须加在**整层**，只加小块无效。
- `None` **不阻止任何一方** ⇒ 挡不住下层 native surface / 子节点。
- 排查先问"命中停在哪个节点"（列全部整屏覆盖层含 `opacity 0`、按 zIndex 从高到低问）。

### 4. 🔴 `LazyForEach` 列表"整表刷新"只有一条真路（`.key()` 不是重建原语）
- **症状**：数据层全对（`@Watch` 触发、`books` 换了新数组），**屏幕条目数/内容不变**；
  空列表导入第一本会立刻显示、已有书再导入就不显示。
- **根因**：`.key('epoch_'+n)` 是**测试专用标识**（`@test`，编译器 WARN `key' can only be used for testing directories`），
  对渲染**零影响**。能真正销毁子树的原语只有 **`if` 的分支号** 和 **`ForEach` 的 key**。
- **正解**：外层套 `if (this.dataEpoch % 2 === 0) { A } else { A }`（两分支逐字同内容 ⇒ 分支号翻转即销毁重建，
  抽 `@Builder` 就不销毁了）；行内刷新用 `ForEach([\`k_${tick}\`], …)`（但 `Refresh` 只能一个子组件，包不住整个 List）。
- **数据源实例必须稳定**：`LazyForEach(source, …)` 创建时把监听器注册在**当时对象**上；
  `this.source = new Xxx()` 后旧实例仍被攥着 ⇒ 新书永远不出现、`notifyRowOf` 打空。
  ⇒ 实例建一次，用 `setRows()` 就地换数据。
- **别重建太勤**：打开书→`markRead`→阅读次数+1 这类不影响行结构的，无条件重建会**每次返回列表跳回顶部**
  ⇒ 用行签名（每行 key 拼起来）当判据，签名变才重建。

### 5. 带参 `@Builder` 根节点事件归属不确定
- **表现**：给带参 `@Builder` 的根节点挂 `onClick` ⇒ **点不动、无日志**。
- **口径**：**带参 `@Builder` 不挂事件，抽成 `@Component`**（组件边界 = 事件边界）。
  `layoutWeight(1)` 这类布局属性也必须挂在组件自己根节点、写在调用处无效。

### 6. 🔴 离屏截图 `getComponentSnapshot().get(id)` 被父容器 `height('100%')` 截断
- 父容器 `.height('100%')` 会把**自适应高度**的离屏子节点**截断到整屏高** ⇒ 长内容拦腰截断。
  承载容器必须显式给足高度（上界用「字数×行高」证明）。
- `.id()` **不要写在自定义组件调用点**（落到 `__Common__` 合成节点，截到的是容器）；透传进组件、打在**组件自己根节点**上。
- 渐隐/覆盖遮罩用**负 margin 叠**（占位高 0），别用 `height('100%')` 覆盖层（百分比按父级约束解析成"最大高度"把卡片撑爆）。

### 7. ⚠️ `fileIo.accessSync(path)` 返回 **boolean**（不存在返回 `false`，**不抛异常**）
- "不存在就建目录"不能写 `try { accessSync } catch { mkdirSync }`（catch 永不执行）⇒ 随后 `openSync` 报 `13900002`。
  ⇒ 直接 `mkdirSync` + 吞掉"已存在"异常。

### 8. 🔴 `clip(true)` 与 `.shadow()` 写在同一个节点 = 阴影被裁（2026-10-07 结构性发现）
- `clip(true)` 把自己节点的绘制（**含向外扩散的阴影**）一起裁掉 ⇒ 同节点写 `clip+shadow` 等于**没有阴影**。
- **为什么长期没发现**：旧阴影右下偏移被裁掉的是左上、右下仍露大半，读作"有效阴影"。改成无偏移/居中时才暴露。
- **修法**：需裁内容（图/渐变塞进圆角）→ **双层**（外层 Stack 做 size+borderRadius+shadow，内层 Stack 做 clip）；
  只想浮起 → 直接给外层容器加 `.shadow`，别在 clip 节点上加。
- ⚠️ `shadow()` 的 `offsetX` 对整行轨道必须 0（右偏让左端无阴影、右端重，读作整体歪）。
- ⚠️⚠️ **`.shadow` 的轮廓 = 它所在节点自身的形状**（2026-10-08 补）：圆角只写在内层
  「裁图节点」上、`shadow` 挂在外层**没有 `borderRadius`** 的容器上 ⇒ 阴影按**直角矩形**画，
  在卡的圆角外露出四个直角，读作「封面圆角了、但阴影衬托出矩形」（用户原话）。
  ⇒ **两处都要写 `borderRadius`**：内层裁内容 + **外层（挂 shadow 的那层）给形状**。
  排查：`grep -rn "\.shadow({" -B 6 entry/src/main/ets --include=*.ets`，逐处确认**同节点**有 `borderRadius`。
- ⚠️⚠️ **父滚动容器默认 `CONTENT_ONLY` ⇒ 阴影在 padding 区被裁**（2026-10-08 第三处独立成因）：
  官方文档原文：**「Grid、Scroll 的默认值为 `ContentClipMode.BOUNDARY`，List、WaterFlow 的
  默认值为 `ContentClipMode.CONTENT_ONLY`」**，而 `CONTENT_ONLY = 0` 的定义是
  **"Clip to content rect inside margin & padding"**（按**扣掉 padding 的内容区**裁剪）。
  ⇒ `List` 挂了 `.padding({ left:16, right:16 })` 时，子项阴影向左右扩散的部分落在
  **padding 区**⇒ **被裁掉**（症状：**只有左右被切平**，上下正常）。这与"父容器 padding 是
  阴影落脚点"的直觉**相反** —— **空间存在 ≠ 可绘制**。
  修法：`List().clipContent(ContentClipMode.BOUNDARY)`（= 裁到组件外框、**含 padding**、不含 margin）。
  ⚠️ 至此「阴影被裁」共**三处独立成因，别合并记**：① 同节点 `clip(true)+shadow`；
  ② shadow 节点无 `borderRadius`；③ 父滚动容器默认 `CONTENT_ONLY`。

### 10. ⚠️⚠️ `Tabs`/`HdsTabs` 的 `onChange` **在切换动画结束后**才触发（2026-10-08）

**症状**：左右滑动切 tab **不跟手** —— 内容页已跟手到位，**底部 tabBar 高亮才切**
（点击切换则读作"页面先过去、高亮过一会儿再亮"）。

**根因**（SDK 文档明写）：`TabContent` 的高亮若读 `currentIndex`，而 `currentIndex`
只在 `onChange` 更新，就必然滞后**整段动画时长**。

| 回调 | 触发时机 |
|---|---|
| `onChange(index)` | 切换动画**结束后** |
| `onAnimationStart(index, target)` | 动画**起手**（松手过阈值那一刻） |
| `onSelected` / `onUnselected` | 动画起手（Hds **6.1.0(23)** 起，低 compatibility 会闪退） |
| `onGestureSwipe` / `onContentDidScroll` | **逐帧** —— ⚠️ **HdsTabs 未透出**（仅标准 `Tabs` 有） |

**判据**：同页标题栏正常（读的是 `onAnimationStart` 写的 `chromeIndex`）、**只有底部高亮滞后**
⇒ 唯一差异就是读的索引不同。

**修法**：**tabBar 选中态与标题栏同源，都读 `chromeIndex`**（由 `onAnimationStart` 在动画起手
写 targetIndex）；`currentIndex` 只保留给受控 `index` 与 `onChange` 兜底。

- ⚠️ **做不到"拖动中随位移渐变高亮"**：需要逐帧的 `onGestureSwipe`/`onContentDidScroll`，
  HdsTabs 没透出。本修法把滞后收敛到**松手过阈值那一刻**，是 HdsTabs 上限。
- 排查：`grep -rn "currentIndex ===" entry/src/main/ets --include=*.ets`（tabBar 高亮读它即错）。

### 11. ⚠️ **订阅一个"从未被写入"的 `@StorageLink` 键 = 静默死代码**（2026-10-08）

**症状**：`@StorageLink('someKey')` 的组件"看着接好了"，但值**永远是初始值** ——
父页面改了对应状态，本组件毫无反应。**编译不报错、运行不报错、日志也没有**。

**根因**：`@StorageLink` 只订阅**键名**。若全项目从未 `AppStorage.setOrCreate('someKey', …)`，
该键不存在 ⇒ 本组件读到的是自己声明的默认值 ⇒ **永不更新**。

> **实证**：某组件订阅 `'homeCurGroup'` / `'homeCurSegment'` 想跟随父页面的分组切换 ——
> 但父页面的 `curGroup`/`curSegment` 是 **`@State`**（**不广播**到 AppStorage）。
> `grep` 该键**零写入点** ⇒ 分组联动是死代码，且**分段过滤完全没做**（取全库 ⇒ 混着别的类型）。

**口径**：**新增"订阅某键"前先 grep 该键的写入点**：
```bash
grep -rn "setOrCreate.*'<键名>'" entry/src/main/ets --include=*.ets   # 无输出 ⇒ 不能订阅
```
两条正路：① **由父 `@Prop` 透传**（状态本就在父手上；子组件不必理解任何筛选规则 ⇒
口径零漂移）—— **优先**；② 让状态持有者新增广播（适合跨页/跨组件多处消费）。

### 12. ⚠️ 枚举/档位的"钳制"写法会把新档位**静默吞掉**（2026-10-08）

**症状**：新增一档（如 `viewMode` 加"封面墙 = 2"），但**切换按钮点了没反应** ——
不报错、值也没写进去。

**根因**：老代码的白名单式钳制没跟上：
```typescript
// ✗ 旧写法：非 1 一律归 0 ⇒ 传入 2 被静默降级成 0
const mode = v === 1 ? 1 : 0;
```
**口径**：**加档位时同步审计所有钳制点**：
```bash
grep -rn "=== 1 ? 1 : 0\|> 1 ? 1\|<= 1" entry/src/main/ets --include=*.ets
```
更稳的写法是把合法值**显式列出**（`(v === 1 || v === 2) ? v : 0`）。

### 9. ⚠️ `aboutToDisappear` **不只**在"主动退出"时触发（2026-10-07 语义陷阱）
- 三种触发：① 用户主动返回（可预期）；② 进程被杀/崩溃（**不触发**）；③ **应用退到后台后系统回收该页面（照常触发）**。
- **后果**：任何靠"`aboutToDisappear`=用户主动离开"的判据**偶发失效**（用户说"有时候…"）。
- **修法**：读 `AppStorage('appInBackground')` 区分前后台 + 在"主动退出唯一入口"处显式再做一次
  （两道独立防线，任一条失效另一条仍正确；取不到键按保守方向——该做没做是破坏性的，多做一次通常不是）。

### 排查 SOP（点不动 / 不生效先看）
1. 列全部整屏覆盖层（含 `opacity 0`）。按 `zIndex` 从高到低问"它吃不吃这一下"。
2. `grep -rn "hitTestBehavior\|\.zIndex(" entry/src/main/ets --include=*.ets`。
3. 看编译产物真实节点：`<module>/build/default/cache/default/default@CompileArkTS/esmodule/debug/entry/src/main/ets/**/*.ts`
   （`__Common__` 合成节点、被丢弃的 getter 都在这里现形）。
4. 改完**真机复验**（命中类"看着对"和"点得动"是两回事，已因此白改过两轮）。

## 编译验证：本机有 CLI，别靠猜（2026-09-16 补齐）

**hvigorw 在 DevEco 安装目录里，项目根通常没有 wrapper**：

```bash
# 纯类型校验（几十秒，最常用）；$DevEco = DevEco Studio 安装根
"$DevEco/tools/hvigor/bin/hvigorw.bat" \
  --mode module -p product=default -p module=entry@default -p buildMode=debug \
  default@CompileArkTS --no-daemon
# 完整打包（含签名，能出 hap）
<同上> assembleHap --no-daemon
```

- 需要 `DEVECO_SDK_HOME`（DevEco 装好即有）+ `oh_modules`（`ohpm install`）。
- **PowerShell 工具不回显 stdout** → `*> $env:TEMP\b.log` 重定向，再 `Read`；日志是 **UTF-16**，
  先用 python 转码（`d.decode('utf-16')`）再读，否则被当二进制拒读。
- **判定"错误是不是我引入的"**：删掉整个 `<module>/build` 全量重编 —— 若错误**一模一样**，
  就是真实的源码错误（不是增量/缓存问题）；再配合 `git status` 看报错文件是否被自己改过。
  别急着改，先分清"自己引入的"和"HEAD 本来就坏的"（后者要么一并修，要么明确报告）。

## 静态预检（CLI 不可用时，用于捕获 Cannot find name / xxx is not exported）

跑不了 hvigor CLI 时，用下面的 Python 扫描替代第一道防线。**注意 report 会误报**：十六进制色串（`#FFFFFF`）、`JSON`、`export class Foo { static readonly NONE }` 的静态成员、`xxx.ENUM` 成员访问都会命中"大写标识符"规则；只把**独立出现且非注释行**的当真。

```python
# 1) 未定义的大写标识符：负向后顾排除成员访问 (?<![.\w])，跳过 // 与 * 注释行
use_pat = re.compile(r'(?<![.\w])([A-Z][A-Z0-9_]{3,})\b')
# 2) import 符号 vs 目标文件 export 一致性
EXPORT = r'export\s+(?:const|let|var|class|enum|interface|type|function)\s+(\w+)'   # ← function 必须带上，否则 export function 被误报
#    还要处理 `export { a, b }` 与 `@Builder @Component export struct X`
#    路径解析：os.path.normpath(join(dirname(file), target)) + '.ets'   ← 漏加 .ets 会全体 TARGET-MISSING
# 3) 括号/引号平衡：count('{')-count('}')、count('(')-count(')')
```

**Edit 工具的隐性风险（真实踩过）**：`old_string` 若覆盖到 `const XXX: number = 4;` 这一行，而 `new_string` 只留注释、忘记重写 const/去掉原本行，符号就凭空消失，报 `Cannot find name 'XXX'`。
判据：**改动涉及抽常量/重命名时，改完必须 grep 该符号的「定义处」与「引用处」同在**，不能只 grep 引用。

## 修复流程
1. 收日志 → 按文件统计错误分布，找根错误文件。
2. 修自定义组件自身 → 清调用页级联。
3. 对照上面 API 铁律逐一核对。
4. 先跑上面静态预检（尤其"抽常量/重命名"类的结构性改动），再交给用户进 DevEco。
5. grep 验证无残留：`Color(`, `blendOpacity`, `createHash/createHmac`, `randomBytes`, `size: N`, `alignSelf(VerticalAlign|HorizontalAlign`, `@Builder` 内 `const`。
6. 让用户在 DevEco 重跑；有新错继续，旧日志别反复用。
