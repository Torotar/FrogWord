import { common } from '@kit.AbilityKit';
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  HdsTabs,
  HdsTabsController,
  hdsMaterial
} from '@kit.UIDesignKit';
import router from '@ohos.router';
import { StudyStats } from '../model/StudyStats';
import { StudyPlanProgress } from '../model/StudyPlan';
import { WordBook } from '../model/WordBook';
import { DatabaseService } from '../services/DatabaseService';
import { DateUtil } from '../utils/DateUtil';
import { ThemeColor } from '../utils/ThemeColor';
import { PreferencesService } from '../services/PreferencesService';
import { StatisticsService } from '../services/StatisticsService';
import { StudyPlanService } from '../services/StudyPlanService';
import { ThemeService } from '../services/ThemeService';
import { WordBookService } from '../services/WordBookService';
import { WordService } from '../services/WordService';
import { createHdsTabTitleBarOptions } from '../components/HdsTabTitleBarOptions';
import { Constants } from '../utils/Constants';
import { HomeSearchTransition, SearchTransitionRect } from '../utils/HomeSearchTransition';
import { HomeModuleTransition, HomeModuleTransitionRoute } from '../utils/HomeModuleTransition';
import { StatisticsPage } from './StatisticsPage';
import { SettingsPage } from './SettingsPage';

interface MainTabsRouteParams {
  initialTab?: number;
}

interface HomeModuleCardParams {
  transitionId: string;
  title: string;
  count: number;
  unit: string;
  description: string;
  actionText: string;
  icon: Resource;
  lightBackground: string;
  darkBackground: string;
  lightIconBackground: string;
  darkIconBackground: string;
  onClick: () => void;
}

@Entry
@Component
struct Index {
  @StorageLink('resolvedDarkMode') darkMode: boolean = false;
  @StorageLink('materialEffectMode') materialEffectMode: number = Constants.DEFAULT_MATERIAL_EFFECT_MODE;
  @State private stats: StudyStats = {
    todayLearnCount: 0,
    todayReviewCount: 0,
    todayCorrectCount: 0,
    todayWrongCount: 0,
    pendingReviewCount: 0,
    unknownWordCount: 0,
    masteredCount: 0,
    totalWordCount: 0,
    unmasteredCount: 0,
    inLearningCount: 0,
    totalCorrectCount: 0,
    totalWrongCount: 0,
    accuracyRate: 0,
    studyDuration: 0
  };
  @State private progress: StudyPlanProgress = {
    learnProgress: 0,
    reviewProgress: 0,
    totalProgress: 0,
    suggestion: ''
  };
  @StorageLink('studyDailyGoal') @Watch('onStudyPlanGoalChange') private dailyGoal: number =
    Constants.DEFAULT_DAILY_GOAL;
  @StorageLink('studyReviewGoal') @Watch('onStudyPlanGoalChange') private reviewGoal: number =
    Constants.DEFAULT_REVIEW_GOAL;
  @State private bookCount: number = 0;
  @State private selectedBookId: number = 0;
  @State private todayStudiedWords: number = 0;
  @State private todayUnrecognizedWords: number = 0;
  @State private selectedBookWordCount: number = 0;
  @State private unstudiedCount: number = 0;
  @State private animatedAccuracy: number = 0;
  @State private reviewPendingCount: number = 0;
  @State private currentTab: number = 0;
  @State private statisticsRefreshToken: number = 0;
  @State private statisticsReselectToken: number = 0;
  @State private settingsReselectToken: number = 0;
  @State private homeSearchTranslateX: number = 0;
  @State private homeSearchTranslateY: number = 0;
  @State private homeSearchScaleX: number = 1;
  @State private homeSearchScaleY: number = 1;
  @State private homeModuleTranslateX: number = 0;
  @State private homeModuleTranslateY: number = 0;
  @State private homeModuleScaleX: number = 1;
  @State private homeModuleScaleY: number = 1;
  private dataLoading: boolean = false;
  private homeSearchNavigating: boolean = false;
  private homeSearchReturnPrepared: boolean = false;
  private homeSearchStartTranslateX: number = 0;
  private homeSearchStartTranslateY: number = 0;
  private homeSearchStartScaleX: number = 1;
  private homeSearchStartScaleY: number = 1;
  private homeModuleNavigating: boolean = false;
  private homeModuleTransitionId: string = '';
  private homeModuleReturnPrepared: boolean = false;
  private homeModuleStartTranslateX: number = 0;
  private homeModuleStartTranslateY: number = 0;
  private homeModuleStartScaleX: number = 1;
  private homeModuleStartScaleY: number = 1;
  private accuracyRollTimer: number = -1;
  private pageScroller: Scroller = new Scroller();
  private tabsController: HdsTabsController = new HdsTabsController();
  private readonly HOME_SEARCH_ID: string = 'home-search-field';
  private readonly HOME_MODULE_REVIEW_ID: string = 'home-module-review';
  private readonly HOME_MODULE_BOOKS_ID: string = 'home-module-books';
  private readonly HOME_MODULE_ALL_ID: string = 'home-module-all';
  private readonly HOME_MODULE_UNKNOWN_ID: string = 'home-module-unknown';
  private readonly HOME_MODULE_UNSTUDIED_ID: string = 'home-module-unstudied';
  private readonly HOME_MODULE_MASTERED_ID: string = 'home-module-mastered';

