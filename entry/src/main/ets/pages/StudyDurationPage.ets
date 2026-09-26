import { common } from '@kit.AbilityKit';
import router from '@ohos.router';
import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { SUB_PAGE_CONTENT_OVERLAP } from '../components/HdsSubPageLayout';
import { createHdsSubPageTitleBarOptions } from '../components/HdsSubPageTitleBarOptions';
import { StudyDaily } from '../model/StudyStats';
import { DatabaseService } from '../services/DatabaseService';
import { StatisticsService } from '../services/StatisticsService';
import { Constants } from '../utils/Constants';
import { ThemeColor } from '../utils/ThemeColor';

interface StudyDurationPageParams {
  timeTab?: string;
}

@Entry
@Component
struct StudyDurationPage {
  @State private isLoading: boolean = true;
  @State private dailyStats: StudyDaily[] = [];
  @State private totalMinutes: number = 0;
  @State private avgMinutes: number = 0;
  @State private bestDay: string = '';
  @State private bestMinutes: number = 0;
  @StorageLink('resolvedDarkMode') darkMode: boolean = false;
  @StorageLink('materialEffectMode') materialEffectMode: number = Constants.DEFAULT_MATERIAL_EFFECT_MODE;
  @State private timeFilter: string = '全部';
  @State private ascending: boolean = false;
  private pageScroller: Scroller = new Scroller();

  private readonly filterOptions: string[] = ['全部', '日', '周', '月', '年'];
  private readonly sortOptions: string[] = ['最新', '最早'];

  aboutToAppear(): void {
    this.applyRouterParams();
    this.loadData();
  }

  onPageShow(): void {
    this.loadData();
  }

  private applyRouterParams(): void {
    const params: StudyDurationPageParams = router.getParams() as StudyDurationPageParams;
    if (params && params.timeTab && this.isValidTimeFilter(params.timeTab)) {
      this.timeFilter = params.timeTab;
    }
  }

  private isValidTimeFilter(filter: string): boolean {
    return filter === '全部' || filter === '日' || filter === '周' || filter === '月' || filter === '年';
  }

  private async loadData(): Promise<void> {
    this.isLoading = true;
    try {
      const context = getContext(this) as common.Context;
      await DatabaseService.init(context);
      let raw: StudyDaily[];
      if (this.timeFilter === '全部') {
        raw = await StatisticsService.getAllDailyStats();
      } else if (this.timeFilter === '年') {
        // 年模式：按月聚合 12 个月
        raw = await StatisticsService.getPeriodDailyStats('月', 12);
      } else {
        raw = await StatisticsService.getRecentDailyStats(this.getFilterDays());
      }
      this.dailyStats = raw;
      // 按排序方向排列
      if (!this.ascending) {
        this.dailyStats = [...raw].reverse();
      }

      let totalSec: number = 0;
      let maxSec: number = 0;
      let maxDay: string = '';
      for (let i: number = 0; i < raw.length; i++) {
        totalSec += raw[i].duration;
        if (raw[i].duration > maxSec) {
          maxSec = raw[i].duration;
          maxDay = raw[i].date;
        }
      }
      this.totalMinutes = totalSec / 60;
      this.avgMinutes = raw.length > 0 ? totalSec / 60 / raw.length : 0;
      this.bestMinutes = maxSec / 60;
      this.bestDay = maxDay;
    } catch (error) {
      console.error('StudyDurationPage loadData failed: ' + JSON.stringify(error));
    } finally {
      this.isLoading = false;
    }
  }

  private formatDate(dateStr: string): string {
    const parts: string[] = dateStr.split('-');
    if (this.timeFilter === '年') {
      // 月度标签 YYYY-MM → "M月"
      if (parts.length >= 2) {
        return parseInt(parts[1]).toString() + '月';
      }
      return dateStr;
    }
    // 每日标签 YYYY-MM-DD → "M/D"
    if (parts.length >= 3) {
      return parseInt(parts[1]).toString() + '/' + parseInt(parts[2]).toString();
    }
    return dateStr;
  }

  private getFilterDays(): number {
    if (this.timeFilter === '日') {
      return 1;
    } else if (this.timeFilter === '周') {
      return 7;
    } else if (this.timeFilter === '月') {
      return 31;
    } else if (this.timeFilter === '年') {
      return 365;
    }
    return 30;
  }

  private getFilterLabel(): string {
    if (this.timeFilter === '日') {
      return '今日';
    } else if (this.timeFilter === '周') {
      return '近7天';
    } else if (this.timeFilter === '月') {
      return '近31天';
    } else if (this.timeFilter === '年') {
      return '近12个月';
    }
    return '全部';
  }

