import { common } from '@kit.AbilityKit';
import { ComponentContent, SymbolGlyphModifier } from '@kit.ArkUI';
import {
  HdsNavigationMenuItemOptions,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  IconStyleMode
} from '@kit.UIDesignKit';
import router from '@ohos.router';
import { createHdsSubPageTitleBarOptions } from '../components/HdsSubPageTitleBarOptions';
import { ReviewSpellingTraining } from '../components/ReviewSpellingTraining';
import { WordCard } from '../components/WordCard';
import { Word } from '../model/Word';
import { DueReviewWord } from '../model/DueReviewWord';
import { DatabaseService } from '../services/DatabaseService';
import { AudioService } from '../services/AudioService';
import { PreferencesService } from '../services/PreferencesService';
import { StudyRecordService } from '../services/StudyRecordService';
import { StudySessionService } from '../services/StudySessionService';
import { StatisticsService } from '../services/StatisticsService';
import { ThemeService } from '../services/ThemeService';
import { WordService } from '../services/WordService';
import { Constants } from '../utils/Constants';
import { ThemeColor } from '../utils/ThemeColor';
import { DateUtil } from '../utils/DateUtil';
import { ArrayUtil } from '../utils/ArrayUtil';
import { SpacedRepetition } from '../algorithm/SpacedRepetition';
import { HomeModuleTransition, HomeModuleTransitionRoute } from '../utils/HomeModuleTransition';
import { SearchTransitionRect } from '../utils/HomeSearchTransition';

interface ReviewPageParams {
  bookId?: number;
  timeTab?: string;
  startReview?: boolean;
  homeModuleTransition?: HomeModuleTransitionRoute;
}

interface TranslationPart {
  part: string;
  meaning: string;
}

type PageMode = 'list' | 'review';
type ReviewPhase = 'review' | 'spell';

interface ReviewSettingsMenuParams {
  darkMode: boolean;
  autoPronounce: boolean;
  defaultShowDetail: boolean;
  pronounceOnReveal: boolean;
  reviewInListOrder: boolean;
  onAutoPronounceChange: (value: boolean) => void;
  onDefaultShowDetailChange: (value: boolean) => void;
  onPronounceOnRevealChange: (value: boolean) => void;
  onReviewInListOrderChange: (value: boolean) => void;
}

@Component
struct ReviewSettingsMenu {
  darkMode: boolean = false;
  @State autoPronounce: boolean = false;
  @State defaultShowDetail: boolean = Constants.DEFAULT_REVIEW_DETAIL_VISIBLE;
  @State pronounceOnReveal: boolean = false;
  @State reviewInListOrder: boolean = Constants.DEFAULT_REVIEW_IN_LIST_ORDER;
  onAutoPronounceChange: (value: boolean) => void = (_value: boolean): void => {};
  onDefaultShowDetailChange: (value: boolean) => void = (_value: boolean): void => {};
  onPronounceOnRevealChange: (value: boolean) => void = (_value: boolean): void => {};
  onReviewInListOrderChange: (value: boolean) => void = (_value: boolean): void => {};

