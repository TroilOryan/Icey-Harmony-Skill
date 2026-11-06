/// 根布局（App.ets 宿主内）——标准工程组件自检页
/// 职责：演示/验证随工程交付的基础组件链路（SettingItem / SettingsGroupCard / 设置七件套 /
/// 主题联动），新项目拷贝本工程后把本文件替换成真实首页即可（App.ets 的 Index 挂载点不变）。
/// ⚠️ 渲染路径读设置键一律 @StorageLink（静态 getter 是死依赖，见 harmony-dev 分册 lint-fix §13）。
import { SettingItem } from '../components/SettingItem/SettingItem';
import { SettingsGroupCard } from '../components/SettingsGroupCard/SettingsGroupCard';
import { SettingsManager, ThemeMode } from '../model/SettingsManager';
import { ThemeManager } from '../model/ThemeManager';

/// 沉浸光感挡位：下拉下标 ↔ 数值档（0=强 1=平衡 2=弱 10=自适应；数值口径见 SettingsManager KEY 注释）
const MATERIAL_LEVELS: number[] = [0, 1, 2, 10];
const MATERIAL_LABELS: string[] = ['强', '平衡', '弱', '自适应'];

@Component
export struct Index {
  /// 主题模式（0=跟随系统 1=浅色 2=深色）——@StorageLink 订阅，切档实时刷新
  @StorageLink('settings_themeMode') themeMode: number = ThemeMode.Follow;
  /// 屏幕常亮
  @StorageLink('settings_keepScreenOn') keepScreenOn: boolean = false;
  /// 沉浸光感挡位
  @StorageLink('settings_materialLevel') materialLevel: number = 10;

  /// 挡位数值 → 下拉下标（未匹配回自适应档）
  private materialIdx(level: number): number {
    const idx = MATERIAL_LEVELS.indexOf(level);
    return idx === -1 ? 3 : idx;
  }

  /// 页面背景：跟随主题（build 内读静态色板，themeMode 变化经 @StorageLink 触发重建后取新值）
  private pageBg(): string {
    return ThemeManager.colors.background;
  }

  build() {
    Column() {
      Text('Harmony 标准工程')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeManager.colors.textPrimary)
        .margin({ top: 24, bottom: 4 })
      Text('基建组件自检页 · 拷贝后替换本文件为真实首页')
        .fontSize(13)
        .fontColor(ThemeManager.colors.textSecondary)
        .margin({ bottom: 16 })

      Scroll() {
        Column() {
          // ⚠️ 自定义组件尾随闭包之后不能链式挂属性（10505001）——外包 Column 承接 margin
          Column() {
            SettingsGroupCard({ title: '外观' }) {
              Column() {
                SettingItem({
                  title: '主题模式',
                  subtitle: '跟随系统 / 浅色 / 深色',
                  withMenu: true,
                  menuOptions: ['跟随系统', '浅色', '深色'],
                  menuSelected: this.themeMode,
                  onMenuPick: (idx: number): void => {
                    SettingsManager.setThemeMode(idx);
                  }
                })
                SettingItem({
                  title: '屏幕常亮',
                  subtitle: '播放 / 阅读等场景的长效开关',
                  isSwitch: true,
                  switchValue: this.keepScreenOn,
                  onSwitch: (v: boolean): void => {
                    SettingsManager.setKeepScreenOn(v);
                  }
                })
                SettingItem({
                  title: '沉浸光感',
                  subtitle: '强=更薄更透，弱=最厚最磨砂',
                  withMenu: true,
                  menuOptions: MATERIAL_LABELS,
                  menuSelected: this.materialIdx(this.materialLevel),
                  onMenuPick: (idx: number): void => {
                    SettingsManager.setMaterialLevel(MATERIAL_LEVELS[idx]);
                  }
                })
              }
              .width('100%')
            }
          }
          .margin({ left: 16, right: 16, top: 4 })
        }
        .width('100%')
        .padding({ bottom: 24 })
      }
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBg())
  }
}
