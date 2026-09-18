/// 首页 tab（示例：列表 + 滚动渐变模糊标题栏 + 空态/加载态 + FAB 弹窗演示）
/// 布局铁律：root Column 用 layoutWeight(1) 替代 height('100%')（height 100% 在 Hds
/// TabContent 内会溢出 ~50vp）；禁止 layoutWeight(1)+justifyContent(SpaceBetween) 联用
/// （子项高度异常离屏）
import { SafeArea } from '../model/SafeArea';
import { ThemeManager } from '../model/ThemeManager';
import { AppRouter, ROUTE_HOME_DETAIL } from '../model/AppRouter';
import { AppLogger } from '../services/AppLogger';
import { SettingItem } from '../components/SettingItem/SettingItem';
import { GlassCard } from '../components/GlassCard/GlassCard';
import { EmptyState } from '../components/EmptyState/EmptyState';

@Component
export struct HomeTab {
  /// 主题版本号（父级 Index 传入——@Prop 变化触发本页重建重读 ThemeManager.colors；
  /// @StorageLink 声明未引用不触发重建，必须 @Prop 传参）
  @Prop themeVersion: number = 0;
  /// 数据加载完成（EntryAbility startupReady 恢复完打标）——避免启动闪空态
  @StorageLink('dataLoaded') dataLoaded: boolean = false;
  private scroller: Scroller = new Scroller();

  build() {
    Column() {
      // List 视口顶到屏幕顶：内容滚动时自然滑进标题栏区域（透明标题栏 + 滚动模糊盖住）
      List({ scroller: this.scroller, space: 12 }) {
        // 顶部留白（避让标题栏；内容滚动后自然滑进模糊带）
        ListItem() {
          Row() {}.height(SafeArea.top + 64)
        }

        // 示例卡片：组件演示入口
        ListItem() {
          GlassCard() {
            Column({ space: 4 }) {
              SettingItem({
                title: '组件演示子页',
                subtitle: 'SubPageScaffold + 标题栏滚动模糊 + 设置组件全家桶',
                iconSymbol: $r('sys.symbol.paintpalette'),
                onTap: () => {
                  AppRouter.getInstance().push(ROUTE_HOME_DETAIL);
                },
              })
              SettingItem({
                title: '弹窗演示',
                subtitle: 'Toast / AppSheet / ConfirmSheet 用法见 Index 与本页',
                iconSymbol: $r('sys.symbol.ellipsis_circle'),
                onTap: () => {
                  AppLogger.info('HomeTab', '弹窗演示点击（示例见 Index 根级 AppSheet）');
                },
              })
            }
            .width('100%')
          }
        }

        // 数据态三分支：加载中 / 空态 / 内容
        ListItem() {
          Column() {
            if (!this.dataLoaded) {
              // 加载态：启动恢复中（UI 优先不阻塞，加载过程有明确呈现）
              Column({ space: 12 }) {
                LoadingProgress().width(36).height(36)
                  .color(ThemeManager.colors.textSecondary)
                Text('加载中…')
                  .fontSize(13)
                  .fontColor(ThemeManager.colors.textSecondary)
              }
              .width('100%')
              .padding({ top: 80 })
              .alignItems(HorizontalAlign.Center)
            } else {
              // TODO: 你的列表内容（LazyForEach + IDataSource 长列表）
              EmptyState({ message: '暂无数据', subMessage: '数据恢复完成后显示在这里' })
                .padding({ top: 60 })
            }
          }
          .width('100%')
        }

        // 尾部留白：滚到底不裁切（barOverlap 悬浮 tabBar 遮挡底部内容）
        ListItem() {
          Row() {}.height(SafeArea.bottom + 80).width('100%')
        }
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .backgroundColor(Color.Transparent)
    }
    // root Column 铁律：layoutWeight(1) 替代 height('100%')
    .layoutWeight(1)
    .width('100%')
    .backgroundColor(Color.Transparent)
  }
}