  aboutToAppear(): void {
    const params: MainTabsRouteParams | undefined = router.getParams() as MainTabsRouteParams | undefined;
    if (params !== undefined && params.initialTab !== undefined && params.initialTab >= 0 && params.initialTab <= 2) {
      this.currentTab = params.initialTab;
    }
  }

  aboutToDisappear(): void {
    this.stopAccuracyRoll();
  }

  onPageShow(): void {
    this.homeSearchNavigating = false;
    this.homeModuleNavigating = false;
    const context = getContext(this) as common.Context;
    ThemeService.applySystemBars(context, this.darkMode);
    this.loadData();
  }

  private onStudyPlanGoalChange(): void {
    this.refreshStudyPlanProgress();
  }

  private async refreshStudyPlanProgress(): Promise<void> {
    this.progress = await StudyPlanService.getProgress(this.selectedBookId);
  }

  private async loadData(): Promise<void> {
    if (this.dataLoading) {
      return;
    }
    this.dataLoading = true;
    try {
      const context = getContext(this) as common.Context;
      await DatabaseService.init(context);
      await PreferencesService.init(context);
      this.selectedBookId = await PreferencesService.getSelectedBookId();
      console.info('Index.loadData: selectedBookId=' + this.selectedBookId.toString());
      this.stats = await StatisticsService.getOverviewStats(this.selectedBookId);
      console.info('Index.loadData: totalWordCount=' + this.stats.totalWordCount.toString() + ', masteredCount=' + this.stats.masteredCount.toString());
      this.startAccuracyRoll(this.stats.accuracyRate);
      this.progress = await StudyPlanService.getProgress(this.selectedBookId);
      this.dailyGoal = await PreferencesService.getDailyGoal();
      this.reviewGoal = await PreferencesService.getReviewGoal();
      this.reviewPendingCount = 0;
      if (this.selectedBookId > 0) {
        const todayKey: string = DateUtil.todayKey();
        const todayReviewed: number[] = await PreferencesService.getReviewedWordIds(todayKey);
        const reviewPoolCount: number = await WordService.getAllStudiedCountByBookId(this.selectedBookId);
        const reviewedTodayCount: number = await WordService.getTodayReviewedCountByBookId(this.selectedBookId, todayReviewed);
        const visibleReviewPoolCount: number = Math.max(0, reviewPoolCount - reviewedTodayCount);
        this.reviewPendingCount = visibleReviewPoolCount;
        console.info('Index.loadData: reviewPendingCount from visible review pool=' + this.reviewPendingCount.toString());
      }
      console.info('Index.loadData: final reviewPendingCount=' + this.reviewPendingCount.toString());
      this.todayStudiedWords = await WordService.getTodayStudiedWords();
      this.todayUnrecognizedWords = await WordService.getTodayUnrecognizedWords();
      const books: WordBook[] = await WordBookService.getAllWordBooks();
      this.bookCount = books.length;
      if (this.selectedBookId > 0) {
        this.selectedBookWordCount = await WordBookService.getWordCount(this.selectedBookId);
        console.info('Index.loadData: selectedBookWordCount=' + this.selectedBookWordCount.toString());
        this.unstudiedCount = await WordService.getUnstudiedCountByBookId(this.selectedBookId);
      } else {
        this.selectedBookWordCount = this.stats.totalWordCount;
        this.unstudiedCount = 0;
      }
    } catch (error) {
      console.error('Index loadData failed: ' + JSON.stringify(error));
    } finally {
      this.dataLoading = false;
    }
  }