  @Builder
  private buildAutoPronounceItem() {
    Row() {
      Text('自动发音')
        .fontSize(14)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: this.autoPronounce })
        .accessibilityText('自动发音')
        .enabled(!this.pronounceOnReveal)
        .onChange((isOn: boolean): void => {
          this.autoPronounce = isOn;
          if (isOn) {
            this.pronounceOnReveal = false;
            this.onPronounceOnRevealChange(false);
          }
          this.onAutoPronounceChange(isOn);
        })
    }
    .width(204)
    .height(48)
    .padding({ left: 14, right: 10 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildDefaultShowDetailItem() {
    Row() {
      Text('默认查看释义')
        .fontSize(14)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: this.defaultShowDetail })
        .accessibilityText('默认查看释义')
        .enabled(!this.pronounceOnReveal)
        .onChange((isOn: boolean): void => {
          this.defaultShowDetail = isOn;
          if (isOn) {
            this.pronounceOnReveal = false;
            this.onPronounceOnRevealChange(false);
          }
          this.onDefaultShowDetailChange(isOn);
        })
    }
    .width(204)
    .height(48)
    .padding({ left: 14, right: 10 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildPronounceOnRevealItem() {
    Row() {
      Text('点击释义时发音')
        .fontSize(14)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: this.pronounceOnReveal })
        .accessibilityText('点击释义时发音')
        .enabled(!this.defaultShowDetail && !this.autoPronounce)
        .onChange((isOn: boolean): void => {
          this.pronounceOnReveal = isOn;
          if (isOn) {
            this.defaultShowDetail = false;
            this.onDefaultShowDetailChange(false);
            this.autoPronounce = false;
            this.onAutoPronounceChange(false);
          }
          this.onPronounceOnRevealChange(isOn);
        })
    }
    .width(204)
    .height(48)
    .padding({ left: 14, right: 10 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildReviewInListOrderItem() {
    Row() {
      Text('复习正序')
        .fontSize(14)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: this.reviewInListOrder })
        .accessibilityText('复习正序')
        .onChange((isOn: boolean): void => {
          this.reviewInListOrder = isOn;
          this.onReviewInListOrderChange(isOn);
        })
    }
    .width(204)
    .height(48)
    .padding({ left: 14, right: 10 })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column() {
      this.buildAutoPronounceItem()
      this.buildDefaultShowDetailItem()
      this.buildPronounceOnRevealItem()
      this.buildReviewInListOrderItem()
    }
    .width(204)
  }
}

@Builder
function buildReviewSettingsMenu(params: ReviewSettingsMenuParams) {
  ReviewSettingsMenu({
    darkMode: params.darkMode,
    autoPronounce: params.autoPronounce,
    defaultShowDetail: params.defaultShowDetail,
    pronounceOnReveal: params.pronounceOnReveal,
    reviewInListOrder: params.reviewInListOrder,
    onAutoPronounceChange: params.onAutoPronounceChange,
    onDefaultShowDetailChange: params.onDefaultShowDetailChange,
    onPronounceOnRevealChange: params.onPronounceOnRevealChange,
    onReviewInListOrderChange: params.onReviewInListOrderChange
  })
}

@Entry
@Component
struct ReviewPage {
  @StorageLink('resolvedDarkMode') darkMode: boolean = false;
  @StorageLink('materialEffectMode') materialEffectMode: number = Constants.DEFAULT_MATERIAL_EFFECT_MODE;

  // ─── 模式控制 ───
  @State private mode: PageMode = 'list';
  @State private isLoading: boolean = true;
  @State private emptyMessage: string = '';
  @State private audioMessage: string = '';
  @State private bookId: number = 0;
  @State private autoPronounce: boolean = Constants.DEFAULT_REVIEW_AUTO_PRONOUNCE;
  @State private defaultShowDetail: boolean = Constants.DEFAULT_REVIEW_DETAIL_VISIBLE;
  @State private pronounceOnReveal: boolean = Constants.DEFAULT_REVIEW_PRONOUNCE_ON_REVEAL;
  @State private reviewInListOrder: boolean = Constants.DEFAULT_REVIEW_IN_LIST_ORDER;

  // ─── 看板列表数据 ───
  @State private dueWords: DueReviewWord[] = [];

  // ─── 时间筛选 ───
  private readonly timeFilterOptions: string[] = ['全部', '日', '周', '月', '年'];
  @State private selectedTimeFilter: string = '日';
  @State private filteredDueWords: DueReviewWord[] = [];
  /** 环形图总单词数（筛选前的总数，用于计算进度比例） */
  @State private ringTotalCount: number = 0;
  /** 本次会话中已复习的单词 ID，返回列表后排除 */
  private reviewedInSession: Set<number> = new Set();
  /** 今日已复习的单词 ID（持久化，跨页面保持） */
  private persistedReviewedIds: Set<number> = new Set();
  private listScroller: Scroller = new Scroller();
  private listScrollY: number = 0;
  @StorageLink('studyReviewGoal') @Watch('onReviewPlanChange') private reviewGoal: number =
    Constants.DEFAULT_REVIEW_GOAL;
  @StorageLink('studyReviewGroupSize') @Watch('onReviewPlanChange') private reviewGroupSize: number =
    Constants.DEFAULT_REVIEW_GROUP_SIZE;
  @State private forgettingCoefficient: number = 0.5;

  // ─── 逐卡复习数据 ───
  @State private reviewWords: Word[] = [];
  @State private currentIndex: number = 0;
  @State private showDetail: boolean = false;
  @State private isFinished: boolean = false;
  @State private isSubmitting: boolean = false;
  @State private knownCount: number = 0;
  @State private unknownCount: number = 0;
  @State private todayReviewCount: number = 0;
  @State private reviewPhase: ReviewPhase = 'review';
  @State private trainingCorrectCount: number = 0;
  @State private trainingWrongCount: number = 0;
  @State private reviewElapsedSeconds: number = 0;
  @State private spellingDistractorPool: Word[] = [];
  @State private pronounceRequestId: number = 0;
  @State private homeModuleContentStage: number = 7;
  private shouldAutoStartReview: boolean = false;
  private reviewSettingsMenuContent: ComponentContent<ReviewSettingsMenuParams> | null = null;
  private sessionId: number = 0;
  private sessionStart: number = 0;
  private originalSessionStart: number = 0;
  private durationTimer: number = -1;
  private readonly SESSION_FLUSH_INTERVAL_MS: number = 1000;
  private readonly REVIEW_SETTINGS_MENU_COMPONENT_ID: string = 'review-settings-menu-button';
  private readonly HOME_MODULE_SUMMARY_ID: string = 'review-page-summary-transition';
  private homeModuleTransition: HomeModuleTransitionRoute | undefined = undefined;
  private homeModuleTransitionPrepared: boolean = false;
  private homeModuleFallbackTimer: number = -1;
  private homeModuleContentTimers: number[] = [];
  private readonly HOME_MODULE_CONTENT_ENTRANCE_DELAY: number = 80;
  private readonly HOME_MODULE_CONTENT_ITEM_DELAY: number = 40;
  private readonly HOME_MODULE_MAX_ENTRY_ITEMS: number = 8;

  aboutToAppear(): void {
    this.readHomeModuleTransition();
    this.applyImmersiveBars();
    this.loadData();
  }

  onPageShow(): void {
    this.applyImmersiveBars();
  }

  private onReviewPlanChange(): void {
    if (!this.isLoading && this.mode === 'list') {
      this.applyTimeFilter();
    }
  }

  private async applyImmersiveBars(): Promise<void> {
    const context = getContext(this) as common.Context;
    await ThemeService.applySystemBars(context, this.darkMode);
  }

  async aboutToDisappear(): Promise<void> {
    this.clearHomeModuleContentTimers();
    if (this.homeModuleFallbackTimer >= 0) {
      clearTimeout(this.homeModuleFallbackTimer);
      this.homeModuleFallbackTimer = -1;
    }
    this.closeReviewSettingsMenu();
    this.stopDurationTimer();
    if (this.mode === 'review') {
      await this.endReviewSession();
    }
  }

  onPageHide(): void {
    if (this.mode !== 'review') {
      return;
    }
    this.flushSessionDuration().catch((error: Error) => {
      console.error('ReviewPage flushSessionDuration onPageHide failed: ' + JSON.stringify(error));
    });
  }

  onBackPress(): boolean {
    if (this.mode === 'review') {
      this.backToList();
      return true;
    }
    return false;
  }

  // ═══════════════════════════════════════════
  //  数据加载
  // ═══════════════════════════════════════════

  private async loadData(): Promise<void> {
    this.isLoading = true;
    try {
      const context = getContext(this) as common.Context;
      await DatabaseService.init(context);
      await PreferencesService.init(context);
      this.materialEffectMode = await PreferencesService.getMaterialEffectMode();
      AppStorage.setOrCreate('materialEffectMode', this.materialEffectMode);
      this.autoPronounce = await PreferencesService.getReviewAutoPronounce();
      this.defaultShowDetail = await PreferencesService.getReviewDetailVisible();
      this.pronounceOnReveal = await PreferencesService.getReviewPronounceOnReveal();
      if (this.defaultShowDetail && this.pronounceOnReveal) {
        this.pronounceOnReveal = false;
        await PreferencesService.setReviewPronounceOnReveal(false);
      }
      if (this.pronounceOnReveal && this.autoPronounce) {
        this.autoPronounce = false;
        await PreferencesService.setReviewAutoPronounce(false);
      }
      this.reviewInListOrder = await PreferencesService.getReviewInListOrder();
      const params: ReviewPageParams = router.getParams() as ReviewPageParams;
      this.bookId = params && params.bookId ? Number(params.bookId) : 0;
      if (params && params.timeTab && this.isValidTimeFilter(params.timeTab)) {
        this.selectedTimeFilter = params.timeTab;
      } else if (params && params.startReview) {
        this.selectedTimeFilter = '全部';
      }
      this.shouldAutoStartReview = !!(params && params.startReview);
      this.reviewGoal = await PreferencesService.getReviewGoal();
      const savedReviewGroupSize: number = await PreferencesService.getReviewGroupSize();
      this.reviewGroupSize = Math.max(1, savedReviewGroupSize);
      this.forgettingCoefficient = await PreferencesService.getForgettingCoefficient();
      this.spellingDistractorPool = await WordService.getAllWords(500, this.bookId);
      // 未选择词书时显示空状态
      if (this.bookId <= 0) {
        this.dueWords = [];
        this.filteredDueWords = [];
        this.isLoading = false;
        this.emptyMessage = '请先选择词书';
        return;
      }
      // 加载今日已复习的单词 ID（持久化）
      const todayKey: string = DateUtil.todayKey();
      const reviewedIds: number[] = await PreferencesService.getReviewedWordIds(todayKey);
      this.persistedReviewedIds = new Set(reviewedIds);
      this.todayReviewCount = (await StatisticsService.getOverviewStats(this.bookId)).todayReviewCount;
      // 仅展示学习过但未复习的单词
      try {
        const detailWords: DueReviewWord[] = this.bookId > 0
          ? await WordService.getDueReviewWordDetailsByBookId(this.bookId)
          : await WordService.getDueReviewWordDetails();
        this.dueWords = detailWords;
        this.applyTimeFilter();
        if (this.shouldAutoStartReview && this.reviewWords.length > 0) {
          this.shouldAutoStartReview = false;
          this.startReview();
        }
      } catch (e) {
        console.error('ReviewPage query failed: ' + JSON.stringify(e));
      }
    } catch (error) {
      console.error('ReviewPage loadData failed: ' + JSON.stringify(error));
      this.emptyMessage = '数据加载失败';
    } finally {
      this.isLoading = false;
    }
  }

  private readHomeModuleTransition(): void {
    const params: ReviewPageParams = router.getParams() as ReviewPageParams;
    this.homeModuleTransition = params ? params.homeModuleTransition : undefined;
    if (HomeModuleTransition.isValidRoute(this.homeModuleTransition)) {
      this.homeModuleContentStage = 0;
      this.homeModuleFallbackTimer = setTimeout((): void => {
        this.homeModuleFallbackTimer = -1;
        if (!this.homeModuleTransitionPrepared) {
          this.homeModuleTransitionPrepared = true;
          this.finishHomeModuleContentEntrance();
        }
      }, 360);
    }
  }

  private readHomeModuleTargetRect(): SearchTransitionRect | undefined {
    return this.readHomeModuleRect(this.HOME_MODULE_SUMMARY_ID);
  }

  private readHomeModuleRect(componentId: string): SearchTransitionRect | undefined {
    try {
      const componentInfo = this.getUIContext().getComponentUtils().getRectangleById(componentId);
      const rect: SearchTransitionRect = {
        x: componentInfo.windowOffset.x,
        y: componentInfo.windowOffset.y,
        width: componentInfo.size.width,
        height: componentInfo.size.height
      };
      return HomeModuleTransition.isValid(rect) ? rect : undefined;
    } catch (error) {
      console.warn('ReviewPage read home module transition rect failed: ' + JSON.stringify(error));
      return undefined;
    }
  }

  private beginHomeModuleEnterTransition(): void {
    if (!HomeModuleTransition.isValidRoute(this.homeModuleTransition) || this.homeModuleTransitionPrepared) {
      return;
    }
    this.homeModuleTransitionPrepared = true;
    if (this.homeModuleFallbackTimer >= 0) {
      clearTimeout(this.homeModuleFallbackTimer);
      this.homeModuleFallbackTimer = -1;
    }
    this.scheduleHomeModuleContentEntrance();
  }

  private clearHomeModuleContentTimers(): void {
    for (let index: number = 0; index < this.homeModuleContentTimers.length; index++) {
      clearTimeout(this.homeModuleContentTimers[index]);
    }
    this.homeModuleContentTimers = [];
  }

  private scheduleHomeModuleContentEntrance(): void {
    this.clearHomeModuleContentTimers();
    for (let stage: number = 1; stage <= this.HOME_MODULE_MAX_ENTRY_ITEMS + 2; stage++) {
      const delay: number = this.HOME_MODULE_CONTENT_ENTRANCE_DELAY +
        (stage - 1) * this.HOME_MODULE_CONTENT_ITEM_DELAY;
      const timer: number = setTimeout((): void => {
        animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
          this.homeModuleContentStage = stage;
        });
      }, delay);
      this.homeModuleContentTimers.push(timer);
    }
  }

  private finishHomeModuleContentEntrance(): void {
    this.clearHomeModuleContentTimers();
    this.homeModuleContentStage = this.HOME_MODULE_MAX_ENTRY_ITEMS + 2;
  }

  private getHomeModuleContentOpacity(stage: number): number {
    if (!HomeModuleTransition.isValidRoute(this.homeModuleTransition) || stage > this.HOME_MODULE_MAX_ENTRY_ITEMS + 2) {
      return 1;
    }
    return this.homeModuleContentStage >= stage ? 1 : 0;
  }

  private getHomeModuleContentOffset(stage: number): number {
    return this.getHomeModuleContentOpacity(stage) > 0 ? 0 : 16;
  }

  private returnToPreviousPage(): void {
    if (this.mode === 'list' && this.homeModuleTransition !== undefined) {
      const source: SearchTransitionRect | undefined = this.readHomeModuleTargetRect();
      if (source !== undefined) {
        HomeModuleTransition.setReturnSource(this.homeModuleTransition.id, source);
      }
    }
    router.back();
  }

  private goBack(): void {
    this.returnToPreviousPage();
  }

  private getTitleMenuItems(): Array<HdsNavigationMenuItemOptions> {
    if (this.mode !== 'review' || this.reviewPhase !== 'review' || this.isFinished) {
      return [];
    }
    return [
      {
        content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.dot_grid_2x2'))
            .fontSize(24)
            .fontColor([this.darkMode ? '#F8FAFC' : '#1A1A2E']),
          label: '复习设置',
          isEnabled: true,
          type: IconStyleMode.NORMAL,
          componentId: this.REVIEW_SETTINGS_MENU_COMPONENT_ID,
          action: (): void => {
            this.openReviewSettingsMenu();
          }
        }
      }
    ];
  }

  private openReviewSettingsMenu(): void {
    if (this.reviewSettingsMenuContent) {
      this.closeReviewSettingsMenu();
      return;
    }
    const params: ReviewSettingsMenuParams = {
      darkMode: this.darkMode,
      autoPronounce: this.autoPronounce,
      defaultShowDetail: this.defaultShowDetail,
      pronounceOnReveal: this.pronounceOnReveal,
      reviewInListOrder: this.reviewInListOrder,
      onAutoPronounceChange: (value: boolean): void => {
        this.autoPronounce = value;
        PreferencesService.setReviewAutoPronounce(value);
      },
      onDefaultShowDetailChange: (value: boolean): void => {
        this.defaultShowDetail = value;
        if (value) {
          this.showDetail = true;
        }
        PreferencesService.setReviewDetailVisible(value);
      },
      onPronounceOnRevealChange: (value: boolean): void => {
        this.pronounceOnReveal = value;
        PreferencesService.setReviewPronounceOnReveal(value);
      },
      onReviewInListOrderChange: (value: boolean): void => {
        this.reviewInListOrder = value;
        this.reorderPendingReviewWords();
        PreferencesService.setReviewInListOrder(value);
      }
    };
    const menuContent: ComponentContent<ReviewSettingsMenuParams> = new ComponentContent(
      this.getUIContext(), wrapBuilder(buildReviewSettingsMenu), params);
    this.reviewSettingsMenuContent = menuContent;
    this.getUIContext().getPromptAction().openMenu(menuContent, {
      id: this.REVIEW_SETTINGS_MENU_COMPONENT_ID
    }, {
      showInSubWindow: false,
      onDidDisappear: (): void => {
        if (this.reviewSettingsMenuContent === menuContent) {
          this.reviewSettingsMenuContent = null;
        }
        menuContent.dispose();
      }
    }).catch((error: Error): void => {
      if (this.reviewSettingsMenuContent === menuContent) {
        this.reviewSettingsMenuContent = null;
      }
      menuContent.dispose();
      console.error('ReviewPage open settings menu failed: ' + JSON.stringify(error));
    });
  }

  private closeReviewSettingsMenu(): void {
    const menuContent: ComponentContent<ReviewSettingsMenuParams> | null = this.reviewSettingsMenuContent;
    if (!menuContent) {
      return;
    }
    this.getUIContext().getPromptAction().closeMenu(menuContent).catch((error: Error): void => {
      if (this.reviewSettingsMenuContent === menuContent) {
        this.reviewSettingsMenuContent = null;
      }
      menuContent.dispose();
      console.error('ReviewPage close settings menu failed: ' + JSON.stringify(error));
    });
  }

  // ═══════════════════════════════════════════
  //  时间筛选
  // ═══════════════════════════════════════════

  /** 根据当前 selectedTimeFilter 过滤 dueWords，同步到 filteredDueWords 和 reviewWords */
  private applyTimeFilter(): void {
    const reviewPool: DueReviewWord[] = this.dueWords.filter((word: DueReviewWord) => {
      return word.mastered === 0 && word.nextReviewTime > 0;
    });
    // 按时间范围筛选（排除前）
    const timeFiltered: DueReviewWord[] = this.selectedTimeFilter === '日'
      ? reviewPool.filter(w => w.lastReviewTime >= DateUtil.todayStartTimestamp())
      : this.selectedTimeFilter === '全部'
        ? reviewPool
        : reviewPool.filter(w => w.lastReviewTime >= this.getPeriodStartMs());
    // 记录环形图总单词数（排除已复习前）
    this.ringTotalCount = timeFiltered.length;
    // 排除今日已复习的单词
    const allReviewed: Set<number> = new Set();
    this.persistedReviewedIds.forEach((id: number) => allReviewed.add(id));
    this.reviewedInSession.forEach((id: number) => allReviewed.add(id));
    const filtered: DueReviewWord[] = timeFiltered.filter(w => !allReviewed.has(w.id));
    filtered.sort((a: DueReviewWord, b: DueReviewWord) => {
      const urgencyDiff: number = this.getReviewUrgency(b) - this.getReviewUrgency(a);
      if (Math.abs(urgencyDiff) > 0.001) {
        return urgencyDiff > 0 ? 1 : -1;
      }
      return a.nextReviewTime - b.nextReviewTime;
    });
    const remainingGoal: number = this.reviewGoal > 0
      ? Math.max(0, this.reviewGoal - this.todayReviewCount)
      : filtered.length;
    const groupLimit: number = Math.min(remainingGoal, this.reviewGroupSize);
    const planned: DueReviewWord[] = filtered.slice(0, groupLimit);
    this.filteredDueWords = filtered;
    this.emptyMessage = filtered.length === 0
      ? (this.selectedTimeFilter === '全部' ? '暂无需要复习的单词' : '当前时间段暂无需要复习的单词')
      : '';
    this.reviewWords = planned.map((dw: DueReviewWord): Word => ({
      id: dw.id,
      word: dw.word,
      phonetic: dw.phonetic,
      partOfSpeech: dw.partOfSpeech ? dw.partOfSpeech : '',
      pronunciationUrl: dw.pronunciationUrl ? dw.pronunciationUrl : '',
      translation: dw.translation,
      example: dw.example,
      bookId: dw.bookId,
      difficulty: dw.difficulty,
      createdAt: dw.createdAt
    }));
  }

  /** 获取当前时间筛选的起始时间戳 */
  private getPeriodStartMs(): number {
    const now: Date = new Date();
    if (this.selectedTimeFilter === '周') {
      const day: number = now.getDay();
      const diff: number = day === 0 ? 6 : day - 1;
      const monday: Date = new Date(now.getTime() - diff * DateUtil.ONE_DAY_MILLISECONDS);
      monday.setHours(0, 0, 0, 0);
      return monday.getTime();
    }
    if (this.selectedTimeFilter === '月') {
      const monthStart: Date = new Date(now.getFullYear(), now.getMonth(), 1);
      return monthStart.getTime();
    }
    if (this.selectedTimeFilter === '年') {
      const yearStart: Date = new Date(now.getFullYear(), 0, 1);
      return yearStart.getTime();
    }
    return 0;
  }

  private isValidTimeFilter(filter: string): boolean {
    return filter === '全部' || filter === '日' || filter === '周' || filter === '月' || filter === '年';
  }

  private onFilterSelect(filter: string): void {
    this.selectedTimeFilter = filter;
    this.applyTimeFilter();
  }

  @Builder
  private buildTimeFilterMenu() {
    Menu() {
      ForEach(this.timeFilterOptions, (option: string) => {
        MenuItem({ content: option })
          .contentFont({ size: 16, weight: FontWeight.Normal })
          .onClick(() => {
            this.onFilterSelect(option);
          })
      }, (option: string) => option)
    }
  }

  // ═══════════════════════════════════════════
  //  看板列表工具方法
  // ═══════════════════════════════════════════

  /** 从翻译中提取词性缩写（如 "v." / "n." / "adj."） */
  private getPosTag(translation: string): string {
    const idx: number = translation.indexOf('.');
    if (idx > 0 && idx <= 5) {
      return translation.substring(0, idx + 1);
    }
    return '';
  }

  /** 从翻译中去除词性前缀得到纯中文释义 */
  private getChineseMeaning(translation: string): string {
    const idx: number = translation.indexOf('.');
    if (idx > 0 && idx <= 5) {
      return translation.substring(idx + 1).trim();
    }
    return translation;
  }

  private getTranslationParts(translation: string): TranslationPart[] {
    const result: TranslationPart[] = [];
    const rawItems: string[] = translation.replace(/\r/g, '\n').split(/;|\n/);
    for (let index: number = 0; index < rawItems.length; index++) {
      const item: string = rawItems[index].trim();
      if (item.length === 0) {
        continue;
      }
      const match = item.match(/^([a-zA-Z]+)\.\s*(.+)$/);
      if (match && match.length >= 3) {
        result.push({ part: match[1] + '.', meaning: match[2].trim() });
      }
    }
    return result;
  }

  /** 遗忘状态文字 */
  private getStatusLabel(word: DueReviewWord): string {
    const retention: number = this.getRetentionPercent(word);
    if (retention <= 35) return '高遗忘风险';
    if (retention <= 60) return '需要巩固';
    return '到期复习';
  }

  /** 遗忘状态文字颜色 */
  private getStatusColor(word: DueReviewWord): string {
    const retention: number = this.getRetentionPercent(word);
    if (retention <= 35) return this.darkMode ? '#F87171' : '#E53E3E';
    if (retention <= 60) return this.darkMode ? '#FB923C' : '#DD6B20';
    return this.darkMode ? '#FBBF24' : '#D69E2E';
  }

  /** 遗忘状态标签底色 */
  private getStatusBg(word: DueReviewWord): string {
    const retention: number = this.getRetentionPercent(word);
    if (retention <= 35) return this.darkMode ? '#3F1A1A' : '#FFF0F0';
    if (retention <= 60) return this.darkMode ? '#3F2618' : '#FFF5EB';
    return this.darkMode ? '#3F3518' : '#FFFFF0';
  }

  /** 复习按钮底色 */
  private getReviewBtnColor(word: DueReviewWord): string {
    const retention: number = this.getRetentionPercent(word);
    if (retention <= 35) return this.darkMode ? '#F87171' : '#E53E3E';
    if (retention <= 60) return this.darkMode ? '#FB923C' : '#DD6B20';
    return this.darkMode ? '#FBBF24' : '#D69E2E';
  }

  private getRetentionPercent(word: DueReviewWord): number {
    return Math.round(SpacedRepetition.estimateRetention(
      word.lastReviewTime,
      word.intervalDays,
      word.easeFactor,
      this.forgettingCoefficient
    ) * 100);
  }

  private getReviewUrgency(word: DueReviewWord): number {
    return SpacedRepetition.estimateUrgency(
      word.lastReviewTime,
      word.nextReviewTime,
      word.intervalDays,
      word.easeFactor,
      word.correctCount,
      word.wrongCount,
      this.forgettingCoefficient
    );
  }

  /** 上次学习文字 */
  private getLastReviewText(lastReviewTime: number): string {
    if (lastReviewTime <= 0) return '未学习';
    const daysAgo: number = Math.floor((Date.now() - lastReviewTime) / 86400000);
    if (daysAgo === 0) return '今天';
    if (daysAgo === 1) return '昨天';
    if (daysAgo <= 7) return daysAgo.toString() + '天前';
    return Math.floor(daysAgo / 7).toString() + '周前';
  }

  /** 预计分钟数（已学单词复习更快，约 20 秒/词） */
  private getEstimatedMinutes(): number {
    return Math.max(1, Math.ceil(this.reviewWords.length * 0.35));
  }

  /** 当前时间筛选下今日已复习的单词数（仅限当前词书） */
  private getReviewedCount(): number {
    const reviewedSet: Set<number> = new Set();
    this.persistedReviewedIds.forEach((id: number) => reviewedSet.add(id));
    this.reviewedInSession.forEach((id: number) => reviewedSet.add(id));
    // 只统计当前词书中实际存在的已复习单词
    let count: number = 0;
    for (let i: number = 0; i < this.dueWords.length; i++) {
      if (reviewedSet.has(this.dueWords[i].id)) {
        count++;
      }
    }
    return count;
  }

  // ═══════════════════════════════════════════
  //  模式切换
  // ═══════════════════════════════════════════

  private getReviewListIndex(wordId: number): number {
    for (let index: number = 0; index < this.filteredDueWords.length; index++) {
      if (this.filteredDueWords[index].id === wordId) {
        return index;
      }
    }
    return this.filteredDueWords.length;
  }

  private reorderReviewWordsFrom(startIndex: number): void {
    if (startIndex >= this.reviewWords.length) {
      return;
    }
    const preservedWords: Word[] = this.reviewWords.slice(0, startIndex);
    let remainingWords: Word[] = this.reviewWords.slice(startIndex);
    if (this.reviewInListOrder) {
      remainingWords.sort((a: Word, b: Word): number => {
        return this.getReviewListIndex(a.id) - this.getReviewListIndex(b.id);
      });
    } else {
      remainingWords = ArrayUtil.shuffle(remainingWords);
    }
    this.reviewWords = preservedWords.concat(remainingWords);
  }

  private reorderPendingReviewWords(): void {
    if (this.mode !== 'review' || this.reviewPhase !== 'review' || this.isFinished) {
      return;
    }
    this.reorderReviewWordsFrom(this.currentIndex + 1);
  }

  private startReview(preservedWordCount: number = 0): void {
    if (this.reviewWords.length === 0) return;
    this.reorderReviewWordsFrom(preservedWordCount);
    this.mode = 'review';
    this.reviewPhase = 'review';
    this.currentIndex = 0;
    this.showDetail = this.defaultShowDetail;
    this.isFinished = false;
    this.knownCount = 0;
    this.unknownCount = 0;
    this.trainingCorrectCount = 0;
    this.trainingWrongCount = 0;
    this.reviewElapsedSeconds = 0;
    this.pronounceRequestId = 0;
    this.isSubmitting = false;
    this.sessionStart = Date.now();
    this.originalSessionStart = this.sessionStart;
    StudySessionService.startSession('review').then((id: number) => {
      this.sessionId = id;
      this.startDurationTimer();
    });
    this.scheduleAutoPronounce();
  }

  private startReviewFromWord(word: DueReviewWord): void {
    this.saveListScrollOffset();
    let nextReviewWords: DueReviewWord[] = [];
    const remainingGoal: number = this.reviewGoal > 0
      ? Math.max(0, this.reviewGoal - this.todayReviewCount)
      : this.filteredDueWords.length;
    const groupLimit: number = Math.min(remainingGoal, this.reviewGroupSize);
    if (groupLimit <= 0) {
      return;
    }
    for (let index: number = 0; index < this.filteredDueWords.length; index++) {
      if (this.filteredDueWords[index].id === word.id) {
        nextReviewWords.push(this.filteredDueWords[index]);
        break;
      }
    }
    for (let index: number = 0; index < this.filteredDueWords.length && nextReviewWords.length < groupLimit; index++) {
      if (this.filteredDueWords[index].id !== word.id) {
        nextReviewWords.push(this.filteredDueWords[index]);
      }
    }
    this.reviewWords = nextReviewWords.map((dw: DueReviewWord): Word => ({
      id: dw.id,
      word: dw.word,
      phonetic: dw.phonetic,
      partOfSpeech: dw.partOfSpeech ? dw.partOfSpeech : '',
      pronunciationUrl: dw.pronunciationUrl ? dw.pronunciationUrl : '',
      translation: dw.translation,
      example: dw.example,
      bookId: dw.bookId,
      difficulty: dw.difficulty,
      createdAt: dw.createdAt
    }));
    this.startReview(1);
  }

  private openWordDetail(wordId: number): void {
    this.saveListScrollOffset();
    router.pushUrl({
      url: 'pages/WordDetailPage',
      params: {
        wordId: wordId
      }
    });
  }

  private backToList(): void {
    this.closeReviewSettingsMenu();
    this.stopDurationTimer();
    this.endReviewSession().catch((error: Error) => {
      console.error('ReviewPage endReviewSession backToList failed: ' + JSON.stringify(error));
    });
    this.mode = 'list';
    this.reviewPhase = 'review';
    this.applyTimeFilter();
    this.restoreListScrollOffset();
  }

  private saveListScrollOffset(): void {
    try {
      const offset = this.listScroller.currentOffset();
      this.listScrollY = Number(offset.yOffset);
    } catch (error) {
      console.error('ReviewPage saveListScrollOffset failed: ' + JSON.stringify(error));
    }
  }

  private restoreListScrollOffset(): void {
    const targetY: number = this.listScrollY;
    setTimeout(() => {
      this.listScroller.scrollTo({ xOffset: 0, yOffset: targetY, animation: false });
    }, 80);
  }

  // ═══════════════════════════════════════════
  //  逐卡复习
  // ═══════════════════════════════════════════

  private async endReviewSession(): Promise<void> {
    const total: number = this.knownCount + this.unknownCount;
    await StudySessionService.endSession(this.sessionId, total, this.originalSessionStart);
    this.sessionId = 0;
  }

  private revealDetail(): void {
    if (this.showDetail) {
      return;
    }
    this.showDetail = true;
    if (this.pronounceOnReveal) {
      this.requestWordCardPronunciation();
    }
  }

  private async playCurrentWord(): Promise<void> {
    await this.playWord(this.reviewWords[this.currentIndex]);
  }

  private async playWord(word: Word): Promise<void> {
    const context = getContext(this) as common.Context;
    this.audioMessage = await AudioService.playWord(word.word, word.pronunciationUrl ? word.pronunciationUrl : '', context);
  }

  private scheduleAutoPronounce(): void {
    if (!this.autoPronounce || this.reviewPhase !== 'review' || this.reviewWords.length === 0) {
      return;
    }
    setTimeout((): void => {
      if (this.mode === 'review' && this.reviewPhase === 'review' && this.autoPronounce && !this.isFinished) {
        this.requestWordCardPronunciation();
      }
    }, 120);
  }

  private requestWordCardPronunciation(): void {
    this.pronounceRequestId++;
  }

  /** 持久化已复习的单词 ID 到 Preferences */
  private async persistReviewedIds(): Promise<void> {
    const todayKey: string = DateUtil.todayKey();
    const merged: Set<number> = new Set();
    this.persistedReviewedIds.forEach((id: number) => merged.add(id));
    this.reviewedInSession.forEach((id: number) => merged.add(id));
    const allIds: number[] = [];
    merged.forEach((id: number) => allIds.push(id));
    await PreferencesService.saveReviewedWordIds(todayKey, allIds);
  }

  private async handleAnswer(isKnown: boolean): Promise<void> {
    if (this.isFinished || this.reviewWords.length === 0 || this.isSubmitting) return;
    this.isSubmitting = true;
    try {
      const now: number = Date.now();
      const elapsed: number = Math.max(0, Math.floor((now - this.sessionStart) / 1000));
      this.sessionStart = now;
      await StudyRecordService.recordAnswer(this.reviewWords[this.currentIndex], isKnown, 'review', elapsed);
      this.todayReviewCount++;
      if (isKnown) {
        this.knownCount++;
        // 记住才算复习完成，未记住继续待复习
        this.reviewedInSession.add(this.reviewWords[this.currentIndex].id);
        // 持久化保存
        this.persistReviewedIds();
      } else {
        this.unknownCount++;
      }
      await this.flushSessionDuration();
      this.nextReviewWord();
    } finally { this.isSubmitting = false; }
  }

  private nextReviewWord(): void {
    if (this.currentIndex >= this.reviewWords.length - 1) {
      this.startSpellingTraining();
      return;
    }
    this.currentIndex++;
    this.showDetail = this.defaultShowDetail;
    this.audioMessage = '';
    this.scheduleAutoPronounce();
  }

  private startSpellingTraining(): void {
    this.closeReviewSettingsMenu();
    this.reviewPhase = 'spell';
    this.currentIndex = 0;
    this.showDetail = false;
    this.audioMessage = '';
  }

  private async handleTrainingAnswer(word: Word, isCorrect: boolean, elapsedSeconds: number): Promise<void> {
    await StudyRecordService.recordSpellingAnswer(word, isCorrect, elapsedSeconds);
    await this.flushSessionDuration();
  }

  private finishReviewTraining(correctCount: number, wrongCount: number): void {
    this.trainingCorrectCount = correctCount;
    this.trainingWrongCount = wrongCount;
    this.updateReviewElapsedSeconds();
    this.isFinished = true;
    this.stopDurationTimer();
    this.endReviewSession().catch((error: Error) => {
      console.error('ReviewPage endReviewSession after training failed: ' + JSON.stringify(error));
    });
  }

  private startDurationTimer(): void {
    if (this.sessionId <= 0) {
      return;
    }
    this.stopDurationTimer();
    this.durationTimer = setInterval((): void => {
      this.updateReviewElapsedSeconds();
      this.flushSessionDuration().catch((error: Error) => {
        console.error('ReviewPage flushSessionDuration timer failed: ' + JSON.stringify(error));
      });
    }, this.SESSION_FLUSH_INTERVAL_MS);
  }

  private stopDurationTimer(): void {
    if (this.durationTimer < 0) {
      return;
    }
    clearInterval(this.durationTimer);
    this.durationTimer = -1;
  }

  private async flushSessionDuration(): Promise<void> {
    await StudySessionService.updateSessionProgress(
      this.sessionId,
      this.originalSessionStart,
      this.knownCount + this.unknownCount
    );
  }

  private updateReviewElapsedSeconds(): void {
    if (this.originalSessionStart <= 0) {
      this.reviewElapsedSeconds = 0;
      return;
    }
    this.reviewElapsedSeconds = Math.max(0, Math.floor((Date.now() - this.originalSessionStart) / 1000));
  }

  private formatReviewDuration(): string {
    const minutes: number = Math.floor(this.reviewElapsedSeconds / 60);
    const seconds: number = this.reviewElapsedSeconds % 60;
    return (minutes < 10 ? '0' : '') + minutes.toString() + ':' +
      (seconds < 10 ? '0' : '') + seconds.toString();
  }

  // ═══════════════════════════════════════════
  //  ? Builder — 页面导航标题区
  // ═══════════════════════════════════════════

  @Builder
  private buildNavTitle() {
    Row() {
      // 返回按钮（左侧，圆形底层 + PNG 图标）
      Row() {
        Image(this.darkMode ? $r('app.media.back_dark') : $r('app.media.back_light'))
          .width(19)
          .height(19)
          .objectFit(ImageFit.Contain)
          .offset({ x: -1 })
      }
      .height(32)
      .width(32)
      .backgroundColor(this.darkMode ? '#2D2015' : '#FFF5EB')
      .borderRadius(16)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .onClick(() => { this.goBack(); })

      // 页面标题「复习单词」（水平居中）
      Text('复习单词')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.darkMode ? '#F8FAFC' : '#1A1A2E')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Blank().width(32)
    }
    .width('100%')
    .height(40)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 20, right: 20 })
    .backgroundColor(ThemeColor.get(this.darkMode).background)
  }

  // ═══════════════════════════════════════════
  //  ? Builder — 顶部数据汇总卡片
  // ═══════════════════════════════════════════

  @Builder
  private buildSummaryCard() {
    Column() {
      // ── 3.1 卡片上层标题信息 ──
      Row() {
        Text('复习单词')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.darkMode ? '#F8FAFC' : '#1A1A2E')
          .margin({ left: 6 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)

      Text('按遗忘曲线优先复习最容易忘的词')
        .fontSize(12)
        .fontColor(this.darkMode ? '#CBD5E1' : '#8C8CA8')
        .margin({ top: 6, left: 6 })
        .width('100%')
        .textAlign(TextAlign.Start)

      // ── 3.2 卡片中层左右分栏 ──
      Row() {
        // 左侧文字数据区
        Column() {
          Row() {
            Text(this.reviewWords.length.toString())
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.darkMode ? '#FB923C' : '#DD6B20')
            Text(' 词')
              .fontSize(16)
              .fontColor(this.darkMode ? '#94A3B8' : '#A0A0B8')
              .margin({ top: 12 })
            Text('总 ' + this.filteredDueWords.length.toString() + ' 词')
              .fontSize(11)
              .fontColor(this.darkMode ? '#94A3B8' : '#A0A0B8')
              .margin({ left: 8, top: 13 })
          }
          .alignItems(VerticalAlign.Bottom)

          Row() {
            Image(this.darkMode ? $r('app.media.review_timer_dark') : $r('app.media.review_timer_light'))
              .width(15)
              .height(15)
              .objectFit(ImageFit.Contain)
            Text('今日计划 · 预计 ' + this.getEstimatedMinutes().toString() + ' 分钟')
              .fontSize(13)
              .fontColor(this.darkMode ? '#CBD5E1' : '#8C8CA8')
              .margin({ left: 4 })
          }
          .margin({ top: 8 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // 右侧图形数据区（环形进度）
        Column() {
          Stack() {
            Progress({ value: this.getReviewedCount(), total: this.ringTotalCount > 0 ? this.ringTotalCount : 1, type: ProgressType.Ring })
              .width(84)
              .height(84)
              .color(this.darkMode ? '#FB923C' : '#DD6B20')
              .backgroundColor(this.darkMode ? '#334155' : '#F0E5D8')
              .style({ strokeWidth: 7 })
            Column() {
              Text(this.getReviewedCount().toString())
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.darkMode ? '#FB923C' : '#DD6B20')
              Text('已复习')
                .fontSize(10)
                .fontColor(this.darkMode ? '#94A3B8' : '#A0A0B8')
                .margin({ top: 1 })
            }
            .alignItems(HorizontalAlign.Center)
          }
          .width(84).height(84)
        }
        .alignItems(HorizontalAlign.Center)
        .height(110)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .margin({ top: 0 })
      .offset({ y: -10 })

      // ── 3.3 卡片底层双功能入口 ──
      Divider()
        .color(this.darkMode ? '#3F2A1A' : '#F0E5D8')
        .margin({ top: 0, bottom: 1 })

      Row() {
        // 左侧 — 复习计划
        Row() {
          Column() {
            Text('复习计划')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
            Text('每日安排更高效')
              .fontSize(10)
              .fontColor(this.darkMode ? '#D4C5F0' : '#E8E0F8')
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Image($r('app.media.back_dark'))
            .width(11)
            .height(11)
            .objectFit(ImageFit.Contain)
            .scale({ x: -1, y: 1 })
            .margin({ left: 4 })
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Center)
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .backgroundColor('#8B7EC8')
        .borderRadius(16)
        .onClick(() => { router.pushUrl({ url: 'pages/StudyPlanPage' }); })
        .margin({ right: 8 })

        // 右侧 — 开始复习
        Row() {
          Column() {
            Text('开始复习')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
            Text('继续今日计划')
              .fontSize(10)
              .fontColor(this.darkMode ? '#D4C5F0' : '#E8E0F8')
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Image($r('app.media.back_dark'))
            .width(11)
            .height(11)
            .objectFit(ImageFit.Contain)
            .scale({ x: -1, y: 1 })
            .margin({ left: 4 })
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Center)
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .backgroundColor('#8B7EC8')
        .borderRadius(16)
        .opacity(this.reviewWords.length > 0 ? 1 : 0.45)
        .enabled(this.reviewWords.length > 0)
        .onClick(() => { this.startReview(); })
      }
      .width('100%')
      .offset({ y: -10 })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 20, bottom: 5 })
    .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
    .borderRadius(18)
    .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
    .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
    .margin({ top: 12 })
  }

  // ═══════════════════════════════════════════
  //  ? Builder — 列表筛选标题区
  // ═══════════════════════════════════════════

  @Builder
  private buildListFilter() {
    Row() {
      Row() {
        Text('待复习单词列表')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.darkMode ? '#F8FAFC' : '#1A1A2E')

        Blank()

        // 下拉筛选控件
        Row() {
          Text(this.selectedTimeFilter)
            .fontSize(12)
            .fontColor(this.darkMode ? '#94A3B8' : '#A0A0B8')
          Text('▼')
            .fontSize(8)
            .fontColor(this.darkMode ? '#94A3B8' : '#A0A0B8')
            .margin({ left: 3 })
        }
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .borderRadius(8)
        .backgroundColor(this.darkMode ? '#1E293B' : '#F1F5F9')
        .bindMenu(this.buildTimeFilterMenu())
      }
      .width('100%')
    }
    .width('100%')
    .margin({ top: 20, bottom: 8 })
  }

  // ═══════════════════════════════════════════
  //  ? Builder — 单条单词卡片
  // ═══════════════════════════════════════════

  @Builder
  private buildWordCard(word: DueReviewWord) {
    Row() {
      // ── 左侧：单词+词性（上）+ 中文释义（下） ──
      Column() {
        Row() {
          Text(word.word)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.darkMode ? '#F8FAFC' : '#1A1A2E')

          // 单词拼音
          if (word.phonetic.length > 0) {
            Text(word.phonetic)
              .fontSize(12)
              .fontColor(this.darkMode ? '#94A3B8' : '#A0A0B8')
              .margin({ left: 8 })
          }

        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        // 中文释义（按词性分组展示）
        if (this.getTranslationParts(word.translation).length > 0) {
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            ForEach(this.getTranslationParts(word.translation), (item: TranslationPart) => {
              Row() {
                Text(item.part)
                  .fontSize(12)
                  .fontColor(this.darkMode ? '#CBD5E1' : '#8C8CA8')
                Text(item.meaning)
                  .fontSize(13)
                  .fontColor(this.darkMode ? '#CBD5E1' : '#8C8CA8')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ left: 3 })
              }
              .margin({ right: 12, top: 6 })
            }, (item: TranslationPart) => item.part + item.meaning)
          }
          .width('100%')
        } else {
          Text(this.getChineseMeaning(word.translation).length > 0
            ? this.getChineseMeaning(word.translation)
            : word.translation)
            .fontSize(13)
            .fontColor(this.darkMode ? '#CBD5E1' : '#8C8CA8')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 6 })
        }

        // 历史记录
        Text('上次学习：' + this.getLastReviewText(word.lastReviewTime) + ' · 保留率 ' + this.getRetentionPercent(word).toString() + '%')
          .fontSize(11)
          .fontColor(this.darkMode ? '#64748B' : '#B0B0C8')
          .margin({ top: 6 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(2)
      .accessibilityText('查看 ' + word.word + ' 详情')
      .onClick(() => { this.openWordDetail(word.id); })

      // ── 右侧：遗忘状态标签 + 开始复习按钮 ──
      Column() {
        Text(this.getStatusLabel(word))
          .fontSize(11)
          .fontColor(this.getStatusColor(word))
          .backgroundColor(this.getStatusBg(word))
          .borderRadius(8)
          .padding({ left: 8, right: 8, top: 6, bottom: 6 })
          .maxLines(1)

        Text('开始复习')
          .fontSize(12)
          .fontColor(Color.White)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor(this.getReviewBtnColor(word))
          .borderRadius(14)
          .margin({ top: 8 })
          .onClick(() => { this.startReviewFromWord(word); })
      }
      .width(82)
      .alignItems(HorizontalAlign.Center)
      .margin({ left: 12 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.darkMode ? '#1B2638' : Color.White)
    .borderRadius(16)
    .border({ width: 1, color: this.darkMode ? '#334155' : '#E2E8F0' })
    .margin({ bottom: 12 })
    .shadow({ radius: 10, color: 'rgba(15, 23, 42, 0.05)', offsetY: 4 })
  }

  // ═══════════════════════════════════════════
  //  ? Builder — 空状态
  // ═══════════════════════════════════════════

  @Builder
  private buildEmptyState(message: string) {
    Column() {
      if (this.isLoading) {
        Text('正在加载...')
          .fontSize(16)
          .fontColor(this.darkMode ? '#94A3B8' : '#A0A0B8')
      } else {
        Image(this.darkMode ? $r('app.media.book_dark') : $r('app.media.book_light'))
          .width(48)
          .height(48)
          .objectFit(ImageFit.Contain)
          .opacity(this.darkMode ? 1 : 0.62)
        Text(message)
          .fontSize(16)
          .fontColor(this.darkMode ? '#94A3B8' : '#A0A0B8')
          .margin({ top: 12 })
      }
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildListEmptyState(message: string) {
    Column() {
      Image(this.darkMode ? $r('app.media.book_dark') : $r('app.media.book_light'))
        .width(42)
        .height(42)
        .objectFit(ImageFit.Contain)
        .opacity(this.darkMode ? 1 : 0.62)
      Text(message.length > 0 ? message : '暂无需要复习的单词')
        .fontSize(15)
        .fontColor(this.darkMode ? '#94A3B8' : '#A0A0B8')
        .margin({ top: 10 })
    }
    .width('100%')
    .height(180)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  // ═══════════════════════════════════════════
  //  ? Builder — 逐卡复习顶栏
  // ═══════════════════════════════════════════

  @Builder
  private buildReviewTopBar() {
    Row() {
      Row() {
        Image(this.darkMode ? $r('app.media.back_dark') : $r('app.media.back_light'))
          .width(19)
          .height(19)
          .objectFit(ImageFit.Contain)
          .offset({ x: -1 })
      }
      .width(32)
      .height(32)
      .backgroundColor(this.darkMode ? '#2D2015' : '#FFF5EB')
      .borderRadius(16)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .onClick(() => { this.backToList(); })

      Text('复习单词')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Blank().width(32)
    }
    .width('100%')
    .height(40)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 20, right: 20 })
    .backgroundColor(ThemeColor.get(this.darkMode).background)
  }

  // ═══════════════════════════════════════════
  //  ? Builder — 逐卡复习内容
  // ═══════════════════════════════════════════

  private reviewSessionProgressWidth(): string {
    if (this.reviewWords.length <= 0) {
      return '0%';
    }
    const progress: number = Math.round(((this.currentIndex + 1) / this.reviewWords.length) * 100);
    return Math.max(4, Math.min(100, progress)).toString() + '%';
  }

  @Builder
  private buildReviewProgressHeader() {
    Column() {
      Row() {
        Column() {
          Text('本次复习')
            .fontSize(11)
            .fontColor(ThemeColor.get(this.darkMode).textSecondary)

          Text('第 ' + (this.currentIndex + 1).toString() + ' 个单词')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeColor.get(this.darkMode).textPrimary)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text('今日 ' + this.todayReviewCount.toString() + ' / ' + this.reviewGoal.toString())
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeColor.get(this.darkMode).primary)
          .maxLines(1)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor(ThemeColor.get(this.darkMode).primaryLight)
          .borderRadius(12)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Column() {
        Row() {
          Text('本轮进度')
            .fontSize(12)
            .fontColor(ThemeColor.get(this.darkMode).textSecondary)

          Blank()

          Text(this.reviewSessionProgressWidth())
            .fontSize(12)
            .fontColor(ThemeColor.get(this.darkMode).textSecondary)
        }
        .width('100%')

        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width('100%')
            .height(7)
            .backgroundColor(this.darkMode ? '#233047' : '#E8EEF8')
            .borderRadius(4)

          Row()
            .width(this.reviewSessionProgressWidth())
            .height(7)
            .backgroundColor(ThemeColor.get(this.darkMode).primary)
            .borderRadius(4)
            .animation({ duration: 220, curve: Curve.EaseOut })
        }
        .width('100%')
        .height(7)
        .margin({ top: 8 })
      }
      .width('100%')
      .margin({ top: 10 })
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor(this.darkMode ? '#111827' : '#FFFFFF')
    .borderRadius(18)
    .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
    .shadow({ radius: 10, color: 'rgba(15, 23, 42, 0.05)', offsetY: 4 })
    .margin({ top: 12, bottom: 10 })
    .transition(TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ y: -6 }))
      .animation({ duration: 180, curve: Curve.EaseOut }))
  }

  @Builder
  private buildReviewContent() {
    Column() {
      this.buildReviewProgressHeader()

      WordCard({
        wordText: this.reviewWords[this.currentIndex].word,
        phonetic: this.reviewWords[this.currentIndex].phonetic,
        partOfSpeech: this.reviewWords[this.currentIndex].partOfSpeech ? this.reviewWords[this.currentIndex].partOfSpeech : '',
        translation: this.reviewWords[this.currentIndex].translation,
        example: this.reviewWords[this.currentIndex].example,
        showDetail: this.showDetail,
        cardBackground: ThemeColor.get(this.darkMode).cardBackground,
        textPrimary: ThemeColor.get(this.darkMode).textPrimary,
        textSecondary: ThemeColor.get(this.darkMode).textSecondary,
        primary: ThemeColor.get(this.darkMode).primary,
        dividerColor: ThemeColor.get(this.darkMode).border,
        darkMode: this.darkMode,
        pronounceRequestId: this.pronounceRequestId,
        onPronounce: async () => {
          await this.playCurrentWord();
        }
      })

      if (this.audioMessage.length > 0) {
        Text(this.audioMessage)
          .fontSize(13)
          .fontColor(ThemeColor.get(this.darkMode).textSecondary)
          .margin({ top: 10 })
      }

      Column() {
        Button('查看释义')
          .width('100%')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .role(ButtonRole.NORMAL)
          .enabled(!this.showDetail && !this.isSubmitting)
          .onClick(() => { this.revealDetail(); })

        Row() {
          Button('未记住')
            .width('31%')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .controlSize(ControlSize.NORMAL)
            .role(ButtonRole.ERROR)
            .enabled(!this.isSubmitting)
            .onClick(() => { this.handleAnswer(false); })

          Button('记住')
            .width('31%')
            .buttonStyle(ButtonStyleMode.EMPHASIZED)
            .controlSize(ControlSize.NORMAL)
            .role(ButtonRole.NORMAL)
            .enabled(!this.isSubmitting)
            .onClick(() => { this.handleAnswer(true); })

          Button('下一个')
            .width('31%')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .controlSize(ControlSize.NORMAL)
            .role(ButtonRole.NORMAL)
            .enabled(!this.isSubmitting)
            .onClick(() => { this.nextReviewWord(); })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ top: 14 })
      }
      .width('100%')
      .margin({ top: 20 })
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 20, right: 20 })
  }

  @Builder
  private buildReviewTrainingContent() {
    Column() {
      Row() {
        Column() {
          Text('复习训练')
            .fontSize(11)
            .fontColor(ThemeColor.get(this.darkMode).textSecondary)
          Text('拼写巩固')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeColor.get(this.darkMode).textPrimary)
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text('共 ' + this.reviewWords.length.toString() + ' 个')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeColor.get(this.darkMode).primary)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor(ThemeColor.get(this.darkMode).primaryLight)
          .borderRadius(12)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      ReviewSpellingTraining({
        words: this.reviewWords,
        distractorPool: this.spellingDistractorPool,
        darkMode: this.darkMode,
        autoPronounce: this.autoPronounce,
        audioMessage: $audioMessage,
        onPronounce: async (word: Word): Promise<void> => {
          await this.playWord(word);
        },
        onAnswer: async (word: Word, isCorrect: boolean, elapsedSeconds: number): Promise<void> => {
          await this.handleTrainingAnswer(word, isCorrect, elapsedSeconds);
        },
        onFinished: (correctCount: number, wrongCount: number): void => {
          this.finishReviewTraining(correctCount, wrongCount);
        }
      })

      if (this.audioMessage.length > 0) {
        Text(this.audioMessage)
          .fontSize(13)
          .fontColor(ThemeColor.get(this.darkMode).textSecondary)
          .margin({ top: 10 })
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 24 })
  }

  @Builder
  private buildFinishedMetric(value: string, label: string, color: string) {
    Column() {
      Text(value)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .maxLines(1)

      Text(label)
        .fontSize(12)
        .fontColor(ThemeColor.get(this.darkMode).textSecondary)
        .margin({ top: 5 })
        .maxLines(1)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildReviewFinished() {
    Column() {
      Image(this.darkMode ? $r('app.media.review_complete_dark') : $r('app.media.review_complete_light'))
        .width(64)
        .height(64)
        .objectFit(ImageFit.Contain)
        .accessibilityText('复习完成')

      Text('今日复习完成')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .margin({ top: 18 })

      Text('本轮完成 ' + (this.knownCount + this.unknownCount).toString() + ' 个单词')
        .fontSize(14)
        .fontColor(ThemeColor.get(this.darkMode).textSecondary)
        .margin({ top: 8 })

      Column() {
        Row() {
          this.buildFinishedMetric(this.knownCount.toString(), '记住', ThemeColor.get(this.darkMode).success)

          Row()
            .width(1)
            .height(42)
            .backgroundColor(ThemeColor.get(this.darkMode).border)

          this.buildFinishedMetric(this.unknownCount.toString(), '未记住', ThemeColor.get(this.darkMode).danger)

          Row()
            .width(1)
            .height(42)
            .backgroundColor(ThemeColor.get(this.darkMode).border)

          this.buildFinishedMetric(this.trainingCorrectCount.toString() + '/' +
            (this.trainingCorrectCount + this.trainingWrongCount).toString(), '训练正确',
            ThemeColor.get(this.darkMode).primary)
        }
        .width('100%')
        .height(72)
        .alignItems(VerticalAlign.Center)

        Divider()
          .color(ThemeColor.get(this.darkMode).border)

        Row() {
          Image(this.darkMode ? $r('app.media.review_timer_dark') : $r('app.media.review_timer_light'))
            .width(22)
            .height(22)
            .objectFit(ImageFit.Contain)

          Text('复习用时')
            .fontSize(14)
            .fontColor(ThemeColor.get(this.darkMode).textSecondary)
            .margin({ left: 8 })

          Blank()

          Text(this.formatReviewDuration())
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        }
        .width('100%')
        .height(58)
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .constraintSize({ maxWidth: 340 })
      .padding({ left: 18, right: 18, top: 10, bottom: 6 })
      .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
      .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
      .borderRadius(16)
      .shadow({ radius: 12, color: 'rgba(15, 23, 42, 0.06)', offsetY: 5 })
      .margin({ top: 26 })

      Button('返回列表')
        .width('100%')
        .constraintSize({ maxWidth: 340 })
        .buttonStyle(ButtonStyleMode.EMPHASIZED)
        .controlSize(ControlSize.NORMAL)
        .role(ButtonRole.NORMAL)
        .margin({ top: 22 })
        .onClick(() => { this.backToList(); })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 24, right: 24, bottom: 16 })
  }

  // ═══════════════════════════════════════════
  //  build 主入口
  // ═══════════════════════════════════════════

  pageTransition() {
    if (HomeModuleTransition.isValidRoute(this.homeModuleTransition)) {
      PageTransitionEnter({ duration: 0, type: RouteType.Push });
      PageTransitionExit({ duration: 240, curve: Curve.EaseIn, type: RouteType.Pop }).opacity(0);
    } else {
      PageTransitionEnter({ duration: 180, curve: Curve.EaseOut }).opacity(0)
      PageTransitionExit({ duration: 140, curve: Curve.EaseIn }).opacity(0)
    }
  }

  build() {
    HdsNavDestination() {
      List({ scroller: this.listScroller }) {
        if (this.mode === 'list') {
        // ── 看板列表模式 ──
        if (this.isLoading || this.bookId <= 0 || this.emptyMessage === '数据加载失败') {
          ListItem() {
            this.buildEmptyState(this.emptyMessage)
          }
          .height('100%')
        } else {
          ListItem() {
            this.buildSummaryCard()
          }
          .id(this.HOME_MODULE_SUMMARY_ID)
          .opacity(this.getHomeModuleContentOpacity(1))
          .translate({ y: this.getHomeModuleContentOffset(1) })
          .onAreaChange((): void => {
            this.beginHomeModuleEnterTransition();
          })
          .padding({ left: 20, right: 20, top: 0 })

          ListItem() {
            this.buildListFilter()
          }
          .opacity(this.getHomeModuleContentOpacity(2))
          .translate({ y: this.getHomeModuleContentOffset(2) })
          .padding({ left: 20, right: 20 })

          ForEach(this.filteredDueWords, (item: DueReviewWord, index?: number) => {
            ListItem() {
                this.buildWordCard(item)
            }
            .opacity(this.getHomeModuleContentOpacity((index ?? 0) + 3))
            .translate({ y: this.getHomeModuleContentOffset((index ?? 0) + 3) })
            .padding({ left: 20, right: 20 })
          }, (item: DueReviewWord, index?: number) => {
            return item.id.toString() + (index !== undefined ? '-' + index.toString() : '');
          })

          if (this.filteredDueWords.length === 0) {
            ListItem() {
                this.buildListEmptyState(this.emptyMessage)
            }
            .opacity(this.getHomeModuleContentOpacity(3))
            .translate({ y: this.getHomeModuleContentOffset(3) })
            .padding({ left: 20, right: 20 })
          }
        }
      } else {
        // ── 逐卡复习模式 ──
        if (this.isFinished) {
          ListItem() {
            this.buildReviewFinished()
          }
          .height('100%')
        } else {
          ListItem() {
            if (this.reviewPhase === 'spell') {
              this.buildReviewTrainingContent()
            } else {
              this.buildReviewContent()
            }
          }
        }
      }
      }
      .width('100%')
      .height('100%')
      .padding({ bottom: 12 })
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .enableScrollInteraction(true)
      .friction(0.75)
      .scrollBar(BarState.Auto)
      .onScroll((xOffset: number, yOffset: number) => {
        this.saveListScrollOffset();
      })
      .onAppear(() => {
        this.restoreListScrollOffset();
      })
      .backgroundColor(ThemeColor.get(this.darkMode).background)
    }
    .width('100%')
    .height('100%')
    .titleBar(createHdsSubPageTitleBarOptions('复习单词', this.darkMode, this.materialEffectMode, () => {
      if (this.mode === 'review') {
        this.backToList();
        return;
      }
      this.returnToPreviousPage();
    }, this.getTitleMenuItems()))
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .onBackPressed(() => {
      if (this.mode === 'review') {
        this.backToList();
        return true;
      }
      this.returnToPreviousPage();
      return true;
    })
    .bindToScrollable([this.listScroller])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    .backgroundColor(ThemeColor.get(this.darkMode).background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}


