/// 设置子页标准模板（SubPageScaffold + SettingsGroupCard 分组卡片 + 三类设置项示例）
/// 设置页基础设计逻辑（对齐原工程实战结构）：
/// - 主页（SettingsTab）：SettingsGroup 分组导航卡（点击 AppRouter.push 进子页）+ 少量快捷开关
/// - 子页（本文件）：SubPageScaffold 承载标题栏滚动模糊；内容用 SettingsGroupCard
///   分组（**标题在卡片上方**，区别于 SettingsGroup 的无标题纯导航卡）；
///   项间分割线由调用方手动插入（Divider 0.5 + `cardDivider` + 左缩进 12）
///
/// ⚠️ 四条间距铁律（违反任一条都会肉眼可见地"不对齐"，2026-10-08 全部实测）：
///  ① **List 不设左右 padding** —— SettingsGroupCard 自带 `padding({left:16,right:16})`，
///     调用点再套一次就变成双倍内缩（32vp），卡片与页面边缘对不齐。
///  ② **顶部留白 = `SafeArea.top + 72`**（状态栏 + MINI 标题栏 + 间距），不要硬编码 112/64。
///     若本组件传了 `titleBottomBuilder`（标题栏内搜索框区），还要**再加**该区高度。
///  ③ **卡内分割线用 `cardDivider`**（比 `divider` 淡一档），否则 20% 的 divider
///     在半透明毛玻璃卡上会显成"一条条白线压在玻璃上"。
///  ④ **末项之后严禁再插 Divider** —— 卡片底部留白仅 6vp，尾部多余分割线会紧贴圆角下边缘。
///
/// ⚠️ 下拉菜单（SettingItem 的 `withMenu: true`）必须配对使用：
///   · 菜单内容用 `@Builder xxxMenu()` + **模块级 apply 函数**，不要在 onClick 里写 `this.setXxx`
///     （`bindMenu` 闭包内 `this` 未绑定 → 真机 `undefined is not callable` 闪退）；
///   · 通过 `menu: this.xxxMenu` 把 builder **引用**传进去（签名是 `@BuilderParam menu`，
///     不是旧版的 `menuOptions: string[]` + `onMenuPick` 回调）。
import { SafeArea } from '../../model/SafeArea';
import { ThemeManager } from '../../model/ThemeManager';
import { SettingsManager } from '../../model/SettingsManager';
import { SettingItem } from '../../components/SettingItem/SettingItem';
import { SettingsGroupCard } from '../../components/SettingsGroupCard/SettingsGroupCard';
import { SubPageScaffold } from '../../components/SubPageScaffold/SubPageScaffold';
import { promptAction } from '@kit.ArkUI';

/// 材质挡位可选项（下拉菜单用）
const MATERIAL_LEVELS: string[] = ['强', '平衡', '弱', '自适应'];

/// 当前挡位对应的展示文案（0强/1平衡/2弱/10自适应）
function materialLevelLabel(): string {
  const lv = SettingsManager.materialLevel;
  if (lv === 0) return MATERIAL_LEVELS[0];
  if (lv === 1) return MATERIAL_LEVELS[1];
  if (lv === 2) return MATERIAL_LEVELS[2];
  return MATERIAL_LEVELS[3];
}

/// ⚠️ 必须是**模块级函数**，不能是组件方法 ——
/// `bindMenu` 的 MenuItem.onClick 闭包内 `this` 未绑定到组件实例，
/// 写 `this.setXxx()` 真机直接 `undefined is not callable` 闪退。
function applyMaterialLevel(index: number): void {
  // index 0..2 对应强/平衡/弱，第 4 项"自适应"映射为 10
  const lv = index >= 3 ? 10 : index;
  SettingsManager.setMaterialLevel(lv);
}

@Component
export struct SettingsSubPage {
  /// 开关值：@StorageLink 读 AppStorage（SettingsManager 回填/更新，响应式）
  @StorageLink('settings_exampleSwitch') exampleSwitch: boolean = false;
  @StorageLink('settings_handedness') handedness: boolean = false;
  /// 材质挡位（改动会驱动 Hds systemMaterialEffect 实时重应用）
  @StorageLink('settings_materialLevel') materialLevel: number = 10;
  /// 材质自动反色开关
  @StorageLink('settings_materialColorInvert') materialColorInvert: boolean = true;
  /// 值选择（演示用 @State；持久化值同上用 @StorageLink）
  @State demoValue: string = '选项一';