  private startAccuracyRoll(targetAccuracy: number): void {
    this.stopAccuracyRoll();
    const target: number = Math.max(0, Math.min(100, Math.round(targetAccuracy)));
    const start: number = 0;
    const steps: number = 24;
    let currentStep: number = 0;
    this.animatedAccuracy = start;

    if (target === start) {
      return;
    }

    this.accuracyRollTimer = setInterval((): void => {
      currentStep++;
      const progress: number = currentStep / steps;
      const easedProgress: number = 1 - Math.pow(1 - progress, 3);
      this.animatedAccuracy = Math.round(start + (target - start) * easedProgress);

      if (currentStep >= steps) {
        this.animatedAccuracy = target;
        this.stopAccuracyRoll();
      }
    }, 35);
  }

  private stopAccuracyRoll(): void {
    if (this.accuracyRollTimer < 0) {
      return;
    }
    clearInterval(this.accuracyRollTimer);
    this.accuracyRollTimer = -1;
  }

  private inactiveTabColor(): string {
    return this.darkMode ? '#CBD5E1' : '#111111';
  }

  private tabIcon(index: number): Resource {
    if (index === 1) {
      if (this.darkMode) {
        return this.currentTab === index ? $r('app.media.stats_active') : $r('app.media.stats_dark');
      }
      return this.currentTab === index ? $r('app.media.stats_active') : $r('app.media.stats_light');
    }
    if (index === 2) {
      if (this.darkMode) {
        return this.currentTab === index ? $r('app.media.settings_active') : $r('app.media.settings_dark');
      }
      return this.currentTab === index ? $r('app.media.settings_active') : $r('app.media.settings_light');
    }
    if (this.darkMode) {
      return this.currentTab === index ? $r('app.media.home_active') : $r('app.media.home_dark');
    }
    return this.currentTab === index ? $r('app.media.home_active') : $r('app.media.home_light');
  }

  private tabMaterialLevel(): hdsMaterial.MaterialLevel {
    if (this.materialEffectMode === 1) {
      return hdsMaterial.MaterialLevel.SMOOTH;
    }
    if (this.materialEffectMode === 2) {
      return hdsMaterial.MaterialLevel.GENTLE;
    }
    return hdsMaterial.MaterialLevel.EXQUISITE;
  }

  private updateCurrentTab(index: number): void {
    this.currentTab = index;
  }

