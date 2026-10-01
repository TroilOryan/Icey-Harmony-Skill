---
name: harmony-material-layer
description: HarmonyOS/ArkTS 沉浸光感（ImmersiveMaterial / uiMaterial / Hds systemMaterialEffect）完整落地方案：强度方向定案（强=更薄更透）、官方系统策略默认档表（标题栏 ULTRA_THIN、底栏 THIN、按钮选择类 THIN、弹窗 THICK+；裸材质默认 REGULAR 是坑）、四种材质 scope（search/menu/sheet/system）与挡位映射、封面色调材质（tinted）、组件级 MaterialLayer + Toggle 绕过法、挡位实时生效三件套（@StorageLink 直传 / ForEach key 重建 / builder 传参）、反色夹薄坑、@Builder 值参数不响应、HdsNavigation 标题栏模糊跨页残留根治、材质浮层位置与过渡。当需要给卡片/按钮/搜索框加毛玻璃光感、自建材质与系统/Hds 观感不统一（偏实/偏薄/挡位无感）、切挡位不实时、或切页残留模糊时使用。
agent_created: true
---

# Harmony 沉浸光感（ImmersiveMaterial / MaterialLayer）

## 结论（先读）

- **强度方向（2026-09-24 用户定案，反转旧方案）**：**「强」= 材质更薄 / 透明度更高**（对齐 Hds EXQUISITE 精致玻璃），「弱」= 最厚最磨砂。所有映射表（style / materialColor / 兜底 blur）必须同向，改一张必查其余——旧映射把「强」喂成最厚是历史教训。
- **两套枚举无官方换算表**：`hdsMaterial.MaterialLevel`（EXQUISITE=0 / GENTLE=1 / SMOOTH=2 / ADAPTIVE=10，档位语义，Hds 组件用）vs `uiMaterial.ImmersiveStyle`（ULTRA_THIN=0~ULTRA_THICK=4，厚薄语义，自建材质用）。应用内挡位 0/1/2=强/平衡/弱、10=自适应。
- **官方《组件适配沉浸光感》系统策略默认档**（2026-09-24 官方文档核实）：Navigation 标题栏 = **ULTRA_THIN**、底部页签(悬浮) = **THIN**、按钮/选择类（ToggleType.Button 同 Button）= ULTRA_THIN/THIN、Menu/Toast/索引条弹窗 = THICK、Dialog = ULTRA_THICK。
- ⚠️ **裸 `new uiMaterial.ImmersiveMaterial({applyShadow:true})` 落在 `ImmersiveOptions` 默认 REGULAR(2)**——比标题栏系统策略厚两档（用户实测「自适应卡片明显比标题栏更不透明」的根因，官方文档坐实）。正解：`materialSystem(style)` **显式传系统策略档位**（自适应卡片传 0 对齐标题栏、浮列表小组件传 1 对齐底栏）+ materialColor 显式透明。**别再相信"裸材质=跟随系统"的旧结论。**
- 想让材质**底色跟随页面主色**（封面/主题色）→ `materialTinted`（主色半透明着色 + 关自动反色），不要靠系统深浅着色。

## 一、材质对象构造（@kit.ArkUI 的 uiMaterial）

```ts
import { uiMaterial } from '@kit.ArkUI';

// 按场景取档（方向：强=薄 → 弱=厚，见第二节映射表）
new uiMaterial.ImmersiveMaterial({
  style: SettingsManager.systemMaterialStyleFor('menu'),
  materialColor: SettingsManager.systemMaterialColor(),   // 按挡位 22%~50% 着色，深浅色跟随主题
  colorInvert: true,                                        // 自动反色（材质够薄才生效）
  applyShadow: true,
});
```

- **API < 26 时 `materialFor` 返回 undefined** → 调用方必须有兜底（半透明底 + `backgroundBlurStyle`）。
- **`ImmersiveOptions` 默认值**（SDK `@ohos.arkui.uiMaterial.d.ts`）：style=REGULAR、materialColor=Color.Transparent、applyShadow=true——这只是"裸默认"，**不是**系统策略口径；跟随系统策略要显式传档（见下）。

## 二、四种 scope + 挡位映射（强→弱，2026-09-24 方向反转后）

