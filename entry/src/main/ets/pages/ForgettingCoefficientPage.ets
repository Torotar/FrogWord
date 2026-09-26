import { common } from '@kit.AbilityKit';
import router from '@ohos.router';
import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { SUB_PAGE_CONTENT_OVERLAP } from '../components/HdsSubPageLayout';
import { createHdsSubPageTitleBarOptions } from '../components/HdsSubPageTitleBarOptions';
import { SpacedRepetition, ReviewSchedule } from '../algorithm/SpacedRepetition';
import { DatabaseService } from '../services/DatabaseService';
import { PreferencesService } from '../services/PreferencesService';
import { Constants } from '../utils/Constants';
import { ThemeColor } from '../utils/ThemeColor';

@Entry
@Component
struct ForgettingCoefficientPage {
  @StorageLink('resolvedDarkMode') darkMode: boolean = false;
  @StorageLink('materialEffectMode') materialEffectMode: number = Constants.DEFAULT_MATERIAL_EFFECT_MODE;
  @State private coefficient: number = Constants.DEFAULT_FORGETTING_COEFFICIENT;
  @State private reviewGoal: number = Constants.DEFAULT_REVIEW_GOAL;
  private pageScroller: Scroller = new Scroller();

  private readonly OPTIONS: number[] = [0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0];
  private readonly RETENTION_DAYS: number[] = [1, 3, 7];

  aboutToAppear(): void {
    this.loadSettings();
  }

  private async loadSettings(): Promise<void> {
    try {
      const context = getContext(this) as common.Context;
      await DatabaseService.init(context);
      await PreferencesService.init(context);
      this.coefficient = await PreferencesService.getForgettingCoefficient();
      this.reviewGoal = await PreferencesService.getReviewGoal();
    } catch (error) {
      console.error('ForgettingCoefficientPage load failed: ' + JSON.stringify(error));
    }
  }

  private rhythmLabel(value: number): string {
    if (value <= 0.4) {
      return '轻松';
    }
    if (value <= 0.6) {
      return '均衡';
    }
    if (value <= 0.8) {
      return '稳固';
    }
    return '高强度';
  }

  private rhythmDescription(value: number): string {
    if (value <= 0.4) {
      return '复习压力较低，适合轻量学习和保持节奏。';
    }
    if (value <= 0.6) {
      return '在遗忘控制和学习负担之间保持平衡。';
    }
    if (value <= 0.8) {
      return '复习更积极，适合希望提高保持率的阶段。';
    }
    return '复习安排更密集，适合短期冲刺和重点巩固。';
  }

  private retentionAfterDays(days: number, value: number): number {
    const pressure: number = 0.75 + value;
    const stabilityDays: number = 8 / pressure;
    return Math.round(Math.exp(-days / stabilityDays) * 100);
  }

  private previewInterval(correctCount: number): number {
    const schedule: ReviewSchedule = SpacedRepetition.calculate(true, Math.max(correctCount, 1), 2.5, correctCount, 0, this.coefficient);
    return schedule.nextIntervalDays;
  }

  private optionWidth(value: number): string {
    const ratio: number = Math.max(8, Math.round(value * 100));
    return ratio.toString() + '%';
  }

  private async selectCoefficient(value: number): Promise<void> {
    this.coefficient = value;
    await PreferencesService.setForgettingCoefficient(value);
  }

