> **分册：`harmony-tabbar-footer`** ｜ 2026-11-17 新增。来源：Icey-Player-Harmony 真源定案
> + 三次跨项目翻车（Icey-Remote-Desktop / Icey-Tagger / Icey-Reader，均为用户真机指出）。
> 触发场景见入口 `SKILL.md` 路由表。**新建或改动底部导航栏，先读本册——同一个错已跨项目犯过三次。**

# 底部导航栏（tabBar / 底栏）统一规范 —— player 为真源

## 结论（先读）

| 定案 | 内容 | 来源 |
| --- | --- | --- |
| 底边距公式 | `barBottomMargin = 2 + Math.max(SafeArea.bottom, DeviceProfile.is2in1() ? 12 : 0)` | player 2026-09-28 PC 适配 |
| 未选中配色 | `tabBarInactive` = **纯黑（浅色）/ 纯白（深色）**；选中 = 主题色 accent | player 2026-10-01 用户定案 |
| 核对姿势 | 凡动底栏，**必须在 PC（2in1）自由窗口截图核对**——只看手机必漏贴底 | 三次翻车教训 |

## 为什么反复翻车（三次实证台账，不许再犯）

| 日期 | 项目 | 用户原话 | 犯的错 |
| --- | --- | --- | --- |
| 11-02 | Icey-Remote-Desktop | 「底部栏的配色也参考player项目改一下 好像没选中的是纯黑纯白吧」 | 未选中用了系统灰（text3 档），光感底栏上发灰难辨 |
| 11-08 | Icey-Tagger | 「底部栏离底部的距离和player没有统一 尤其是pc端」 | 只抄了手机口径：PC 上 `SafeArea.bottom=0` 只剩 2vp，观感贴底 |
| 11-15 | Icey-Reader | 「pc端 底部的菜单栏离底部怎么没有边距」 | 同上，PC 贴底 |

**共同根因**：手机上导航指示条天然垫出 `SafeArea.bottom`，底栏"天生不贴底"；
**PC/2in1 没有导航条，`SafeArea.bottom = 0`**，任何只依赖 SafeArea 的间距方案到 PC 上全部塌掉。
⇒ **改底栏的最后一步固定动作：开 PC 自由窗口（或 2in1 全屏）截图核对，不能省。**

## 定案一：底边距公式（2026-09-28）

真源：`Icey-Player-Harmony/entry/src/main/ets/layout/Index.ets` → `barBottomMarginVp()`

```ets
/// 底栏底部间距（2026-09-28 PC 适配）：手机=2+SafeArea.bottom（导航指示条高度）；
/// 2in1/PC 无导航条 → SafeArea.bottom=0 只剩 2vp 观感贴底 → 最小给 12vp 呼吸间距
private barBottomMarginVp(): number {
  return 2 + Math.max(SafeArea.bottom, DeviceProfile.is2in1() ? 12 : 0);
}
```

要点：

- HdsTabs 底栏是**浮动栏**（`barOverlap` / `barFloatingStyle`），`barBottomMargin` 必须**显式给**，
  系统不会替你避让；不安全区方案到 2in1 上就是贴死。
- **全屏布局（沉浸 / `expandSafeArea`）后底部导航条不再自动避让**，此时 `barBottomMargin`
  还要补上导航条高度 + 2vp（player Index.ets:2559 布局转储注释原文）。
- **移植时整函数逐字照抄**，不许"看着调" 12vp，更不许把公式简化成 `SafeArea.bottom + 2`。
- 已对齐样本（可抄的落地版）：Icey-Tagger `layout/Index.ets:152`
  （同款公式 + 多选模式下收起：`barBottomMargin: this.mediaSelecting ? 0 : this.barBottomMarginVp()`）。

## 定案二：配色 token（2026-10-01）

真源：`Icey-Player-Harmony/entry/src/main/ets/model/ThemeManager.ets` → `ThemeColors`

| token | 浅色 | 深色 | 语义 |
| --- | --- | --- | --- |
| `tabBarActive` | 主题色 accent | 主题色 accent | 选中 |
| `tabBarInactive` | `#000000` 纯黑 | `#FFFFFF` 纯白 | 未选中 |

- ❌ 未选中**禁止用**系统灰 `#8E8E93` / text3 档：光感悬浮底栏是半透明材质，
  灰色叠上去**发灰、辨识度低**（Icey-Remote-Desktop Theme.ets 翻车原址；其 Theme.ets:151 已有对齐注释）。
- 图标与文字**两态都消费同一个 token**（TabItemBuilder 里 `SymbolGlyph` + `Text` 各读一次），
  改一处全局生效——**不许图标一套色、文字另一套色，更不许写死两个值**。
- 底栏容器底色与选中/未选中无关联，别顺手一起改。

## 新建 / 移植 / 改动底栏自查清单（全过才算做完）

1. 边距函数与 player 逐字一致（含 `is2in1() ? 12 : 0` 档）；
2. **PC（2in1）自由窗口截图**：底栏离屏幕底边有肉眼可见呼吸间距（≥12vp）；
3. **深浅两色各截一张**：未选中纯黑/纯白、选中主题色；
4. 手机端：距底 = 2vp + 导航条高度（`SafeArea.bottom`）；
5. 全屏/沉浸模式下最后一行内容不被导航条盖住；
6. 列表 `bottomInset` 与浮动底栏高度联动（最后一行不压在栏下）。

## 相关分册

- 主布局基建（HdsNavigation + HdsTabs）：`references/harmony-app-template.md`
- 光感材质（为什么底栏配色容易翻车：半透明材质叠色）：`references/harmony-material-layer.md`