| scope | 场景 | 挡位映射（强→平衡→弱，自适应） | 备注 |
|---|---|---|---|
| `'search'` | 浮动工具栏 / 搜索框 | ULTRA_THIN(0)→THIN(1)→REGULAR(2)，自适应=THIN(1) | ⚠️ 被「光感自动反色」`min(base,1)` **夹薄**：开反色时强/平衡全压 THIN → **挡位差异被抹平，切换无感**。卡片类勿用 |
| `'menu'` | 菜单 / Toast / 设置卡片 | THIN(1)→REGULAR(2)→THICK(3)，自适应=THICK(3)* | 挡位阶梯完整。⚠️ **MaterialLayer 默认 scope='search' 是坑**——卡片类调用必须显式传 'menu'（漏传即薄一档，全局审计定案） |
| `'sheet'` | 弹窗 | REGULAR(2)→THICK(3)→ULTRA_THICK(4)，自适应=ULTRA_THICK(4) | |
| `'system'` | **浮在列表内容之上的小组件** | 固定 THIN(1)（显式，对齐底部页签策略） | materialColor 显式透明 |

*menu/sheet 的自适应值仅 tinted 材质与兜底路径使用；MaterialLayer 的自适应挡**短路**走 `materialSystem(0)`（见第四节），不查此表。

**着色（`systemMaterialColor`，深浅色跟随主题）**：强=`#38`(22%)最透 / 平衡=`#59`(35%) / 弱=`#80`(50%)最磨砂 / 自适应=`#6B`(42%)。
**API<26 兜底 blur 同向**：强=COMPONENT_THIN → 平衡=COMPONENT_REGULAR → 弱/自适应=COMPONENT_THICK。

```ts
/// 跟随系统策略的薄材质：显式传 ImmersiveStyle 数值（0=ULTRA_THIN 1=THIN），勿回退裸默认
static materialSystem(style: number = 1): uiMaterial.ImmersiveMaterial | undefined {
  if (!SettingsManager.materialAvailable()) return undefined;
  return new uiMaterial.ImmersiveMaterial({
    style: style,
    materialColor: Color.Transparent,   // 系统策略不额外着色
    applyShadow: true,
  });
}
```

## 三、封面色调材质（tinted）——材质底色跟随页面主色

```ts
static materialTinted(scope: string, tintColor: string): uiMaterial.ImmersiveMaterial | undefined {
  return new uiMaterial.ImmersiveMaterial({
    style: SettingsManager.systemMaterialStyleFor(scope),
    materialColor: CoverColorExtractor.withAlpha(tintColor, 0.24),  // 主色 24% 半透明着色
    colorInvert: false,       // ⚠️ 关自动反色——文字/图标对比色由调用方按主色亮度自控，反色方向不可控
    applyShadow: true,
  });
}
```

- 用途：听歌报告「保存」按钮 / 详情页「播放全部」按钮——光感底色跟随封面/页面主色（深封面→深玻璃底，浅封面→浅玻璃底），不出现系统深浅着色的"黑白"观感。
- 文字色配对：`textColorOnBackground(tintColor)`（按主色亮度选浅字/深字），次色用 `withAlpha(主文字色, 0.55)`。

## 四、组件级 MaterialLayer + Toggle 绕过法

> 材质（ImmersiveMaterial）只能通过**系统组件属性**挂载，ArkUI 没有"给任意形状上材质"的属性——用 Toggle 绕过法（Toggle 属官方"按钮与选择类"，页面内任意区域生效）。

```ets
// 不可见 Toggle 当"承载层"，把材质画成需要的圆角（layerRadius），材质不采样兄弟节点 →
// SymbolGlyph/文字作为兄弟节点叠在它上面，靠上层内容透出
MaterialLayer({ layerRadius: this.size / 2, scope: 'system', active: this.materialOn() })
SymbolGlyph($r('sys.symbol.local_fill'))
```

- `MaterialLayer` 内部 `layerMaterial()` 分流：`tintColor` 非空 → `materialTinted`；**挡位=10（自适应）短路 → `materialSystem(0)`（ULTRA_THIN，对齐标题栏）**；`scope==='system'` → `materialSystem(1)`（THIN，对齐底栏）；否则 `materialFor(scope)`。
- **挡位实时**：`ForEach([this.materialLevel], key = 'mlv-${lv}-...')` 强制销毁重建承载 Toggle——**systemMaterial 对同一节点换材质对象不重应用**，节点重建是唯一可靠手法（2026-09-15 实时重建失败的根因）。
- 五条硬约束（少一条材质画不出来）：matchParent 尺寸 / borderRadius 与外壳一致 / backgroundColor 显式透明 / enabled+focusable+accessibilityLevel('no')+hitTestBehavior(None) / systemMaterial 放最后。
- **兜底**（材质不可用/低版本）：`backgroundColor` 半透明 + `backgroundBlurStyle` 挡位与 scope 同口径同向（见第二节 blur 行）。