  private getDuration(day: StudyDaily): number {
    return day.duration / 60;
  }

  private toggleSort(): void {
    this.ascending = !this.ascending;
    this.dailyStats = [...this.dailyStats].reverse();
  }

  private getSortLabel(): string {
    return this.ascending ? '最早' : '最新';
  }

  private onSortChange(option: string): void {
    const nextAscending: boolean = option === '最早';
    if (this.ascending !== nextAscending) {
      this.ascending = nextAscending;
      this.dailyStats = [...this.dailyStats].reverse();
    }
  }

  @Builder
  private buildFilterMenu() {
    Menu() {
      ForEach(this.filterOptions, (option: string) => {
        MenuItem({ content: option })
          .contentFont({ size: 16, weight: FontWeight.Normal })
          .onClick(() => {
            this.timeFilter = option;
            this.loadData();
          })
      }, (option: string) => option)
    }
  }

  @Builder
  private buildSortMenu() {
    Menu() {
      ForEach(this.sortOptions, (option: string) => {
        MenuItem({ content: option })
          .contentFont({ size: 16, weight: FontWeight.Normal })
          .onClick(() => {
            this.onSortChange(option);
          })
      }, (option: string) => option)
    }
  }

  pageTransition() {
    PageTransitionEnter({ duration: 180, curve: Curve.EaseOut }).opacity(0)
    PageTransitionExit({ duration: 140, curve: Curve.EaseIn }).opacity(0)
  }

