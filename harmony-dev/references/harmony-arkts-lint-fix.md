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
