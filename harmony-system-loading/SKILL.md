---
name: harmony-system-loading
description: HarmonyOS/ArkTS 首屏与加载态一律用系统 LoadingProgress 组件，禁止自绘加载动画（星点呼吸/自定义圆圈/帧动画）。当遇到「加载动画」「loading」「转圈」「首屏占位」「启动屏内容」类需求时使用；也适用于用户质疑"为什么不用华为自带的 loading"的场景。
agent_created: true
---

# HarmonyOS 加载态：系统 LoadingProgress，禁止自绘

## 铁律（2026-09-24 用户定案）

用户原话：「首屏加载动画 为什么不用华为的那个loading 这个事儿要沉淀到技能里」。

**任何等待场景（首屏加载 / 数据恢复 / 导入中 / 定位中）的加载指示器一律用系统组件 `LoadingProgress`，不要自绘动画。**

## 为什么

1. **系统语义**：LoadingProgress 是 HarmonyOS 标准加载指示器，用户在全系统（设置/应用市场/文件管理）天天见，认知零成本。
2. **主题/深浅色自动跟随**：组件内部处理了深浅色模式，自绘动画要么写死颜色，要么还得自己接 ThemeManager。
3. **无障碍跟随**：系统组件带无障碍语义，自绘的没有。
4. **零维护**：自绘的"星点呼吸"三圆 + opacity 动画没有比一个系统转圈更好看，反而多了十几行动画代码和一个 aboutToAppear 时序。

## 标准写法

```typescript
Column({ space: 18 }) {
  LoadingProgress()
    .width(40)
    .height(40)
    .color(ACCENT)          // 主题色（ThemeManager.colors.accent）；暗场固定色亦可
  Text('正在铺开星空…')
    .fontSize(14)
    .fontColor(textDim)     // 次级文字色
}
```

要点：
- 尺寸 40vp 上下的方形；**必须给 color**，默认色在某些深色背景上对比度不足。
- 配一句状态文案（"正在…"），文案短、不用进度条（用户 HUD 偏好精炼文本）。
- 等待结束的判断放业务侧（如"首帧画完"），不要用固定 setTimeout 假装加载完成。

## 同类场景判定

| 场景 | 用法 |
|---|---|
| 首屏/启动屏等待 | LoadingProgress + 一句文案 |
| 数据恢复/导入中（列表项右侧） | 小号 LoadingProgress（18vp）替代 value/箭头 |
| 定位中/上传中 | 同上，加 loading 态布尔驱动 if 切换 |
| 需要可取消 | LoadingProgress 外套按钮/文案说明，仍不自绘动画 |

反面教材（本项目 SkyMap.ets 旧实现）：三个 Circle + keyframeAnimateTo 呼吸动画 —— 已删，换 LoadingProgress。