## 五、铁律：组件内读 AppStorage 不订阅 = 不实时

组件 `build()` 里调 `SettingsManager.materialFor(...)`（内部 `AppStorage.get`）**不建立响应式依赖**——档位变了 build 不会重跑，材质留在旧挡位。

```ets
// 必须 @StorageLink 绑定 + build 内引用（恒真条件即可，只为建依赖）
@StorageLink('settings_materialLevel') materialLevel: number = 10;
// build: .active(this.active && this.materialLevel >= 0)
```

### 五之二、铁律续：`@Builder` 的值参数不响应 → 带状态的小控件必须做成 `@Component`

同一条"不建依赖就不刷新"的规律，**不止 AppStorage，`@Builder` 的参数也一样**：

```ets
// ✗ 反例：active 是值参数，点击后不会重跑 pill(label, active, fn)
@Builder pill(label: string, active: boolean, fn: () => void) { Text(label) ... }
// ✓ 正解：@Component + @Prop
@Component struct ControlPill {
  @Prop label: string = '';
  @Prop active: boolean = false;
  onTap: () => void = () => {};
}
```

- 现象：点菜单胶囊**选中态不实时更新**（要退到主界面再进来才对）。
- ⚠️ 更贵的代价：这类"假死"会**掩盖别处的真 bug**——Icey-Stars 里"亮星名全部消失"曾被误判为"名称开关点了没反应"，实际是两个独立缺陷叠加。排查顺序：先确认开关**真的**改了状态（日志/状态栏文本），再查渲染。

## 六、挡位实时生效三件套（2026-09-24 反转 09-16 的「重启生效」旧定案）

切挡位**全局实时，无需重启**（「调整后重启应用生效」副标题与硬重启链路已废弃，勿恢复）：

1. **Index 主页**（底栏 / 主页标题栏）：`@StorageLink('settings_materialLevel')` 直传 `materialLevel` → build 内读取 → 变化触发 build 重跑 → 属性重应用。
2. **内容区 MaterialLayer**：@StorageLink + ForEach key 销毁重建（第四节）。
3. **子页 / 详情页 / 报告页标题栏**（NavDestination 宿主）：宿主加 @StorageLink 并**透传给 titleBar builder**（`buildSubPageTitleBar(..., materialLevel?)` / `buildDetailTitleBar(..., materialLevel?)`）——⚠️ 映射函数内部读 static SettingsManager 框架**追踪不到**，必须经参数把读取拉进 build，否则标题栏只在进页时构建一次、切挡位不实时。

## 七、深浅色坑

- `colorMode` 必须显式跟**应用内**深浅（`ThemeColorMode.DARK/LIGHT`），别用 `SYSTEM`：应用可强制浅色而系统是深色 → 材质色反相（浅色面板拿到深色材质 = 发灰）。
- 低版本兜底 `backgroundBlurStyle` 的 `colorMode` 同理。

## 八、相邻坑：HdsNavigation 标题栏模糊会"跨页残留"

**现象**：设置页顶部模糊**影响到首页**（切回首页仍有一层玻璃/发灰）。

**根因**：HdsNavigation 默认标题栏的 scroll effect 是 `GRADIENT_BLUR`，**模糊采样是窗口级**——A tab 激活后的残留状态被 B tab 继承。

**正解**：主 nav 的 title bar **显式关掉 scroll effect + 透明掩码**（`scrollEffectOpts: { enableScrollEffect: false }`），所有 tab 共用同一构造器；确需顶部模糊就自己画组件级 `backgroundBlurStyle`。子页保留滚动模糊时，注意 maskExtraHeight 会把模糊带向内容方向下延（本项目 28vp），首卡留白必须扣掉这段，否则"被标题栏模糊区域覆盖"。

## 九、材质浮层的位置与过渡（FAB + 面板）

**根因**：`Column` 顺序布局 + `if (showPanel)`——面板收起时把 FAB 往上顶。

**正解**：`Stack({ alignContent: Alignment.BottomEnd })` + 面板**常驻挂载**，只做纯属性动画：

