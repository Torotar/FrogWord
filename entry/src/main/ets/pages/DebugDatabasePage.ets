import { common } from '@kit.AbilityKit';
import router from '@ohos.router';
import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { SUB_PAGE_CONTENT_OVERLAP } from '../components/HdsSubPageLayout';
import { createHdsSubPageTitleBarOptions } from '../components/HdsSubPageTitleBarOptions';
import { DatabaseSummary, DebugService } from '../services/DebugService';
import { DatabaseService } from '../services/DatabaseService';
import { PreferencesService } from '../services/PreferencesService';
import { Constants } from '../utils/Constants';
import { ThemeColor } from '../utils/ThemeColor';

@Entry
@Component
struct DebugDatabasePage {
  @State private isLoading: boolean = true;
  @StorageLink('resolvedDarkMode') darkMode: boolean = false;
  @StorageLink('materialEffectMode') materialEffectMode: number = Constants.DEFAULT_MATERIAL_EFFECT_MODE;
  @State private summary: DatabaseSummary = {
    databaseReady: false,
    totalWords: 0,
    bookCount: 0,
    studyRecordCount: 0,
    todayLearnCount: 0,
    pendingReviewCount: 0,
    healthMessage: ''
  };
  @State private message: string = '';
  private pageScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.loadSummary();
  }

  private async loadSummary(): Promise<void> {
    this.isLoading = true;
    try {
      const context = getContext(this) as common.Context;
      await DatabaseService.init(context);
      await PreferencesService.init(context);
      this.summary = await DebugService.getDatabaseSummary();
      this.message = '数据库信息已刷新';
    } catch (error) {
      console.error('DebugDatabasePage loadSummary failed: ' + JSON.stringify(error));
      this.message = '数据库信息读取失败';
    } finally {
      this.isLoading = false;
    }
  }

  private confirmClearStudyRecords(): void {
    AlertDialog.show({
      title: '确认清空学习记录',
      message: '此操作会清空学习、复习和统计记录，单词与词书不会删除。',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '清空',
        fontColor: ThemeColor.get(this.darkMode).danger,
        action: () => {
          this.clearStudyRecords();
        }
      }
    });
  }

  private confirmResetDefaultWords(): void {
    AlertDialog.show({
      title: '确认重建默认词库',
      message: '此操作会重建默认词库，并清空默认词库相关学习记录。',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '重建',
        fontColor: ThemeColor.get(this.darkMode).danger,
        action: () => {
          this.resetDefaultWords();
        }
      }
    });
  }

  private async clearStudyRecords(): Promise<void> {
    await DebugService.clearStudyRecords();
    this.message = '学习记录已清空';
    await this.loadSummary();
  }

  private async resetDefaultWords(): Promise<void> {
    await DebugService.resetDefaultWords();
    this.message = '默认词库已重建';
    await this.loadSummary();
  }

  @Builder
  private infoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor(ThemeColor.get(this.darkMode).textSecondary)
        .width(132)
      Text(value)
        .fontSize(15)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .layoutWeight(1)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  build() {
    HdsNavDestination() {
      List({ scroller: this.pageScroller }) {
        ListItem() {
          Text('这里用于检查数据库状态和执行调试操作，请谨慎使用。')
            .fontSize(13)
            .fontColor(ThemeColor.get(this.darkMode).danger)
            .width('100%')
            .margin({ top: 12, bottom: 18 })
        }
        .width('100%')
        .reuseId('debug-database-warning')

        if (this.isLoading) {
          ListItem() {
            Text('正在读取数据库信息...')
              .fontSize(16)
              .fontColor(ThemeColor.get(this.darkMode).textSecondary)
              .margin({ top: 40 })
          }
          .width('100%')
          .reuseId('debug-database-loading')
        } else {
          ListItem() {
            Column() {
              this.infoRow('数据库状态', this.summary.databaseReady ? '正常' : '未就绪')
              this.infoRow('健康检查', this.summary.healthMessage)
              this.infoRow('单词数量', this.summary.totalWords.toString())
              this.infoRow('词书数量', this.summary.bookCount.toString())
              this.infoRow('学习记录', this.summary.studyRecordCount.toString())
              this.infoRow('今日学习', this.summary.todayLearnCount.toString())
              this.infoRow('待复习', this.summary.pendingReviewCount.toString())
            }
            .width('100%')
            .padding(18)
            .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
            .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
            .borderRadius(18)
            .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
          }
          .width('100%')
          .reuseId('debug-database-summary')

          ListItem() {
            Button('刷新数据库信息')
              .width('100%')
              .buttonStyle(ButtonStyleMode.EMPHASIZED)
              .controlSize(ControlSize.NORMAL)
              .role(ButtonRole.NORMAL)
              .margin({ top: 18 })
              .onClick(() => {
                this.loadSummary();
              })
          }
          .width('100%')
          .reuseId('debug-database-refresh')

          ListItem() {
            Button('清空学习记录')
              .width('100%')
              .buttonStyle(ButtonStyleMode.NORMAL)
              .controlSize(ControlSize.NORMAL)
              .role(ButtonRole.ERROR)
              .margin({ top: 12 })
              .onClick(() => {
                this.confirmClearStudyRecords();
              })
          }
          .width('100%')
          .reuseId('debug-database-clear-records')

          ListItem() {
            Button('重建默认词库')
              .width('100%')
              .buttonStyle(ButtonStyleMode.NORMAL)
              .controlSize(ControlSize.NORMAL)
              .role(ButtonRole.ERROR)
              .margin({ top: 12 })
              .onClick(() => {
                this.confirmResetDefaultWords();
              })
          }
          .width('100%')
          .reuseId('debug-database-reset-default')

          if (this.message.length > 0) {
            ListItem() {
              Text(this.message)
                .fontSize(14)
                .fontColor(ThemeColor.get(this.darkMode).primary)
                .margin({ top: 16 })
            }
            .width('100%')
            .reuseId('debug-database-message')
          }
        }

        ListItem() {
          Column().width('100%').height(32)
        }
        .width('100%')
        .reuseId('debug-database-bottom-spacer')
      }
      .width('100%')
      .height('100%')
      .padding({ left: 20, right: 20, top: 0 })
      .contentStartOffset(-SUB_PAGE_CONTENT_OVERLAP)
      .contentEndOffset(SUB_PAGE_CONTENT_OVERLAP)
      .cachedCount(2)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .enableScrollInteraction(true)
      .friction(0.75)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .titleBar(createHdsSubPageTitleBarOptions('开发者调试', this.darkMode, this.materialEffectMode))
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .onBackPressed(() => {
      router.back();
      return true;
    })
    .bindToScrollable([this.pageScroller])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    .backgroundColor(ThemeColor.get(this.darkMode).background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}