  build() {
    HdsNavDestination() {
      if (this.isLoading) {
        Text('正在加载...')
          .fontSize(16)
          .fontColor(this.darkMode ? '#CBD5E1' : ThemeColor.get(this.darkMode).textSecondary)
          .margin({ top: 16 })
      } else {
        List({ scroller: this.pageScroller }) {
          ListItem() {
            // 汇总卡片
            Row() {
              // 总时长
              Column() {
                Text(this.totalMinutes.toFixed(1))
                  .fontSize(32)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#8B5CF6')
                  .textAlign(TextAlign.Center)
                  .width('100%')
                Text(this.getFilterLabel() + '学习时长')
                  .fontSize(12)
                  .fontColor(this.darkMode ? '#94A3B8' : '#8C8CA8')
                  .textAlign(TextAlign.Center)
                  .width('100%')
                  .margin({ top: 4 })
                Text('分钟')
                  .fontSize(11)
                  .fontColor(this.darkMode ? '#64748B' : '#B0B0C8')
                  .textAlign(TextAlign.Center)
                  .width('100%')
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Center)
              .layoutWeight(1)

              Column().width(1).height(60).backgroundColor(this.darkMode ? '#334155' : '#E0E0E8')

              // 日均
              Column() {
                Text(this.avgMinutes.toFixed(1))
                  .fontSize(32)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#10B981')
                  .textAlign(TextAlign.Center)
                  .width('100%')
                Text('日均学习时长')
                  .fontSize(12)
                  .fontColor(this.darkMode ? '#94A3B8' : '#8C8CA8')
                  .textAlign(TextAlign.Center)
                  .width('100%')
                  .margin({ top: 4 })
                Text('分钟')
                  .fontSize(11)
                  .fontColor(this.darkMode ? '#64748B' : '#B0B0C8')
                  .textAlign(TextAlign.Center)
                  .width('100%')
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Center)
              .layoutWeight(1)

              Column().width(1).height(60).backgroundColor(this.darkMode ? '#334155' : '#E0E0E8')

              // 最佳
              Column() {
                Text(this.bestMinutes.toFixed(1))
                  .fontSize(32)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#F59E0B')
                  .textAlign(TextAlign.Center)
                  .width('100%')
                Text('单日最高')
                  .fontSize(12)
                  .fontColor(this.darkMode ? '#94A3B8' : '#8C8CA8')
                  .textAlign(TextAlign.Center)
                  .width('100%')
                  .margin({ top: 4 })
                Text(this.formatDate(this.bestDay))
                  .fontSize(11)
                  .fontColor(this.darkMode ? '#64748B' : '#B0B0C8')
                  .textAlign(TextAlign.Center)
                  .width('100%')
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Center)
              .layoutWeight(1)
            }
            .width('100%')
            .padding(20)
            .backgroundColor(this.darkMode ? '#111827' : Color.White)
            .border({ width: 1, color: this.darkMode ? '#334155' : '#E2E8F0' })
            .borderRadius(18)
            .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
            .margin({ top: 12 })
          }
          .width('100%')
          .reuseId('study-duration-summary')

          ListItem() {
            // 每日明细列表
            Row() {
              Text('每日学习记录')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.darkMode ? '#F8FAFC' : '#1A1A2E')
              Blank()
              // 时间筛选下拉（bindMenu）
              Row() {
                Text(this.timeFilter)
                  .fontSize(12)
                  .fontColor(this.darkMode ? '#CBD5E1' : '#666666')
                Text('▼')
                  .fontSize(8)
                  .fontColor(this.darkMode ? '#CBD5E1' : '#666666')
                  .margin({ left: 3 })
              }
              .alignItems(VerticalAlign.Center)
              .padding({ top: 4, bottom: 4, left: 10, right: 10 })
              .borderRadius(8)
              .backgroundColor(this.darkMode ? '#1E293B' : '#F1F5F9')
              .bindMenu(this.buildFilterMenu())
              // 排序切换
              Row() {
                Text(this.getSortLabel())
                  .fontSize(12)
                  .fontColor(this.darkMode ? '#CBD5E1' : '#666666')
                Text('▼')
                  .fontSize(8)
                  .fontColor(this.darkMode ? '#CBD5E1' : '#666666')
                  .margin({ left: 3 })
              }
              .alignItems(VerticalAlign.Center)
              .padding({ top: 4, bottom: 4, left: 10, right: 10 })
              .borderRadius(8)
              .backgroundColor(this.darkMode ? '#1E293B' : '#F1F5F9')
              .bindMenu(this.buildSortMenu())
              .margin({ left: 6 })
            }
            .width('100%')
            .margin({ top: 24, bottom: 12 })
          }
          .width('100%')
          .reuseId('study-duration-filter')

            ForEach(this.dailyStats, (day: StudyDaily, index: number) => {
              ListItem() {
                Column() {
                  Row() {
                    Text(this.formatDate(day.date))
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.darkMode ? '#F8FAFC' : '#1A1A2E')
                      .layoutWeight(1)

                    Text(this.getDuration(day).toFixed(1) + ' 分钟')
                      .fontSize(13)
                      .fontColor(this.darkMode ? '#CBD5E1' : '#555570')

                    Text(this.getDuration(day) > 0 ? '学习' : '休息')
                      .fontSize(11)
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                      .backgroundColor(this.getDuration(day) > 0 ? 'rgba(139, 92, 246, 0.12)' : 'rgba(148, 163, 184, 0.12)')
                      .fontColor(this.getDuration(day) > 0 ? '#8B5CF6' : '#94A3B8')
                      .borderRadius(8)
                      .margin({ left: 8 })
                  }
                  .width('100%')

                  // 进度条
                  Row() {
                    Column()
                      .width((Math.min(this.getDuration(day), this.bestMinutes) / Math.max(this.bestMinutes, 1) * 100).toString() + '%')
                      .height(4)
                      .backgroundColor(this.getDuration(day) > 0 ? '#8B5CF6' : '#E8E4F0')
                      .borderRadius(2)
                    Column()
                      .layoutWeight(1)
                      .height(4)
                      .backgroundColor(this.darkMode ? '#2A2A3E' : '#F0EDF6')
                      .borderRadius(2)
                  }
                  .width('100%')
                  .margin({ top: 6 })
                }
                .width('100%')
                .padding(14)
                .backgroundColor(this.darkMode ? '#111827' : Color.White)
                .border({ width: 1, color: this.darkMode ? '#334155' : '#E2E8F0' })
                .borderRadius(12)
                .shadow({ radius: 10, color: 'rgba(15, 23, 42, 0.05)', offsetY: 4 })
                .margin({ bottom: 8 })
              }
              .width('100%')
              .reuseId('study-duration-record')
            }, (day: StudyDaily, index: number) => day.date + index.toString())

          ListItem() {
            Column().width('100%').height(24)
          }
          .width('100%')
          .reuseId('study-duration-bottom-spacer')
        }
        .width('100%')
        .height('100%')
        .padding({ left: 20, right: 20 })
        .contentStartOffset(-SUB_PAGE_CONTENT_OVERLAP)
        .contentEndOffset(SUB_PAGE_CONTENT_OVERLAP)
        .cachedCount(6)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .enableScrollInteraction(true)
        .friction(0.75)
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .titleBar(createHdsSubPageTitleBarOptions('学习时长', this.darkMode, this.materialEffectMode))
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