```ets
Stack({ alignContent: Alignment.BottomEnd }) {
  this.controlPanel()   // 常驻；opacity/translate + .animation 收起
    .hitTestBehavior(this.showPanel ? HitTestMode.Default : HitTestMode.None)
  this.fab()            // 位置只由 Stack 决定 → 恒定，不会跳
}
```

- 收起态必须 `hitTestBehavior(None)`，否则透明面板仍吃点击。
- **Icey Rule**：材质浮层动画只用纯属性动画（opacity/translate/transition），不要 `animateTo` 混用。

## 十、验证

- 材质是否生效：切深浅色 + 各挡位截图对比；重点看**同屏三处一致性**——标题栏 / 底栏 / 卡片（偏实 = 重着色或档位不对；自适应挡三者应基本一致）。
- 挡位实时：开着设置页切挡位，标题栏/底栏/卡片三处应同时变化，无需重启或重进页面。
- 性能：材质在平移/动画帧会重算，大面积面板开合若掉帧 → 动画期降级（纯半透明底，到位后再挂材质）。

## 十一、Toggle 承载层完整性清单（2026-09-29 miha_hm 文档核对后补全）

参考：miha_hm 仓库《沉浸光感Toggle承载方案》（Toggle 绕过生效范围限制的完整文档）。
**「材质没渲染」八成不是材质问题，是承载层五条属性缺一条**——它不报错不警告，安静地什么都不画：

| # | 属性 | 少了会怎样 |
| --- | --- | --- |
| ① | 尺寸 `LayoutPolicy.matchParent`（外壳尺寸未定时）或**具体 vp 值** | 尺寸塌成 0，材质画不出来。⚠️ 禁止 `width('100%')` 百分比——Stack 子项百分比按「父级可用尺寸」解析（列表里=整列剩余空间），会把卡片顶大 |
| ② | `borderRadius` 与外壳一致 | Toggle 画自己的按钮图形，卡片里出现内嵌小圆角描边 |
| ③ | `backgroundColor(Color.Transparent)` 显式透明 | 不透明底色垫在材质之下，材质被盖住 |
| ④ | `enabled(false)` + `focusable(false)` + `accessibilityLevel('no')` + `hitTestBehavior(HitTestMode.None)` | 承载层抢走焦点与点击 |
| ⑤ | `attributeModifier` 挂属性链**最末**（写成方法调用 `this.carrierModifier()`） | 材质被后面的样式属性覆盖；内联对象字面量→切主题不刷新 |

- **文字按钮（Toggle 宽度由内容撑）**：Stack 由 Text 撑开后，Toggle 用 `matchParent`（实测尺寸）而不是固定高——固定高无宽的 Toggle 宽度塌陷 ≈ 0，材质整体画不出来（2026-09-29 导出按钮无光感根因）。
- **Stack 内兄弟层必须同一种尺寸写法**：一个 matchParent 一个百分比 → 覆盖范围对不上。
- **外壳不 clip 时**（溢光溢出场景），材质/沾色/光斑层各自都要带圆角。
- **图标色不要写死白色**：对齐标题栏 = `ThemeManager.colors.textPrimary` 跟深浅色；材质 `colorInvert` 与显式图标色**二选一**——invert 会把显式色再反一次，叠加后方向不可控。
- **应用级前置**：`module.json5` metadata `ohos.arkui.UIMaterial.state = "enable"`（改动后必须重新构建安装）。
- **带状态的浮层控件必须 @Component + @Prop**（@Builder 值参数不响应的三犯现场：图标钮、下拉行）——且**不要用 @Builder 再包一层 @Component 调用**：双层 @Builder 值传参链会断状态更新，调用点直接写 `<MaterialIconButton({ icon: ..., onTap: ... })>`。

## 样板

- `model/SettingsManager.ets`：`MaterialScope`（含 'system'）/ `materialFor` / `materialSystem(style)` / `materialTinted` / `systemMaterialStyleFor` / `systemMaterialColor` / `materialBlurStyle` / `materialAvailable`。
- `components/MaterialLayer/MaterialLayer.ets`：scope/自适应分流 + Toggle 绕过法 + ForEach key 重建 + 兜底。
- `model/TitleBarStyles.ets`：`buildSubPageTitleBar` / `buildDetailTitleBar` 尾参 `materialLevel?` 透传（宿主 @StorageLink 订阅）。
- 调用方：媒体库定位按钮（`scope:'system'`）、设置卡片/搜索标签（`scope:'menu'`）、听歌报告保存按钮与详情页播放全部（`tintColor`）。