  private handleTabBarClick(index: number): void {
    if (index !== this.currentTab) {
      this.updateCurrentTab(index);
      return;
    }
    if (index === 0) {
      this.pageScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: true });
    } else if (index === 1) {
      this.statisticsReselectToken++;
    } else {
      this.settingsReselectToken++;
    }
  }

  private readComponentRect(id: string): SearchTransitionRect | undefined {
    try {
      const componentInfo = this.getUIContext().getComponentUtils().getRectangleById(id);
      const rect: SearchTransitionRect = {
        x: componentInfo.windowOffset.x,
        y: componentInfo.windowOffset.y,
        width: componentInfo.size.width,
        height: componentInfo.size.height
      };
      return HomeSearchTransition.isValid(rect) ? rect : undefined;
    } catch (error) {
      console.warn('Index read search transition rect failed: ' + JSON.stringify(error));
      return undefined;
    }
  }

  private openHomeSearch(): void {
    if (this.homeSearchNavigating) {
      return;
    }
    this.homeSearchNavigating = true;
    const params: Record<string, Object> = {};
    params['bookId'] = this.selectedBookId;
    params['autoFocusSearch'] = true;
    const source: SearchTransitionRect | undefined = this.readComponentRect(this.HOME_SEARCH_ID);
    if (source !== undefined) {
      params['homeSearchTransitionSource'] = source;
    }
    router.pushUrl({ url: 'pages/SearchPage', params: params }).catch((error: Error): void => {
      this.homeSearchNavigating = false;
      console.error('Index open home search failed: ' + JSON.stringify(error));
    });
  }

  private openHomeModule(transitionId: string, url: string, params: Record<string, Object>): void {
    if (this.homeModuleNavigating || this.homeSearchNavigating) {
      return;
    }
    this.homeModuleNavigating = true;
    const source: SearchTransitionRect | undefined = this.readComponentRect(transitionId);
    if (source !== undefined) {
      const transition: HomeModuleTransitionRoute = { id: transitionId, source: source };
      params['homeModuleTransition'] = transition;
      this.homeModuleTransitionId = transitionId;
      this.homeModuleReturnPrepared = false;
    }
    router.pushUrl({ url: url, params: params }).catch((error: Error): void => {
      this.homeModuleNavigating = false;
      this.homeModuleTransitionId = '';
      console.error('Index open home module failed: ' + JSON.stringify(error));
    });
  }

  private updateHomeSearchReturnTransition(type: RouteType, progress: number): void {
    if (type !== RouteType.Pop) {
      return;
    }
    if (!this.homeSearchReturnPrepared) {
      const source: SearchTransitionRect | undefined = HomeSearchTransition.consumeReturnSource();
      const target: SearchTransitionRect | undefined = this.readComponentRect(this.HOME_SEARCH_ID);
      if (source === undefined || target === undefined) {
        return;
      }
      this.homeSearchStartTranslateX = px2vp(source.x + source.width / 2 - target.x - target.width / 2);
      this.homeSearchStartTranslateY = px2vp(source.y + source.height / 2 - target.y - target.height / 2);
      this.homeSearchStartScaleX = source.width / target.width;
      this.homeSearchStartScaleY = source.height / target.height;
      this.homeSearchReturnPrepared = true;
    }
    this.homeSearchTranslateX = this.homeSearchStartTranslateX * (1 - progress);
    this.homeSearchTranslateY = this.homeSearchStartTranslateY * (1 - progress);
    this.homeSearchScaleX = 1 + (this.homeSearchStartScaleX - 1) * (1 - progress);
    this.homeSearchScaleY = 1 + (this.homeSearchStartScaleY - 1) * (1 - progress);
    if (progress >= 1) {
      this.homeSearchTranslateX = 0;
      this.homeSearchTranslateY = 0;
      this.homeSearchScaleX = 1;
      this.homeSearchScaleY = 1;
      this.homeSearchReturnPrepared = false;
    }
  }

  private updateHomeModuleReturnTransition(type: RouteType, progress: number): void {
    if (type !== RouteType.Pop || this.homeModuleTransitionId.length === 0) {
      return;
    }
    if (!this.homeModuleReturnPrepared) {
      const source: SearchTransitionRect | undefined = HomeModuleTransition.consumeReturnSource(this.homeModuleTransitionId);
      const target: SearchTransitionRect | undefined = this.readComponentRect(this.homeModuleTransitionId);
      if (source === undefined || target === undefined) {
        this.homeModuleTransitionId = '';
        return;
      }
      this.homeModuleStartTranslateX = px2vp(source.x + source.width / 2 - target.x - target.width / 2);
      this.homeModuleStartTranslateY = px2vp(source.y + source.height / 2 - target.y - target.height / 2);
      this.homeModuleStartScaleX = source.width / target.width;
      this.homeModuleStartScaleY = source.height / target.height;
      this.homeModuleReturnPrepared = true;
    }
    this.homeModuleTranslateX = this.homeModuleStartTranslateX * (1 - progress);
    this.homeModuleTranslateY = this.homeModuleStartTranslateY * (1 - progress);
    this.homeModuleScaleX = 1 + (this.homeModuleStartScaleX - 1) * (1 - progress);
    this.homeModuleScaleY = 1 + (this.homeModuleStartScaleY - 1) * (1 - progress);
    if (progress >= 1) {
      this.homeModuleTranslateX = 0;
      this.homeModuleTranslateY = 0;
      this.homeModuleScaleX = 1;
      this.homeModuleScaleY = 1;
      this.homeModuleReturnPrepared = false;
      this.homeModuleTransitionId = '';
    }
  }

  @Builder
  private TabItem(label: string, index: number) {
    Column() {
      Image(this.tabIcon(index))
        .width(24)
        .height(24)
        .objectFit(ImageFit.Contain)
        .opacity(index === this.currentTab ? 1 : 0.76)

      Text(label)
        .fontSize(11)
        .lineHeight(14)
        .fontWeight(index === this.currentTab ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(index === this.currentTab ? '#4F5BFF' : this.inactiveTabColor())
        .margin({ top: 2 })
        .height(14)
        .maxLines(1)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height(56)
    .padding({ top: 4, bottom: 4 })
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  private homeModuleCard(params: HomeModuleCardParams) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Column() {
        Row() {
          Text(params.title)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeColor.get(this.darkMode).textPrimary)
            .maxLines(1)

          Blank()

          Row() {
            Image(params.icon)
              .width(19)
              .height(19)
              .objectFit(ImageFit.Contain)
          }
          .width(34)
          .height(34)
          .justifyContent(FlexAlign.Center)
          .borderRadius(17)
          .backgroundColor(this.darkMode ? params.darkIconBackground : params.lightIconBackground)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row() {
          Text(params.count.toString())
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeColor.get(this.darkMode).textPrimary)

          Text(' ' + params.unit)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeColor.get(this.darkMode).textSecondary)
            .baselineOffset(-4)
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)
        .margin({ top: 12 })

        Text(params.description)
          .fontSize(12)
          .lineHeight(18)
          .fontColor(ThemeColor.get(this.darkMode).textSecondary)
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 5 })

        Blank()

        Row() {
          Text(params.actionText)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeColor.get(this.darkMode).textPrimary)

          Blank()

          Image(this.darkMode ? $r('app.media.home_module_arrow_dark') :
            $r('app.media.home_module_arrow_light'))
            .width(17)
            .height(17)
            .objectFit(ImageFit.Contain)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .backgroundColor(this.darkMode ? params.darkBackground : params.lightBackground)
      .borderRadius(22)
      .border({
        width: 1,
        color: this.darkMode ? 'rgba(255, 255, 255, 0.08)' : 'rgba(15, 23, 42, 0.05)'
      })
      .shadow({
        radius: 10,
        color: this.darkMode ? 'rgba(0, 0, 0, 0.18)' : 'rgba(15, 23, 42, 0.05)',
        offsetY: 4
      })
    }
    .width('100%')
    .height(174)
    .padding(0)
    .backgroundColor(Color.Transparent)
    .borderRadius(22)
    .accessibilityText(params.title + '，' + params.count.toString() + params.unit + '，' + params.actionText)
    .id(params.transitionId)
    .translate({ x: this.homeModuleTransitionId === params.transitionId ? this.homeModuleTranslateX : 0,
      y: this.homeModuleTransitionId === params.transitionId ? this.homeModuleTranslateY : 0 })
    .scale({ x: this.homeModuleTransitionId === params.transitionId ? this.homeModuleScaleX : 1,
      y: this.homeModuleTransitionId === params.transitionId ? this.homeModuleScaleY : 1 })
    .onClick(() => {
      params.onClick();
    })
  }

  @Builder
  private HomePage() {
    Stack({ alignContent: Alignment.Bottom }) {
      HdsNavigation() {
        List({ scroller: this.pageScroller }) {
          ListItem() {
            Column() {
            Row() {
              Text('\u4eca\u65e5\u5b66\u4e60')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.darkMode ? '#F8FAFC' : '#1A1A2E')
            }
            .width('100%')

            Text('\u4fdd\u6301\u8282\u594f\uff0c\u6bcf\u5929\u8fdb\u6b65\u4e00\u70b9\u70b9')
              .fontSize(13)
              .fontColor(this.darkMode ? '#94A3B8' : '#8888A8')
              .margin({ top: 4 })
              .width('100%')

            Row() {
              Column() {
                Text('\u65b0\u5b66\u8fdb\u5ea6')
                  .fontSize(12)
                  .fontColor(this.darkMode ? '#94A3B8' : '#7C7C9A')
                Text(this.progress.learnProgress.toString() + '%')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.darkMode ? '#F8FAFC' : '#1A1A2E')
                  .margin({ top: 4 })
                Row() {
                  Row()
                    .width(this.progress.learnProgress.toString() + '%')
                    .height(5)
                    .backgroundColor('#8B7EC8')
                    .borderRadius(3)
                  Row()
                    .layoutWeight(1)
                    .height(5)
                    .backgroundColor(this.darkMode ? '#334155' : '#E8E3F0')
                    .borderRadius(3)
                }
                .width('76%')
                .margin({ top: 8 })
                Text('\u5df2\u5b66 ' + this.stats.todayLearnCount.toString() + ' / ' + this.dailyGoal.toString() + ' \u8bcd')
                  .fontSize(11)
                  .fontColor(this.darkMode ? '#64748B' : '#AAAAC4')
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              .onClick(() => {
                const searchParams: Record<string, Object> = {};
                searchParams['mode'] = 'recent';
                searchParams['title'] = '\u4eca\u65e5\u5b66\u4e60';
                searchParams['timeTab'] = '\u65e5';
                searchParams['bookId'] = this.selectedBookId;
                router.pushUrl({
                  url: 'pages/SearchPage',
                  params: searchParams
                });
              })

              Column() {
                Text('\u590d\u4e60\u8fdb\u5ea6')
                  .fontSize(12)
                  .fontColor(this.darkMode ? '#94A3B8' : '#7C7C9A')
                Text(this.progress.reviewProgress.toString() + '%')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.darkMode ? '#F8FAFC' : '#1A1A2E')
                  .margin({ top: 4 })
                Row() {
                  Row()
                    .width(this.progress.reviewProgress.toString() + '%')
                    .height(5)
                    .backgroundColor('#8B7EC8')
                    .borderRadius(3)
                  Row()
                    .layoutWeight(1)
                    .height(5)
                    .backgroundColor(this.darkMode ? '#334155' : '#E8E3F0')
                    .borderRadius(3)
                }
                .width('76%')
                .margin({ top: 8 })
                Text('\u590d\u4e60 ' + this.stats.todayReviewCount.toString() + ' / ' + this.reviewGoal.toString() + ' \u4e2a')
                  .fontSize(11)
                  .fontColor(this.darkMode ? '#64748B' : '#AAAAC4')
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Stack() {
                Progress({ value: this.animatedAccuracy, total: 100, type: ProgressType.Ring })
                  .width(68)
                  .height(68)
                  .color('#8B7EC8')
                  .backgroundColor(this.darkMode ? '#334155' : '#E8E3F0')
                  .style({ strokeWidth: 6 })
                Column() {
                  Text(this.animatedAccuracy.toString())
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#8B7EC8')
                  Text('\u6b63\u786e\u7387%')
                    .fontSize(9)
                    .fontColor(this.darkMode ? '#64748B' : '#AAAAC4')
                }
                .alignItems(HorizontalAlign.Center)
              }
              .width(68)
              .height(68)
            }
            .width('100%')
            .margin({ top: 12 })

            Row() {
              Row() {
                Text(this.selectedBookId > 0 ? '\u5f00\u59cb\u5b66\u4e60' : '\u8bf7\u5148\u9009\u62e9\u8bcd\u4e66')
                  .fontSize(13)
                  .fontColor(Color.White)
                Image($r('app.media.arrow_dark'))
                  .width(10)
                  .height(10)
                  .objectFit(ImageFit.Contain)
                  .margin({ left: 4 })
              }
              .alignItems(VerticalAlign.Center)
                .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                .backgroundColor(this.selectedBookId > 0 ? '#8B7EC8' : '#A0A0B8')
                .borderRadius(16)
                .onClick(() => {
                  if (this.selectedBookId > 0) {
                    const params: Record<string, Object> = {};
                    params['bookId'] = this.selectedBookId;
                    router.pushUrl({ url: 'pages/StudyPage', params: params });
                  } else {
                    router.pushUrl({ url: 'pages/WordBookManagePage' });
                  }
                })
              Blank()
              Row() {
                Text('\u5f00\u59cb\u590d\u4e60')
                  .fontSize(13)
                  .fontColor(Color.White)
                Image($r('app.media.arrow_dark'))
                  .width(10)
                  .height(10)
                  .objectFit(ImageFit.Contain)
                  .margin({ left: 4 })
              }
              .alignItems(VerticalAlign.Center)
                .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                .backgroundColor('#8B7EC8')
                .borderRadius(16)
                .onClick(() => {
                  const params: Record<string, Object> = {};
                  if (this.selectedBookId > 0) {
                    params['bookId'] = this.selectedBookId;
                  }
                  params['startReview'] = true;
                  router.pushUrl({ url: 'pages/ReviewPage', params: params });
                })
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 6, bottom: 2 })
            .margin({ top: 10 })
            .borderRadius(14)
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 18, bottom: 16 })
          .borderRadius(22)
          .linearGradient({
            angle: 135,
            colors: this.darkMode ?
              [['#1E1B2E', 0], ['#251E30', 0.5], ['#1F1A2E', 1]] :
              [['#FFF0F3', 0], ['#FFF5F0', 0.5], ['#FDF2FF', 1]]
          })
          .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
          .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
          .margin({ top: 136 })
          }
          .reuseId('home-study-overview')

          ListItem() {
            Row() {
            Text('\u641c\u7d22\u5355\u8bcd')
              .fontSize(15)
              .fontColor(this.darkMode ? '#94A3B8' : '#7C7C9A')
              .layoutWeight(1)
            Text('\u8f93\u5165\u4e2d\u6587\u6216\u82f1\u6587')
              .fontSize(12)
              .fontColor(this.darkMode ? '#64748B' : '#BBBBD4')
          }
          .width('100%')
          .height(48)
          .padding({ left: 16, right: 16 })
          .backgroundColor(this.darkMode ? '#1E293B' : '#F8FAFC')
          .borderRadius(22)
          .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
          .margin({ top: 12 })
          .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
          .onClick(() => {
            this.openHomeSearch();
          })
          .id(this.HOME_SEARCH_ID)
          .translate({ x: this.homeSearchTranslateX, y: this.homeSearchTranslateY })
          .scale({ x: this.homeSearchScaleX, y: this.homeSearchScaleY })
          }
          .reuseId('home-search')

          ListItem() {
            Grid() {
              GridItem() {
                this.homeModuleCard({
                  transitionId: this.HOME_MODULE_REVIEW_ID,
                  title: '\u5f85\u590d\u4e60',
                  count: this.reviewPendingCount,
                  unit: '\u8bcd',
                  description: '\u53ca\u65f6\u590d\u4e60\uff0c\u5de9\u56fa\u8bb0\u5fc6',
                  actionText: '\u53bb\u590d\u4e60',
                  icon: this.darkMode ? $r('app.media.home_review_dark') : $r('app.media.home_review_light'),
                  lightBackground: '#FDF2EA',
                  darkBackground: '#2D2015',
                  lightIconBackground: '#F6DCCB',
                  darkIconBackground: '#4A3022',
                  onClick: () => {
                    const reviewParams: Record<string, Object> = {};
                    if (this.selectedBookId > 0) {
                      reviewParams['bookId'] = this.selectedBookId;
                    }
                    this.openHomeModule(this.HOME_MODULE_REVIEW_ID, 'pages/ReviewPage', reviewParams);
                  }
                })
              }

              GridItem() {
                this.homeModuleCard({
                  transitionId: this.HOME_MODULE_BOOKS_ID,
                  title: '\u5355\u8bcd\u672c',
                  count: this.bookCount,
                  unit: '\u672c',
                  description: '\u7ba1\u7406\u4f60\u7684\u5b66\u4e60\u8bcd\u4e66',
                  actionText: '\u67e5\u770b\u5168\u90e8',
                  icon: this.darkMode ? $r('app.media.home_library_dark') : $r('app.media.home_library_light'),
                  lightBackground: '#F2EDFC',
                  darkBackground: '#1E1B2E',
                  lightIconBackground: '#DED6F4',
                  darkIconBackground: '#342C4B',
                  onClick: () => {
                    this.openHomeModule(this.HOME_MODULE_BOOKS_ID, 'pages/WordBookManagePage', {});
                  }
                })
              }

              GridItem() {
                this.homeModuleCard({
                  transitionId: this.HOME_MODULE_ALL_ID,
                  title: '\u603b\u8bcd\u6570',
                  count: this.selectedBookWordCount,
                  unit: '\u8bcd',
                  description: '\u6d4f\u89c8\u5f53\u524d\u8bcd\u4e66\u5168\u90e8\u5355\u8bcd',
                  actionText: '\u67e5\u770b\u5168\u90e8',
                  icon: this.darkMode ? $r('app.media.home_total_words_dark') :
                    $r('app.media.home_total_words_light'),
                  lightBackground: '#FDF8E8',
                  darkBackground: '#2D2A15',
                  lightIconBackground: '#F3E8B8',
                  darkIconBackground: '#49411F',
                  onClick: () => {
                    const allParams: Record<string, Object> = {};
                    allParams['mode'] = 'all';
                    allParams['title'] = '\u5168\u90e8\u5355\u8bcd';
                    allParams['bookId'] = this.selectedBookId;
                    this.openHomeModule(this.HOME_MODULE_ALL_ID, 'pages/SearchPage', allParams);
                  }
                })
              }

              GridItem() {
                this.homeModuleCard({
                  transitionId: this.HOME_MODULE_UNKNOWN_ID,
                  title: '\u4e0d\u8ba4\u8bc6',
                  count: this.stats.unknownWordCount,
                  unit: '\u8bcd',
                  description: '\u52a0\u5f3a\u8bb0\u5fc6\uff0c\u96c6\u4e2d\u653b\u514b\u96be\u70b9',
                  actionText: '\u53bb\u5b66\u4e60',
                  icon: this.darkMode ? $r('app.media.home_unknown_dark') : $r('app.media.home_unknown_light'),
                  lightBackground: '#F2F8F5',
                  darkBackground: '#152D22',
                  lightIconBackground: '#D8EBE0',
                  darkIconBackground: '#244532',
                  onClick: () => {
                    const unknownParams: Record<string, Object> = {};
                    unknownParams['mode'] = 'unknown';
                    unknownParams['title'] = '\u4e0d\u8ba4\u8bc6\u5355\u8bcd';
                    unknownParams['bookId'] = this.selectedBookId;
                    this.openHomeModule(this.HOME_MODULE_UNKNOWN_ID, 'pages/SearchPage', unknownParams);
                  }
                })
              }

              GridItem() {
                this.homeModuleCard({
                  transitionId: this.HOME_MODULE_UNSTUDIED_ID,
                  title: '\u5f85\u5b66\u4e60',
                  count: this.unstudiedCount,
                  unit: '\u8bcd',
                  description: '\u7ee7\u7eed\u5b66\u4e60\u5c1a\u672a\u5f00\u59cb\u7684\u5355\u8bcd',
                  actionText: '\u67e5\u770b\u8bb0\u5f55',
                  icon: this.darkMode ? $r('app.media.home_unstudied_dark') : $r('app.media.home_unstudied_light'),
                  lightBackground: '#F2F6FC',
                  darkBackground: '#15222D',
                  lightIconBackground: '#D9E7F5',
                  darkIconBackground: '#24394B',
                  onClick: () => {
                    const unstudiedParams: Record<string, Object> = {};
                    unstudiedParams['mode'] = 'unstudied';
                    unstudiedParams['title'] = '\u5f85\u5b66\u4e60\u5355\u8bcd';
                    unstudiedParams['bookId'] = this.selectedBookId;
                    this.openHomeModule(this.HOME_MODULE_UNSTUDIED_ID, 'pages/SearchPage', unstudiedParams);
                  }
                })
              }

              GridItem() {
                this.homeModuleCard({
                  transitionId: this.HOME_MODULE_MASTERED_ID,
                  title: '\u5df2\u638c\u63e1',
                  count: this.stats.masteredCount,
                  unit: '\u8bcd',
                  description: '\u67e5\u770b\u5df2\u7262\u56fa\u638c\u63e1\u7684\u5355\u8bcd',
                  actionText: '\u67e5\u770b\u8fdb\u5ea6',
                  icon: this.darkMode ? $r('app.media.home_mastered_dark') : $r('app.media.home_mastered_light'),
                  lightBackground: '#EAF0FC',
                  darkBackground: '#15202D',
                  lightIconBackground: '#CBD9EE',
                  darkIconBackground: '#24334A',
                  onClick: () => {
                    const masteredParams: Record<string, Object> = {};
                    masteredParams['mode'] = 'mastered';
                    masteredParams['title'] = '\u5df2\u638c\u63e1\u5355\u8bcd';
                    masteredParams['bookId'] = this.selectedBookId;
                    this.openHomeModule(this.HOME_MODULE_MASTERED_ID, 'pages/SearchPage', masteredParams);
                  }
                })
              }
            }
            .columnsTemplate('1fr 1fr')
            .columnsGap(12)
            .rowsGap(12)
            .width('100%')
            .margin({ top: 16 })
          }
          .width('100%')
          .reuseId('home-module-grid')

          ListItem() {
            Column() {
              Blank()
                .height(120)
            }
          }
          .reuseId('home-bottom-spacer')
        }
        .width('100%')
        .height('100%')
        .padding({ left: 24, right: 24, top: 0 })
        .cachedCount(2)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .enableScrollInteraction(true)
        .friction(0.75)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .titleBar(createHdsTabTitleBarOptions('\u4eca\u5929\u4e5f\u8981\u52a0\u6cb9\u5440',
        '\u575a\u6301\u5b66\u4e60\uff0c\u70b9\u4eae\u6bcf\u4e00\u5929', this.darkMode, this.materialEffectMode))
      .titleMode(HdsNavigationTitleMode.FULL)
      .hideBackButton(true)
      .bindToScrollable([this.pageScroller])
      .backgroundColor(ThemeColor.get(this.darkMode).background)

    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeColor.get(this.darkMode).background)
  }

  build() {
    HdsTabs({
      barPosition: BarPosition.End,
      controller: this.tabsController,
      index: this.currentTab
    }) {
      TabContent() {
        this.HomePage()
      }
      .tabBar(this.TabItem('首页', 0))

      TabContent() {
        StatisticsPage({
          refreshToken: this.statisticsRefreshToken,
          reselectToken: this.statisticsReselectToken
        })
      }
      .tabBar(this.TabItem('统计', 1))

      TabContent() {
        SettingsPage({ reselectToken: this.settingsReselectToken })
      }
      .tabBar(this.TabItem('设置', 2))
    }
    .width('100%')
    .height('100%')
    .vertical(false)
    .barPosition(BarPosition.End)
    .barOverlap(true)
    .barHeight(56)
    .barFloatingStyle(this.materialEffectMode === 0 ? {
      barBottomMargin: 28
    } : {
      barBottomMargin: 28,
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: this.tabMaterialLevel()
      }
    })
    .animationDuration(320)
    .onTabBarClick((index: number) => {
      this.handleTabBarClick(index);
    })
    .onChange((index: number) => {
      this.updateCurrentTab(index);
      if (index === 1) {
        this.statisticsRefreshToken++;
      }
    })
  }

  pageTransition() {
    // The home page instance is retained while SearchPage is on top, so this
    // transition must be registered before a return source is available.
    PageTransitionEnter({ duration: 240, curve: Curve.EaseOut, type: RouteType.Pop })
      .onEnter((type: RouteType, progress: number): void => {
        this.updateHomeSearchReturnTransition(type, progress);
        this.updateHomeModuleReturnTransition(type, progress);
      });
  }
}