  /// 材质挡位下拉菜单内容（`@Builder` 不带访问修饰符 —— 带 private 会解析中断）
  @Builder
  materialMenu() {
    Menu() {
      ForEach(MATERIAL_LEVELS, (label: string, index: number) => {
        MenuItem({ content: label }).onClick(() => {
          applyMaterialLevel(index);
        })
      })
    }
  }

  build() {
    SubPageScaffold({ title: '设置子页' }) {
      List({ space: 0 }) {
        // 顶部留白：SafeArea.top + 72（状态栏 + MINI 标题栏 + 间距）
        ListItem() {
          Row() {}.height(SafeArea.top + 72).width('100%')
        }

        // 分组一：开关组（带分组标题；项间手动插 Divider，末项后不插）
        ListItem() {
          SettingsGroupCard({ title: '通用' }) {
            Column() {
              SettingItem({
                title: '示例开关',
                subtitle: '持久化开关模板（重启保持）',
                isSwitch: true,
                switchValue: this.exampleSwitch,
                onSwitch: (v: boolean) => {
                  SettingsManager.setExampleSwitch(v);
                },
              })

              Divider()
                .strokeWidth(0.5)
                .color(ThemeManager.colors.cardDivider)
                .margin({ left: 12, right: 8 })

              SettingItem({
                title: '智感握姿',
                subtitle: '底部导航栏跟随握持手自动换边',
                isSwitch: true,
                switchValue: this.handedness,
                onSwitch: (v: boolean) => {
                  SettingsManager.setHandedness(v);
                },
              })
            }
            .width('100%')
          }
        }

        // 分组二：沉浸光感（材质挡位下拉 + 自动反色开关）
        ListItem() {
          SettingsGroupCard({ title: '外观' }) {
            Column() {
              SettingItem({
                title: '光感强度',
                subtitle: '强=更薄更透，弱=更厚更磨砂',
                value: materialLevelLabel(),
                withMenu: true,
                menu: this.materialMenu,
              })

              Divider()
                .strokeWidth(0.5)
                .color(ThemeManager.colors.cardDivider)
                .margin({ left: 12, right: 8 })

              SettingItem({
                title: '光感自动反色',
                subtitle: '由系统按背景亮度自动决定前景色',
                isSwitch: true,
                switchValue: this.materialColorInvert,
                onSwitch: (v: boolean) => {
                  SettingsManager.setMaterialColorInvert(v);
                },
              })
              // ⚠️ 末项之后不再插 Divider（卡片底部留白仅 6vp，多余分割线会贴圆角下缘）
            }
            .width('100%')
          }
        }

        // 分组三：值选择组（label/value 模式，点击弹 OptionSheet/弹窗选择）
        ListItem() {
          SettingsGroupCard({ title: '偏好' }) {
            Column() {
              SettingItem({
                title: '示例选择项',
                subtitle: '点击弹窗选择，当前值显示在右侧',
                value: this.demoValue,
                hasChevron: false,
                onTap: () => {
                  // TODO: OptionSheet / AppSheet 弹窗选择后 set 状态
                  this.demoValue = this.demoValue === '选项一' ? '选项二' : '选项一';
                },
              })
            }
            .width('100%')
          }
        }

        // 分组四：导航组（跳更深层子页/外链）
        ListItem() {
          SettingsGroupCard({ title: '更多' }) {
            Column() {
              SettingItem({
                title: '深层子页',
                subtitle: 'AppRouter.push 再进一层',
                onTap: () => {
                  // TODO: AppRouter.getInstance().push(ROUTE_XXX);
                  promptAction.showToast({ message: 'TODO: 跳转子页' });
                },
              })
            }
            .width('100%')
          }
        }

        // 尾部留白：滚到底不裁切（List expandSafeArea 底部延伸配套）
        ListItem() {
          Row() {}.height(SafeArea.bottom + 40).width('100%')
        }
      }
      .layoutWeight(1).width('100%')
      // ⚠️ 铁律①：List **不设左右 padding**（SettingsGroupCard 自带 16）
      .scrollBar(BarState.Off)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      .edgeEffect(EdgeEffect.Spring)
      .backgroundColor(Color.Transparent)
    }
  }
}