  @Builder
  private buildEngineCard() {
    Column() {
      Row() {
        Column() {
          Text('当前复习节奏')
            .fontSize(13)
            .fontColor(this.darkMode ? '#C4B5FD' : '#7C6BCB')
          Text(this.rhythmLabel(this.coefficient))
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeColor.get(this.darkMode).textPrimary)
            .margin({ top: 6 })
          Text(this.rhythmDescription(this.coefficient))
            .fontSize(13)
            .fontColor(ThemeColor.get(this.darkMode).textSecondary)
            .lineHeight(20)
            .margin({ top: 8 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column() {
          Text(this.coefficient.toFixed(1))
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          Text('系数')
            .fontSize(11)
            .fontColor('rgba(255,255,255,0.78)')
        }
        .width(76)
        .height(76)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#8B5CF6')
        .borderRadius(18)
      }
      .width('100%')

      Row() {
        this.buildMetric('每日复习目标', this.reviewGoal.toString() + ' 词')
        this.buildMetric('首次答对间隔', this.previewInterval(1).toString() + ' 天')
        this.buildMetric('连续答对间隔', this.previewInterval(5).toString() + ' 天')
      }
      .width('100%')
      .margin({ top: 18 })
    }
    .width('100%')
    .padding(20)
    .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
    .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
    .borderRadius(18)
    .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
    .margin({ top: 12 })
  }

  @Builder
  private buildMetric(title: string, value: string) {
    Column() {
      Text(value)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
      Text(title)
        .fontSize(11)
        .fontColor(ThemeColor.get(this.darkMode).textSecondary)
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildCurveCard() {
    Column() {
      Text('记忆保持预估')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .width('100%')

      ForEach(this.RETENTION_DAYS, (day: number) => {
        Column() {
          Row() {
            Text(day.toString() + ' 天后')
              .fontSize(13)
              .fontColor(ThemeColor.get(this.darkMode).textSecondary)
            Blank()
            Text(this.retentionAfterDays(day, this.coefficient).toString() + '%')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#8B5CF6')
          }
          .width('100%')

          Stack({ alignContent: Alignment.Start }) {
            Row()
              .width('100%')
              .height(8)
              .backgroundColor(this.darkMode ? '#1E293B' : '#EEF2FF')
              .borderRadius(4)
            Row()
              .width(this.retentionAfterDays(day, this.coefficient).toString() + '%')
              .height(8)
              .backgroundColor('#8B5CF6')
              .borderRadius(4)
          }
          .width('100%')
          .height(8)
          .margin({ top: 8 })
        }
        .width('100%')
        .margin({ top: 16 })
      }, (day: number) => day.toString())
    }
    .width('100%')
    .padding(20)
    .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
    .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
    .borderRadius(20)
    .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
    .margin({ top: 16 })
  }

  @Builder
  private buildOptionCard() {
    Column() {
      Text('选择遗忘系数')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .width('100%')

      ForEach(this.OPTIONS, (value: number) => {
        Row() {
          Column() {
            Text(this.rhythmLabel(value))
              .fontSize(14)
              .fontWeight(this.coefficient === value ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(this.coefficient === value ? '#8B5CF6' : ThemeColor.get(this.darkMode).textPrimary)
            Text('系数 ' + value.toFixed(1))
              .fontSize(11)
              .fontColor(ThemeColor.get(this.darkMode).textSecondary)
              .margin({ top: 3 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Stack({ alignContent: Alignment.Start }) {
            Row()
              .width(68)
              .height(6)
              .backgroundColor(this.darkMode ? '#334155' : '#E9D5FF')
              .borderRadius(3)
            Row()
              .width(this.optionWidth(value))
              .height(6)
              .backgroundColor(this.coefficient === value ? '#8B5CF6' : '#C4B5FD')
              .borderRadius(3)
          }
          .width(68)
          .height(6)
          .margin({ right: 12 })

          Text(this.coefficient === value ? '当前' : '选择')
            .fontSize(12)
            .fontColor(this.coefficient === value ? Color.White : '#8B5CF6')
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(this.coefficient === value ? '#8B5CF6' : (this.darkMode ? '#2D2440' : '#F3E8FF'))
            .borderRadius(12)
        }
        .width('100%')
        .padding({ top: 12, bottom: 12 })
        .border({
          width: { bottom: 1 },
          color: ThemeColor.get(this.darkMode).border
        })
        .onClick(() => {
          this.selectCoefficient(value);
        })
      }, (value: number) => value.toString())
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 20, bottom: 10 })
    .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
    .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
    .borderRadius(20)
    .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
    .margin({ top: 16 })
  }

  build() {
    HdsNavDestination() {
      List({ scroller: this.pageScroller }) {
        ListItem() {
          this.buildEngineCard()
        }
        .width('100%')
        .reuseId('forgetting-engine')

        ListItem() {
          this.buildCurveCard()
        }
        .width('100%')
        .reuseId('forgetting-curve')

        ListItem() {
          this.buildOptionCard()
        }
        .width('100%')
        .reuseId('forgetting-options')

        ListItem() {
          Column().width('100%').height(32)
        }
        .width('100%')
        .reuseId('forgetting-bottom-spacer')
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
    .titleBar(createHdsSubPageTitleBarOptions('遗忘系数', this.darkMode, this.materialEffectMode))
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
