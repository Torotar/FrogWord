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
import { WordCard } from '../components/WordCard';
import { StudyStats } from '../model/StudyStats';
import { Word } from '../model/Word';
import { DatabaseService } from '../services/DatabaseService';
import { AudioService } from '../services/AudioService';
import { PreferencesService } from '../services/PreferencesService';
import { StudyRecordService } from '../services/StudyRecordService';
import { StudySessionService } from '../services/StudySessionService';
import { WordService } from '../services/WordService';
import { ArrayUtil } from '../utils/ArrayUtil';
import { Constants } from '../utils/Constants';
import { DateUtil } from '../utils/DateUtil';
import { ThemeColor } from '../utils/ThemeColor';

interface StudyPageParams {
  bookId?: number;
  mode?: string;
  timeTab?: string;
}

type StudyPhase = 'learn' | 'spell';
type SpellingQuestionMode = 'complete' | 'spell' | 'choice';
type ChoiceQuestionMode = 'translationToWord' | 'wordToTranslation';

interface StudySettingsMenuParams {
  darkMode: boolean;
  autoPronounce: boolean;
  defaultShowDetail: boolean;
  pronounceOnReveal: boolean;
  learnInOrder: boolean;
  onAutoPronounceChange: (value: boolean) => void;
  onDefaultShowDetailChange: (value: boolean) => void;
  onPronounceOnRevealChange: (value: boolean) => void;
  onLearnInOrderChange: (value: boolean) => void;
}

@Component
struct StudySettingsMenu {
  darkMode: boolean = false;
  @State autoPronounce: boolean = Constants.DEFAULT_REVIEW_AUTO_PRONOUNCE;
  @State defaultShowDetail: boolean = Constants.DEFAULT_STUDY_DETAIL_VISIBLE;
  @State pronounceOnReveal: boolean = Constants.DEFAULT_REVIEW_PRONOUNCE_ON_REVEAL;
  @State learnInOrder: boolean = true;
  onAutoPronounceChange: (value: boolean) => void = (_value: boolean): void => {};
  onDefaultShowDetailChange: (value: boolean) => void = (_value: boolean): void => {};
  onPronounceOnRevealChange: (value: boolean) => void = (_value: boolean): void => {};
  onLearnInOrderChange: (value: boolean) => void = (_value: boolean): void => {};

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
  private buildLearnInOrderItem() {
    Row() {
      Text('单词正序')
        .fontSize(14)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: this.learnInOrder })
        .accessibilityText('单词正序')
        .onChange((isOn: boolean): void => {
          this.learnInOrder = isOn;
          this.onLearnInOrderChange(isOn);
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
      this.buildLearnInOrderItem()
    }
    .width(204)
  }
}

@Builder
function buildStudySettingsMenu(params: StudySettingsMenuParams) {
  StudySettingsMenu({
    darkMode: params.darkMode,
    autoPronounce: params.autoPronounce,
    defaultShowDetail: params.defaultShowDetail,
    pronounceOnReveal: params.pronounceOnReveal,
    learnInOrder: params.learnInOrder,
    onAutoPronounceChange: params.onAutoPronounceChange,
    onDefaultShowDetailChange: params.onDefaultShowDetailChange,
    onPronounceOnRevealChange: params.onPronounceOnRevealChange,
    onLearnInOrderChange: params.onLearnInOrderChange
  })
}

@Entry
@Component
struct StudyPage {
  @State private words: Word[] = [];
  @State private currentIndex: number = 0;
  @State private studyPhase: StudyPhase = 'learn';
  @State private showDetail: boolean = false;
  @State private isFinished: boolean = false;
  @State private isLoading: boolean = true;
  @State private isSubmitting: boolean = false;
  @State private knownCount: number = 0;
  @State private unknownCount: number = 0;
  @State private dailyGoal: number = 20;
  @State private newWordGroupSize: number = 10;
  @State private relearnGoal: number = 30;
  @State private relearnGroupSize: number = 10;
  @State private todayLearnCount: number = 0;
  @State private emptyMessage: string = '';
  @State private showGoalBadge: boolean = false;
  @State private hasShownGoalBadge: boolean = false;
  @State private defaultShowDetail: boolean = Constants.DEFAULT_STUDY_DETAIL_VISIBLE;
  @State private audioMessage: string = '';
  @State private spellingPronounceFrame: number = 2;
  @State private spellingInput: string = '';
  @State private spellingFeedback: string = '';
  @State private spellingHintText: string = '';
  @State private spellingChecked: boolean = false;
  @State private spellingCorrect: boolean = false;
  @State private spellingQuestionMode: SpellingQuestionMode = 'spell';
  @State private choiceQuestionMode: ChoiceQuestionMode = 'translationToWord';
  @State private spellingLetters: string[] = [];
  @State private spellingEditableSlots: boolean[] = [];
  @State private spellingOptions: string[] = [];
  @State private selectedSpellingOption: string = '';
  @State private spellingHintLevel: number = 0;
  @State private spellingDistractorPool: Word[] = [];
  @State private activeSpellingSlot: number = -1;
  @State private studyElapsedSeconds: number = 0;
  @State private studyMode: string = '';
  @State private unknownStudyTotalCount: number = 0;
  @State private unknownStudyGroupStart: number = 0;
  @State private hasNextUnknownStudyGroup: boolean = false;
  @State private autoPronounce: boolean = Constants.DEFAULT_REVIEW_AUTO_PRONOUNCE;
  @State private pronounceOnReveal: boolean = Constants.DEFAULT_REVIEW_PRONOUNCE_ON_REVEAL;
  @State private studyOrderMode: number = 0;
  @State private pronounceRequestId: number = 0;
  @StorageLink('resolvedDarkMode') darkMode: boolean = false;
  @StorageLink('materialEffectMode') materialEffectMode: number = Constants.DEFAULT_MATERIAL_EFFECT_MODE;
  @State private bookId: number = 0;
  private sessionId: number = 0;
  private sessionStart: number = 0;
  /** 会话原始开始时间（记录到 study_session 的 start_time），整个会话中不变 */
  private originalSessionStart: number = 0;
  private durationTimer: number = -1;
  private spellingPronounceAnimationTimer: number = -1;
  private spellingPronounceAnimationId: number = 0;
  private pendingGoalBadge: boolean = false;
  private learnElapsedSeconds: number[] = [];
  private unknownStudyWords: Word[] = [];
  private pageScroller: Scroller = new Scroller();
  private studySettingsMenuContent: ComponentContent<StudySettingsMenuParams> | null = null;
  private readonly SESSION_FLUSH_INTERVAL_MS: number = 1000;
  private readonly UNKNOWN_STUDY_MIN_SPLIT_SIZE: number = 5;
  private readonly SPELLING_INPUT_ID: string = 'study-spelling-input';
  private readonly STUDY_SETTINGS_MENU_COMPONENT_ID: string = 'study-settings-menu-button';

  aboutToAppear(): void {
    this.sessionStart = Date.now();
    this.loadWords();
  }

  async aboutToDisappear(): Promise<void> {
    this.closeStudySettingsMenu();
    this.stopSpellingPronounceAnimation();
    this.stopDurationTimer();
    await this.endSession();
  }

  onPageHide(): void {
    this.flushSessionDuration().catch((error: Error) => {
      console.error('StudyPage flushSessionDuration onPageHide failed: ' + JSON.stringify(error));
    });
  }

  private async endSession(): Promise<void> {
    const sessionId: number = this.sessionId;
    if (sessionId <= 0) {
      return;
    }
    this.sessionId = 0;
    const totalAnswered: number = this.knownCount + this.unknownCount;
    await StudySessionService.endSession(sessionId, totalAnswered, this.originalSessionStart);
  }

  private async loadWords(): Promise<void> {
    this.isLoading = true;
    try {
      const context = getContext(this) as common.Context;
      await DatabaseService.init(context);
      await PreferencesService.init(context);
      this.autoPronounce = await PreferencesService.getReviewAutoPronounce();
      this.pronounceOnReveal = await PreferencesService.getReviewPronounceOnReveal();
      this.studyOrderMode = await PreferencesService.getStudyOrderMode();
      const params: StudyPageParams = router.getParams() as StudyPageParams;
      this.bookId = params && params.bookId ? Number(params.bookId) : 0;
      const mode: string = params && params.mode ? params.mode : '';
      this.studyMode = mode;
      const timeTab: string = params && params.timeTab ? params.timeTab : '全部';
      if (this.bookId <= 0) {
        this.words = [];
        this.emptyMessage = '请先选择词书';
        return;
      }
      this.dailyGoal = await PreferencesService.getDailyGoal();
      const savedNewWordGroupSize: number = await PreferencesService.getNewWordGroupSize();
      const savedRelearnGoal: number = await PreferencesService.getRelearnGoal();
      const savedRelearnGroupSize: number = await PreferencesService.getRelearnGroupSize();
      this.newWordGroupSize = Math.max(1, savedNewWordGroupSize);
      this.relearnGoal = Math.max(1, savedRelearnGoal);
      this.relearnGroupSize = Math.max(1, savedRelearnGroupSize);
      this.defaultShowDetail = await PreferencesService.getStudyDetailVisible();
      if (this.defaultShowDetail && this.pronounceOnReveal) {
        this.pronounceOnReveal = false;
        await PreferencesService.setReviewPronounceOnReveal(false);
      }
      if (this.pronounceOnReveal && this.autoPronounce) {
        this.autoPronounce = false;
        await PreferencesService.setReviewAutoPronounce(false);
      }
      const stats: StudyStats = await WordService.getStats(this.bookId);
      this.todayLearnCount = this.isUnknownStudy() ? 0 : stats.todayLearnCount;
      const remainingCount: number = Math.max(this.dailyGoal - this.todayLearnCount, 0);
      this.showGoalBadge = false;
      this.pendingGoalBadge = false;
      this.hasShownGoalBadge = this.isUnknownStudy() || remainingCount <= 0;
      const loadLimit: number = remainingCount > 0 ? Math.min(remainingCount, this.newWordGroupSize) : this.newWordGroupSize;
      // 应用学习顺序模式：0=字母排序，1=乱序
      const effectiveLimit: number = Math.max(loadLimit, 1);
      if (mode === 'unknown') {
        let unknownWords: Word[] = [];
        if (timeTab !== '全部') {
          const startDate: string = DateUtil.periodStartKey(timeTab);
          const endDate: string = DateUtil.periodEndKey(timeTab);
          unknownWords = await WordService.getWordsByPeriod('unknown', startDate, endDate, this.bookId);
        } else {
          unknownWords = await WordService.getUnknownWords(this.bookId);
        }
        this.prepareUnknownStudyGroups(unknownWords);
      } else if (this.studyOrderMode === 1) {
        this.words = (await WordService.getRandomUnmasteredWordsByBookId(this.bookId)).slice(0, effectiveLimit);
      } else {
        this.words = await WordService.getUnmasteredWordsByBookId(this.bookId, effectiveLimit);
      }
      this.spellingDistractorPool = await WordService.getAllWords(500, this.bookId);
      console.info('StudyPage loadWords: mode=' + mode + ', orderMode=' + this.studyOrderMode.toString() + ', wordCount=' + this.words.length.toString());
      if (!this.isUnknownStudy() && this.words.length > 1) {
        if (this.studyOrderMode === 1) {
          this.words = ArrayUtil.shuffle(this.words);
        } else {
          this.words = this.words.sort((a: Word, b: Word) => a.word.toLowerCase().localeCompare(b.word.toLowerCase()));
        }
      }
      this.currentIndex = 0;
      this.studyPhase = 'learn';
      this.knownCount = 0;
      this.unknownCount = 0;
      this.studyElapsedSeconds = 0;
      this.learnElapsedSeconds = [];
      this.resetSpellingState();
      // 开启学习时长会话（从进入页面时开始计时）
      this.sessionStart = Date.now();
      this.originalSessionStart = this.sessionStart;
      this.sessionId = await StudySessionService.startSession('learn');
      this.startDurationTimer();
      this.showDetail = this.defaultShowDetail;
      this.isFinished = false;
      this.pronounceRequestId = 0;
      this.emptyMessage = this.words.length === 0 ? (mode === 'unknown' ? '暂无不认识的单词' : '暂无可学习的单词') : '';
      this.scheduleAutoPronounce();
    } catch (error) {
      console.error('StudyPage loadWords failed: ' + JSON.stringify(error));
      this.emptyMessage = '学习数据加载失败';
    } finally {
      this.isLoading = false;
    }
  }

  private currentWord(): Word {
    return this.words[this.currentIndex];
  }

  private goBack(): void {
    router.back();
  }

  private getTitleMenuItems(): Array<HdsNavigationMenuItemOptions> {
    if (this.isLoading || this.emptyMessage.length > 0 || this.words.length === 0 ||
      this.studyPhase !== 'learn' || this.isFinished) {
      return [];
    }
    return [
      {
        content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.dot_grid_2x2'))
            .fontSize(24)
            .fontColor([this.darkMode ? '#F8FAFC' : '#1A1A2E']),
          label: '学习设置',
          isEnabled: true,
          type: IconStyleMode.NORMAL,
          componentId: this.STUDY_SETTINGS_MENU_COMPONENT_ID,
          action: (): void => {
            this.openStudySettingsMenu();
          }
        }
      }
    ];
  }

  private openStudySettingsMenu(): void {
    if (this.studySettingsMenuContent) {
      this.closeStudySettingsMenu();
      return;
    }
    const params: StudySettingsMenuParams = {
      darkMode: this.darkMode,
      autoPronounce: this.autoPronounce,
      defaultShowDetail: this.defaultShowDetail,
      pronounceOnReveal: this.pronounceOnReveal,
      learnInOrder: this.studyOrderMode === 0,
      onAutoPronounceChange: (value: boolean): void => {
        this.autoPronounce = value;
        PreferencesService.setReviewAutoPronounce(value);
      },
      onDefaultShowDetailChange: (value: boolean): void => {
        this.defaultShowDetail = value;
        if (value) {
          this.showDetail = true;
        }
        PreferencesService.setStudyDetailVisible(value);
      },
      onPronounceOnRevealChange: (value: boolean): void => {
        this.pronounceOnReveal = value;
        PreferencesService.setReviewPronounceOnReveal(value);
      },
      onLearnInOrderChange: (value: boolean): void => {
        this.studyOrderMode = value ? 0 : 1;
        this.reorderPendingStudyWords();
        PreferencesService.setStudyOrderMode(this.studyOrderMode);
      }
    };
    const menuContent: ComponentContent<StudySettingsMenuParams> = new ComponentContent(
      this.getUIContext(), wrapBuilder(buildStudySettingsMenu), params);
    this.studySettingsMenuContent = menuContent;
    this.getUIContext().getPromptAction().openMenu(menuContent, {
      id: this.STUDY_SETTINGS_MENU_COMPONENT_ID
    }, {
      showInSubWindow: false,
      onDidDisappear: (): void => {
        if (this.studySettingsMenuContent === menuContent) {
          this.studySettingsMenuContent = null;
        }
        menuContent.dispose();
      }
    }).catch((error: Error): void => {
      if (this.studySettingsMenuContent === menuContent) {
        this.studySettingsMenuContent = null;
      }
      menuContent.dispose();
      console.error('StudyPage open settings menu failed: ' + JSON.stringify(error));
    });
  }

  private closeStudySettingsMenu(): void {
    const menuContent: ComponentContent<StudySettingsMenuParams> | null = this.studySettingsMenuContent;
    if (!menuContent) {
      return;
    }
    this.getUIContext().getPromptAction().closeMenu(menuContent).catch((error: Error): void => {
      if (this.studySettingsMenuContent === menuContent) {
        this.studySettingsMenuContent = null;
      }
      menuContent.dispose();
      console.error('StudyPage close settings menu failed: ' + JSON.stringify(error));
    });
  }

  private orderWords(source: Word[]): Word[] {
    return this.studyOrderMode === 0 ? this.sortWordsByAlphabet(source) : ArrayUtil.shuffle(source);
  }

  private reorderPendingStudyWords(): void {
    if (this.studyPhase !== 'learn' || this.isFinished || this.words.length === 0) {
      return;
    }
    const pendingStart: number = this.currentIndex + 1;
    const preservedCurrentWords: Word[] = this.words.slice(0, pendingStart);
    if (!this.isUnknownStudy()) {
      this.words = preservedCurrentWords.concat(this.orderWords(this.words.slice(pendingStart)));
      return;
    }

    const futureGroupStart: number = this.unknownStudyGroupStart + this.words.length;
    const pendingWords: Word[] = this.words.slice(pendingStart)
      .concat(this.unknownStudyWords.slice(futureGroupStart));
    const reorderedPendingWords: Word[] = this.orderWords(pendingWords);
    const currentGroupPendingCount: number = this.words.length - pendingStart;
    this.words = preservedCurrentWords.concat(reorderedPendingWords.slice(0, currentGroupPendingCount));
    this.unknownStudyWords = this.unknownStudyWords.slice(0, this.unknownStudyGroupStart)
      .concat(preservedCurrentWords)
      .concat(reorderedPendingWords);
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

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({
      message: message,
      duration: 2000
    });
  }

  private async playCurrentWord(): Promise<void> {
    const word: Word = this.currentWord();
    const context = getContext(this) as common.Context;
    this.audioMessage = await AudioService.playWord(word.word, word.pronunciationUrl ? word.pronunciationUrl : '', context);
  }

  private scheduleAutoPronounce(): void {
    if (!this.autoPronounce || this.studyPhase !== 'learn' || this.words.length === 0) {
      return;
    }
    setTimeout((): void => {
      if (!this.isLoading && this.studyPhase === 'learn' && this.autoPronounce && !this.isFinished &&
        this.words.length > 0) {
        this.requestWordCardPronunciation();
      }
    }, 120);
  }

  private requestWordCardPronunciation(): void {
    this.pronounceRequestId++;
  }

  private spellingPronounceIcon(): Resource {
    if (this.spellingPronounceFrame === 0) {
      return this.darkMode ? $r('app.media.pronounce_dark_frame1') : $r('app.media.pronounce_light_frame1');
    }
    if (this.spellingPronounceFrame === 1) {
      return this.darkMode ? $r('app.media.pronounce_dark_frame2') : $r('app.media.pronounce_light_frame2');
    }
    return this.darkMode ? $r('app.media.pronounce_dark') : $r('app.media.pronounce_light');
  }

  private startSpellingPronounceAnimation(): number {
    this.stopSpellingPronounceAnimation(false);
    const animationId: number = this.spellingPronounceAnimationId + 1;
    this.spellingPronounceAnimationId = animationId;
    this.spellingPronounceFrame = 0;
    this.spellingPronounceAnimationTimer = setInterval(() => {
      this.spellingPronounceFrame = (this.spellingPronounceFrame + 1) % 3;
    }, Constants.PRONUNCIATION_ANIMATION_FRAME_INTERVAL_MS);
    return animationId;
  }

  private stopSpellingPronounceAnimation(resetFrame: boolean = true): void {
    if (this.spellingPronounceAnimationTimer >= 0) {
      clearInterval(this.spellingPronounceAnimationTimer);
      this.spellingPronounceAnimationTimer = -1;
    }
    if (resetFrame) {
      this.spellingPronounceFrame = 2;
    }
  }

  private async runSpellingPronounceAnimation(playTask: Promise<void>): Promise<void> {
    const animationId: number = this.startSpellingPronounceAnimation();
    try {
      await playTask;
    } finally {
      if (this.spellingPronounceAnimationId === animationId) {
        this.stopSpellingPronounceAnimation();
      }
    }
  }

  private async handleNext(): Promise<void> {
    if (this.isFinished || this.words.length === 0) {
      return;
    }
    if (this.isSubmitting) {
      return;
    }

    this.isSubmitting = true;
    try {
      const now: number = Date.now();
      const elapsedSeconds: number = Math.max(0, Math.floor((now - this.sessionStart) / 1000));
      this.sessionStart = now;
      this.learnElapsedSeconds[this.currentIndex] = elapsedSeconds;
      // 每次答题后增量更新会话时长（即使异常退出也有记录）
      await this.flushSessionDuration();
      this.nextLearnWord();
    } finally {
      this.isSubmitting = false;
    }
  }

  private nextLearnWord(): void {
    if (this.currentIndex >= this.words.length - 1) {
      this.startSpellingPhase();
      return;
    }

    this.currentIndex++;
    this.showDetail = this.defaultShowDetail;
    this.audioMessage = '';
    this.scheduleAutoPronounce();
  }

  private startSpellingPhase(): void {
    if (this.words.length === 0) {
      this.finishStudy();
      return;
    }

    this.closeStudySettingsMenu();
    this.studyPhase = 'spell';
    this.currentIndex = 0;
    this.showDetail = false;
    this.audioMessage = '';
    this.showGoalBadge = false;
    this.resetSpellingState();
  }

  private async handleSpellingSubmit(): Promise<void> {
    if (this.isFinished || this.words.length === 0 || this.isSubmitting || this.spellingChecked) {
      return;
    }

    if (!this.isSpellingAnswerReady()) {
      this.spellingFeedback = this.spellingQuestionMode === 'choice' ? '请选择一个拼写' : '请补完整所有字母';
      this.spellingCorrect = false;
      return;
    }

    this.isSubmitting = true;
    try {
      const now: number = Date.now();
      const elapsedSeconds: number = Math.max(0, Math.floor((now - this.sessionStart) / 1000));
      this.sessionStart = now;
      const word: Word = this.currentWord();
      const answer: string = this.currentSpellingAnswer();
      const isCorrect: boolean = this.normalizeSpelling(answer) === this.normalizeSpelling(word.word);
      const totalElapsedSeconds: number = (this.learnElapsedSeconds[this.currentIndex] ? this.learnElapsedSeconds[this.currentIndex] : 0) + elapsedSeconds;
      await StudyRecordService.recordLearned(word, totalElapsedSeconds, false);
      await StudyRecordService.recordSpellingAnswer(word, isCorrect, 0);
      this.todayLearnCount++;
      if (!this.isUnknownStudy() && !this.hasShownGoalBadge && this.todayLearnCount >= this.dailyGoal) {
        this.pendingGoalBadge = true;
        this.hasShownGoalBadge = true;
      }
      if (isCorrect) {
        this.knownCount++;
        this.spellingFeedback = '拼写正确';
      } else {
        this.unknownCount++;
        this.spellingFeedback = '拼写错误，正确拼写：' + word.word;
      }
      this.spellingCorrect = isCorrect;
      this.spellingChecked = true;
      await this.flushSessionDuration();
    } finally {
      this.isSubmitting = false;
    }
  }

  private handleSpellingNext(): void {
    if (!this.spellingChecked || this.isSubmitting) {
      return;
    }

    if (this.currentIndex >= this.words.length - 1) {
      this.finishStudy();
      return;
    }

    this.currentIndex++;
    this.audioMessage = '';
    this.resetSpellingState();
  }

  private finishStudy(): void {
    this.closeStudySettingsMenu();
    this.isFinished = true;
    this.studyPhase = 'learn';
    this.showDetail = false;
    this.audioMessage = '';
    this.showGoalBadge = this.pendingGoalBadge;
    this.pendingGoalBadge = false;
    if (this.showGoalBadge) {
      this.updateStudyElapsedSeconds();
      this.stopDurationTimer();
      this.endSession().catch((error: Error) => {
        console.error('StudyPage endSession after goal completion failed: ' + JSON.stringify(error));
      });
      this.showToast('今日学习目标已完成');
    }
  }

  private prepareUnknownStudyGroups(source: Word[]): void {
    const limitedWords: Word[] = source.slice(0, this.relearnGoal);
    this.unknownStudyWords = this.orderWords(limitedWords);
    this.unknownStudyTotalCount = this.unknownStudyWords.length;
    this.applyUnknownStudyGroup(0);
  }

  private sortWordsByAlphabet(source: Word[]): Word[] {
    const sorted: Word[] = source.slice();
    sorted.sort((left: Word, right: Word): number => {
      return left.word.toLowerCase().localeCompare(right.word.toLowerCase());
    });
    return sorted;
  }

  private applyUnknownStudyGroup(startIndex: number): void {
    const total: number = this.unknownStudyWords.length;
    const safeStart: number = Math.max(0, Math.min(startIndex, total));
    const endIndex: number = this.unknownStudyGroupEnd(safeStart, total);
    this.unknownStudyGroupStart = safeStart;
    this.words = this.unknownStudyWords.slice(safeStart, endIndex);
    this.hasNextUnknownStudyGroup = endIndex < total;
  }

  private unknownStudyGroupEnd(startIndex: number, total: number): number {
    const remaining: number = total - startIndex;
    if (remaining <= this.relearnGroupSize) {
      return total;
    }
    const afterCurrentGroup: number = remaining - this.relearnGroupSize;
    if (afterCurrentGroup <= this.UNKNOWN_STUDY_MIN_SPLIT_SIZE) {
      return total;
    }
    return startIndex + this.relearnGroupSize;
  }

  private async startNextUnknownStudyGroup(): Promise<void> {
    if (!this.isUnknownStudy() || !this.hasNextUnknownStudyGroup) {
      return;
    }
    const nextStart: number = this.unknownStudyGroupStart + this.words.length;
    this.stopDurationTimer();
    await this.endSession();
    this.applyUnknownStudyGroup(nextStart);
    this.currentIndex = 0;
    this.studyPhase = 'learn';
    this.knownCount = 0;
    this.unknownCount = 0;
    this.studyElapsedSeconds = 0;
    this.learnElapsedSeconds = [];
    this.resetSpellingState();
    this.sessionStart = Date.now();
    this.originalSessionStart = this.sessionStart;
    this.sessionId = await StudySessionService.startSession('learn');
    this.startDurationTimer();
    this.showDetail = this.defaultShowDetail;
    this.isFinished = false;
    this.audioMessage = '';
    this.pronounceRequestId = 0;
    this.pageScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: true });
    this.scheduleAutoPronounce();
  }

  private resetSpellingState(): void {
    this.spellingInput = '';
    this.spellingFeedback = '';
    this.spellingHintText = '';
    this.spellingChecked = false;
    this.spellingCorrect = false;
    this.selectedSpellingOption = '';
    this.spellingHintLevel = 0;
    this.activeSpellingSlot = -1;
    this.prepareSpellingQuestion();
  }

  private normalizeSpelling(value: string): string {
    return value.trim().toLowerCase().replace(/\s+/g, ' ');
  }

  private prepareSpellingQuestion(): void {
    if (this.words.length === 0) {
      this.spellingLetters = [];
      this.spellingEditableSlots = [];
      this.spellingOptions = [];
      return;
    }

    this.spellingQuestionMode = this.spellingQuestionModeForIndex();
    this.choiceQuestionMode = this.choiceQuestionModeForIndex();
    this.spellingEditableSlots = this.buildSpellingEditableSlots();
    this.spellingLetters = this.buildInitialSpellingLetters();
    this.spellingOptions = this.spellingQuestionMode === 'choice' ? this.buildSpellingOptions() : [];
    this.activeSpellingSlot = this.firstEditableSpellingSlot();
  }

  private spellingQuestionModeForIndex(): SpellingQuestionMode {
    const modeIndex: number = this.currentIndex % 3;
    if (modeIndex === 0) {
      return 'complete';
    }
    if (modeIndex === 1) {
      return 'spell';
    }
    return 'choice';
  }

  private choiceQuestionModeForIndex(): ChoiceQuestionMode {
    return Math.floor(this.currentIndex / 3) % 2 === 0 ? 'translationToWord' : 'wordToTranslation';
  }

  private currentWordCharacters(): string[] {
    return this.currentWord().word.split('');
  }

  private isEditableCharacter(character: string): boolean {
    if (character.length === 0) {
      return false;
    }
    const lower: string = character.toLowerCase();
    return lower >= 'a' && lower <= 'z';
  }

  private buildSpellingEditableSlots(): boolean[] {
    const characters: string[] = this.currentWordCharacters();
    const slots: boolean[] = [];
    if (this.spellingQuestionMode === 'choice') {
      for (let i: number = 0; i < characters.length; i++) {
        slots.push(false);
      }
      return slots;
    }

    let hasEditableSlot: boolean = false;
    for (let i: number = 0; i < characters.length; i++) {
      let editable: boolean = false;
      if (this.isEditableCharacter(characters[i])) {
        editable = this.spellingQuestionMode === 'spell' ||
          (i > 0 && i < characters.length - 1 && (i + this.currentIndex) % 2 === 0);
      }
      if (editable) {
        hasEditableSlot = true;
      }
      slots.push(editable);
    }

    if (!hasEditableSlot && this.spellingQuestionMode === 'complete') {
      for (let i: number = 0; i < characters.length; i++) {
        if (this.isEditableCharacter(characters[i])) {
          slots[i] = true;
          break;
        }
      }
    }
    return slots;
  }

  private buildInitialSpellingLetters(): string[] {
    const characters: string[] = this.currentWordCharacters();
    const letters: string[] = [];
    for (let i: number = 0; i < characters.length; i++) {
      letters.push(this.spellingEditableSlots[i] ? '' : this.formatLetterForSlot(characters[i], i));
    }
    return letters;
  }

  private updateSpellingInput(value: string): void {
    if (this.spellingChecked) {
      return;
    }
    const nextInput: string = this.lastSpellingInputCharacter(value);
    if (nextInput.length === 0) {
      this.clearSpellingInputText();
      return;
    }

    this.applySpellingCharacter(nextInput);
    this.clearSpellingInputText();
  }

  private applySpellingCharacter(character: string): void {
    const nextLetters: string[] = [...this.spellingLetters];
    let slotIndex: number = this.activeSpellingSlot >= 0 ? this.activeSpellingSlot : this.firstEmptySpellingSlot();
    if (slotIndex < 0) {
      return;
    }
    nextLetters[slotIndex] = this.formatLetterForSlot(character, slotIndex);
    slotIndex = this.nextEmptySpellingSlot(nextLetters, slotIndex);
    this.spellingLetters = nextLetters;
    this.activeSpellingSlot = slotIndex;
    this.spellingFeedback = '';
  }

  private handleSpellingDelete(): void {
    if (this.spellingChecked) {
      return;
    }
    const nextLetters: string[] = [...this.spellingLetters];
    let slotIndex: number = this.activeSpellingSlot >= 0 ? this.activeSpellingSlot : this.firstEmptySpellingSlot();
    if (slotIndex >= 0 && this.spellingEditableSlots[slotIndex] && nextLetters[slotIndex].length > 0) {
      nextLetters[slotIndex] = '';
    } else {
      slotIndex = this.previousFilledSpellingSlot(slotIndex);
      if (slotIndex < 0) {
        return;
      }
      nextLetters[slotIndex] = '';
    }
    this.spellingLetters = nextLetters;
    this.activeSpellingSlot = slotIndex;
    this.spellingFeedback = '';
    this.clearSpellingInputText();
  }

  private clearSpellingInputText(): void {
    this.spellingInput = '';
  }

  private lastSpellingInputCharacter(value: string): string {
    const nextInput: string = this.sanitizeSpellingInput(value);
    return nextInput.length > 0 ? nextInput.charAt(nextInput.length - 1) : '';
  }

  private sanitizeSpellingInput(value: string): string {
    const characters: string[] = value.split('');
    let result: string = '';
    for (let i: number = 0; i < characters.length; i++) {
      if (this.isEditableCharacter(characters[i])) {
        result += characters[i];
      }
    }
    return result;
  }

  private formatLetterForSlot(character: string, index: number): string {
    if (index > 0) {
      return character.toLowerCase();
    }
    return character;
  }

  private firstEditableSpellingSlot(): number {
    return this.nextEditableSpellingSlot(-1);
  }

  private firstEmptySpellingSlot(): number {
    return this.nextEmptySpellingSlot(this.spellingLetters, -1);
  }

  private nextEditableSpellingSlot(index: number): number {
    for (let i: number = index + 1; i < this.spellingEditableSlots.length; i++) {
      if (this.spellingEditableSlots[i]) {
        return i;
      }
    }
    return -1;
  }

  private nextEmptySpellingSlot(letters: string[], index: number): number {
    for (let i: number = index + 1; i < this.spellingEditableSlots.length; i++) {
      if (this.spellingEditableSlots[i] && letters[i].length === 0) {
        return i;
      }
    }
    return -1;
  }

  private previousFilledSpellingSlot(index: number): number {
    const start: number = index >= 0 ? index - 1 : this.spellingEditableSlots.length - 1;
    for (let i: number = start; i >= 0; i--) {
      if (this.spellingEditableSlots[i] && this.spellingLetters[i].length > 0) {
        return i;
      }
    }
    return -1;
  }

  private activateSpellingSlot(index: number): void {
    if (!this.spellingChecked && this.spellingEditableSlots[index]) {
      this.activeSpellingSlot = index;
      this.focusSpellingInput();
    }
  }

  private focusSpellingInput(): void {
    if (this.studyPhase !== 'spell' || this.spellingQuestionMode === 'choice' || this.spellingChecked || this.isSubmitting) {
      return;
    }
    focusControl.requestFocus(this.SPELLING_INPUT_ID);
  }

  private isSpellingAnswerReady(): boolean {
    if (this.spellingQuestionMode === 'choice') {
      return this.selectedSpellingOption.length > 0;
    }
    for (let i: number = 0; i < this.spellingEditableSlots.length; i++) {
      if (this.spellingEditableSlots[i] && this.spellingLetters[i].length === 0) {
        return false;
      }
    }
    return true;
  }

  private currentSpellingAnswer(): string {
    if (this.spellingQuestionMode === 'choice') {
      return this.selectedSpellingOption;
    }
    return this.spellingLetters.join('');
  }

  private selectSpellingOption(option: string): void {
    if (this.spellingChecked || this.isSubmitting) {
      return;
    }
    this.selectedSpellingOption = option;
    this.spellingInput = option;
    this.spellingFeedback = '';
  }

  private buildSpellingOptions(): string[] {
    const options: string[] = [this.currentWord().word];
    const candidates: Word[] = this.sortedDistractorWords();
    for (let i: number = 0; i < candidates.length && options.length < 4; i++) {
      if (this.hasSimilarMeaning(candidates[i].translation, this.currentWord().translation) &&
        !this.containsSpellingOption(options, candidates[i].word)) {
        options.push(candidates[i].word);
      }
    }

    const variants: string[] = this.buildSpellingVariants(this.currentWord().word);
    for (let i: number = 0; i < variants.length && options.length < 4; i++) {
      if (!this.containsSpellingOption(options, variants[i])) {
        options.push(variants[i]);
      }
    }

    for (let i: number = 0; i < candidates.length && options.length < 4; i++) {
      if (!this.containsSpellingOption(options, candidates[i].word)) {
        options.push(candidates[i].word);
      }
    }

    let variantIndex: number = variants.length + 1;
    while (options.length < 4 && variantIndex < variants.length + 20) {
      const variant: string = this.buildFallbackSpellingVariant(this.currentWord().word, variantIndex);
      if (!this.containsSpellingOption(options, variant)) {
        options.push(variant);
      }
      variantIndex++;
    }
    return ArrayUtil.shuffle(options);
  }

  private sortedDistractorWords(): Word[] {
    const current: Word = this.currentWord();
    const candidates: Word[] = [];
    const pool: Word[] = this.spellingDistractorPool.length > 0 ? this.spellingDistractorPool : this.words;
    for (let i: number = 0; i < pool.length; i++) {
      if (this.normalizeSpelling(pool[i].word) !== this.normalizeSpelling(current.word)) {
        candidates.push(pool[i]);
      }
    }
    return candidates.sort((a: Word, b: Word): number => {
      return this.distractorScore(b) - this.distractorScore(a);
    });
  }

  private distractorScore(candidate: Word): number {
    let score: number = this.spellingSimilarityScore(candidate.word, this.currentWord().word);
    if (this.hasSimilarMeaning(candidate.translation, this.currentWord().translation)) {
      score += 1000;
    }
    return score;
  }

  private spellingSimilarityScore(candidate: string, target: string): number {
    const a: string = candidate.toLowerCase();
    const b: string = target.toLowerCase();
    const minLength: number = Math.min(a.length, b.length);
    let samePosition: number = 0;
    let commonPrefix: number = 0;
    for (let i: number = 0; i < minLength; i++) {
      if (a.charAt(i) === b.charAt(i)) {
        samePosition++;
        if (commonPrefix === i) {
          commonPrefix++;
        }
      }
    }
    return samePosition * 4 + commonPrefix * 3 - Math.abs(a.length - b.length) * 2;
  }

  private hasSimilarMeaning(a: string, b: string): boolean {
    const aParts: string[] = this.translationPartsForMatch(a);
    const bParts: string[] = this.translationPartsForMatch(b);
    for (let i: number = 0; i < aParts.length; i++) {
      for (let j: number = 0; j < bParts.length; j++) {
        if (aParts[i].length > 0 && bParts[j].length > 0 &&
          (aParts[i] === bParts[j] || aParts[i].indexOf(bParts[j]) >= 0 || bParts[j].indexOf(aParts[i]) >= 0)) {
          return true;
        }
      }
    }
    return false;
  }

  private translationPartsForMatch(value: string): string[] {
    return value
      .replace(/[；;，,、。.!！?？]/g, '|')
      .split('|')
      .map((item: string): string => item.trim().toLowerCase())
      .filter((item: string): boolean => item.length > 0);
  }

  private containsSpellingOption(options: string[], value: string): boolean {
    const normalizedValue: string = this.normalizeSpelling(value);
    for (let i: number = 0; i < options.length; i++) {
      if (this.normalizeSpelling(options[i]) === normalizedValue) {
        return true;
      }
    }
    return false;
  }

  private buildSpellingVariants(word: string): string[] {
    const variants: string[] = [];
    const characters: string[] = word.split('');
    if (characters.length <= 0) {
      return variants;
    }

    for (let i: number = 0; i < characters.length - 1; i++) {
      if (this.isEditableCharacter(characters[i]) && this.isEditableCharacter(characters[i + 1])) {
        const swapped: string[] = [...characters];
        const temp: string = swapped[i];
        swapped[i] = swapped[i + 1];
        swapped[i + 1] = temp;
        this.pushUniqueSpellingVariant(variants, swapped.join(''));
      }
    }

    for (let i: number = 0; i < characters.length; i++) {
      if (this.isEditableCharacter(characters[i])) {
        const replaced: string[] = [...characters];
        replaced[i] = this.nextSimilarLetter(characters[i], i + 1);
        this.pushUniqueSpellingVariant(variants, replaced.join(''));
      }
    }

    if (characters.length > 3) {
      for (let i: number = 1; i < characters.length - 1; i++) {
        if (this.isEditableCharacter(characters[i])) {
          const removed: string[] = [...characters];
          removed.splice(i, 1);
          this.pushUniqueSpellingVariant(variants, removed.join(''));
        }
      }
    }

    return variants;
  }

  private pushUniqueSpellingVariant(variants: string[], value: string): void {
    if (this.normalizeSpelling(value) === this.normalizeSpelling(this.currentWord().word)) {
      return;
    }
    if (!this.containsSpellingOption(variants, value)) {
      variants.push(value);
    }
  }

  private nextSimilarLetter(character: string, offset: number): string {
    const lower: string = character.toLowerCase();
    if (!this.isEditableCharacter(lower)) {
      return character;
    }
    const code: number = lower.charCodeAt(0) - 97;
    const nextCode: number = (code + offset + 1) % 26;
    return String.fromCharCode(97 + nextCode);
  }

  private buildFallbackSpellingVariant(word: string, variantIndex: number): string {
    const characters: string[] = word.split('');
    if (characters.length === 0) {
      return word + variantIndex.toString();
    }

    let targetIndex: number = variantIndex % characters.length;
    for (let i: number = 0; i < characters.length; i++) {
      const probeIndex: number = (targetIndex + i) % characters.length;
      if (this.isEditableCharacter(characters[probeIndex])) {
        targetIndex = probeIndex;
        break;
      }
    }

    const current: string = characters[targetIndex].toLowerCase();
    if (!this.isEditableCharacter(current)) {
      return word + variantIndex.toString();
    }
    characters[targetIndex] = this.nextSimilarLetter(current, variantIndex + 3);
    return characters.join('');
  }

  private spellingModeTitle(): string {
    if (this.spellingQuestionMode === 'complete') {
      return '补全单词';
    }
    if (this.spellingQuestionMode === 'choice') {
      return this.choiceQuestionMode === 'wordToTranslation' ? '选择正确释义' : '选择正确拼写';
    }
    return '逐字母拼写';
  }

  private spellingPromptText(): string {
    if (this.spellingQuestionMode === 'choice' && this.choiceQuestionMode === 'wordToTranslation') {
      return this.currentWord().word;
    }
    return this.currentWord().translation;
  }

  private optionWord(option: string): Word {
    const normalizedOption: string = this.normalizeSpelling(option);
    if (normalizedOption === this.normalizeSpelling(this.currentWord().word)) {
      return this.currentWord();
    }
    for (let i: number = 0; i < this.spellingDistractorPool.length; i++) {
      if (this.normalizeSpelling(this.spellingDistractorPool[i].word) === normalizedOption) {
        return this.spellingDistractorPool[i];
      }
    }
    for (let i: number = 0; i < this.words.length; i++) {
      if (this.normalizeSpelling(this.words[i].word) === normalizedOption) {
        return this.words[i];
      }
    }
    return this.currentWord();
  }

  private optionPrimaryText(option: string): string {
    if (this.choiceQuestionMode === 'wordToTranslation') {
      return this.optionWord(option).translation;
    }
    return option;
  }

  private optionRevealText(option: string): string {
    if (!this.spellingChecked) {
      return '';
    }
    if (this.choiceQuestionMode === 'wordToTranslation') {
      return option;
    }
    return this.optionWord(option).translation;
  }

  private spellingLetterAt(index: number): string {
    if (index < 0 || index >= this.spellingLetters.length) {
      return '';
    }
    return this.spellingLetters[index];
  }

  private spellingSlotAreaHeight(): number {
    const rowCount: number = Math.max(1, Math.ceil(this.currentWordCharacters().length / 7));
    return Math.min(146, rowCount * 42 + 6);
  }

  private spellingSlotFromTouch(x: number, y: number): number {
    const column: number = Math.floor(Math.max(0, x) / 40);
    const row: number = Math.floor(Math.max(0, y) / 42);
    const index: number = row * 7 + column;
    if (index >= 0 && index < this.spellingEditableSlots.length && this.spellingEditableSlots[index]) {
      return index;
    }
    return this.activeSpellingSlot >= 0 ? this.activeSpellingSlot : this.firstEmptySpellingSlot();
  }

  private optionSelected(option: string): boolean {
    return this.normalizeSpelling(option) === this.normalizeSpelling(this.selectedSpellingOption);
  }

  private handleSpellingHint(): void {
    if (this.spellingQuestionMode === 'choice' || this.spellingChecked || this.spellingHintLevel >= 2) {
      return;
    }
    if (this.spellingHintLevel === 0) {
      this.spellingHintText = this.buildPartialSpellingHint();
      this.spellingHintLevel = 1;
      return;
    }
    this.spellingHintText = this.currentWord().word;
    this.spellingHintLevel = 2;
  }

  private buildPartialSpellingHint(): string {
    const characters: string[] = this.currentWordCharacters();
    const segment: number = this.currentIndex % 3;
    const start: number = Math.floor(characters.length * segment / 3);
    const end: number = Math.max(start + 1, Math.floor(characters.length * (segment + 1) / 3));
    return this.currentWord().word.substring(start, Math.min(end, characters.length));
  }

  private hintButtonText(): string {
    return '提示';
  }

  private isCorrectOption(option: string): boolean {
    return this.normalizeSpelling(option) === this.normalizeSpelling(this.currentWord().word);
  }

  private optionBorderColor(option: string): string {
    if (this.spellingChecked && this.isCorrectOption(option)) {
      return ThemeColor.get(this.darkMode).success;
    }
    if (this.spellingChecked && this.optionSelected(option) && !this.isCorrectOption(option)) {
      return ThemeColor.get(this.darkMode).danger;
    }
    return this.optionSelected(option) ? ThemeColor.get(this.darkMode).primary : ThemeColor.get(this.darkMode).border;
  }

  private optionTextColor(option: string): string {
    if (this.spellingChecked && this.isCorrectOption(option)) {
      return ThemeColor.get(this.darkMode).success;
    }
    if (this.spellingChecked && this.optionSelected(option) && !this.isCorrectOption(option)) {
      return ThemeColor.get(this.darkMode).danger;
    }
    return this.optionSelected(option) ? ThemeColor.get(this.darkMode).primary : ThemeColor.get(this.darkMode).textPrimary;
  }

  @Builder
  private buildSpellingPronounceButton() {
    Image(this.spellingPronounceIcon())
      .width(26)
      .height(26)
      .objectFit(ImageFit.Contain)
      .margin({ right: 8 })
      .onClick(() => {
        this.runSpellingPronounceAnimation(this.playCurrentWord());
      })
  }

  @Builder
  private buildLetterSlot(character: string, index: number) {
    Column() {
      Text(this.spellingLetterAt(index).length > 0 ? this.spellingLetterAt(index) : ' ')
        .width(30)
        .height(32)
        .fontSize(20)
        .lineHeight(32)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .textAlign(TextAlign.Center)

      Column() {
        Row()
          .width(30)
          .height(this.activeSpellingSlot === index && this.spellingEditableSlots[index] && !this.spellingChecked ? 3 : 2)
          .backgroundColor(this.spellingEditableSlots[index] ? ThemeColor.get(this.darkMode).primary : ThemeColor.get(this.darkMode).border)
          .borderRadius(1)
      }
      .width(30)
      .height(6)
      .justifyContent(FlexAlign.Center)
    }
    .width(34)
    .height(40)
    .margin({ right: 6, top: 2 })
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.activateSpellingSlot(index);
    })
  }

  @Builder
  private buildSpellingInputLayer() {
    TextInput({ text: this.spellingInput, placeholder: '' })
      .width(1)
      .height(1)
      .id(this.SPELLING_INPUT_ID)
      .type(InputType.Normal)
      .autoCapitalizationMode(AutoCapitalizationMode.NONE)
      .enablePreviewText(false)
      .inputFilter('[A-Za-z]')
      .maxLength(1)
      .defaultFocus(!this.spellingChecked && this.studyPhase === 'spell' && this.spellingQuestionMode !== 'choice')
      .opacity(0.01)
      .fontColor(Color.Transparent)
      .placeholderColor(Color.Transparent)
      .backgroundColor(Color.Transparent)
      .caretColor(Color.Transparent)
      .enableAutoFill(false)
      .enableKeyboardOnFocus(true)
      .enabled(!this.spellingChecked && !this.isSubmitting)
      .onAppear(() => {
        this.focusSpellingInput();
      })
      .onChange((value: string) => {
        this.updateSpellingInput(value);
      })
      .onWillInsert((value: InsertValue): boolean => {
        this.updateSpellingInput(value.insertValue);
        return false;
      })
      .onWillDelete((_value: DeleteValue): boolean => {
        this.handleSpellingDelete();
        return false;
      })
  }

  @Builder
  private buildSpellingSlots() {
    Column() {
      this.buildSpellingInputLayer()

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        ForEach(this.currentWordCharacters(), (character: string, index: number) => {
          this.buildLetterSlot(character, index)
        }, (character: string, index: number) => index.toString() + '-' + character)
      }
      .width('100%')
      .height(this.spellingSlotAreaHeight())
      .onTouch((event: TouchEvent): void => {
        if (event.type === TouchType.Down && event.touches && event.touches.length > 0) {
          this.activateSpellingSlot(this.spellingSlotFromTouch(event.touches[0].x, event.touches[0].y));
        }
      })
      .margin({ top: 2 })
    }
    .width('100%')
    .margin({ top: 0, bottom: 4 })
  }

  @Builder
  private buildSpellingOptionButtons() {
    Column() {
      ForEach(this.spellingOptions, (option: string) => {
        Column() {
          Text(this.optionPrimaryText(option))
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.optionTextColor(option))
            .textAlign(TextAlign.Center)
            .maxLines(this.spellingChecked ? 2 : 1)
            .wordBreak(WordBreak.BREAK_WORD)
            .width('100%')

          if (this.optionRevealText(option).length > 0) {
            Text(this.optionRevealText(option))
              .fontSize(13)
              .fontColor(ThemeColor.get(this.darkMode).textSecondary)
              .textAlign(TextAlign.Center)
              .maxLines(1)
              .width('100%')
              .margin({ top: 4 })
          }
        }
        .width('100%')
        .height(this.spellingChecked ? 66 : 48)
        .padding({ left: 14, right: 14 })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(this.optionSelected(option) ? ThemeColor.get(this.darkMode).primaryLight : ThemeColor.get(this.darkMode).background)
        .border({ width: this.spellingChecked && this.isCorrectOption(option) ? 2 : 1, color: this.optionBorderColor(option) })
        .borderRadius(14)
        .margin({ top: 10 })
        .onClick(() => {
          this.selectSpellingOption(option);
        })
      }, (option: string) => option)
    }
    .width('100%')
    .margin({ top: 10 })
  }

  private phaseTitle(): string {
    if (this.studyPhase === 'spell') {
      return this.isUnknownStudy() ? '重新拼写巩固' : '拼写巩固';
    }
    return this.isUnknownStudy() ? '本次重新学习' : '本次学习';
  }

  private phaseIndexText(): string {
    return this.studyPhase === 'spell'
      ? '第 ' + (this.currentIndex + 1).toString() + ' 个拼写'
      : '第 ' + (this.currentIndex + 1).toString() + ' 个单词';
  }

  private finishTitle(): string {
    if (this.isUnknownStudy()) {
      return this.hasNextUnknownStudyGroup ? '本组重新学习完成' : '重新学习完成';
    }
    return this.showGoalBadge ? '今日学习目标已完成' : '本组学习完成';
  }

  private finishSummary(): string {
    if (this.isUnknownStudy()) {
      return '今日重新学习 ' + this.todayLearnCount.toString() + ' / 总 ' +
      this.unknownStudyTotalCount.toString() + '，拼写正确 ' + this.knownCount.toString() +
        ' 个，拼错 ' + this.unknownCount.toString() + ' 个';
    }
    return '拼写正确 ' + this.knownCount.toString() + ' 个，拼错 ' + this.unknownCount.toString() + ' 个';
  }

  private spellingActionText(): string {
    if (this.currentIndex < this.words.length - 1) {
      return '下一个拼写';
    }
    return this.isUnknownStudy() ? '完成重新学习' : '完成学习';
  }

  private isUnknownStudy(): boolean {
    return this.studyMode === 'unknown';
  }

  private pageTitle(): string {
    return this.isUnknownStudy() ? '重新学习' : '开始学习';
  }

  private todayProgressText(): string {
    if (this.isUnknownStudy()) {
      return '今日重新学习 ' + this.todayLearnCount.toString() + ' / 总 ' + this.unknownStudyTotalCount.toString();
    }
    return '今日 ' + this.todayLearnCount.toString() + ' / ' + this.dailyGoal.toString();
  }

  private spellingFeedbackColor(): string {
    if (this.spellingFeedback.length === 0) {
      return ThemeColor.get(this.darkMode).textSecondary;
    }
    return this.spellingCorrect ? ThemeColor.get(this.darkMode).success : ThemeColor.get(this.darkMode).danger;
  }

  private currentPartOfSpeech(): string {
    const partOfSpeech: string | undefined = this.currentWord().partOfSpeech;
    return partOfSpeech ? partOfSpeech : '';
  }

  private startDurationTimer(): void {
    if (this.sessionId <= 0) {
      return;
    }
    this.stopDurationTimer();
    this.durationTimer = setInterval((): void => {
      this.flushSessionDuration().catch((error: Error) => {
        console.error('StudyPage flushSessionDuration timer failed: ' + JSON.stringify(error));
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

  private updateStudyElapsedSeconds(): void {
    if (this.originalSessionStart <= 0) {
      this.studyElapsedSeconds = 0;
      return;
    }
    this.studyElapsedSeconds = Math.max(0, Math.floor((Date.now() - this.originalSessionStart) / 1000));
  }

  private formatStudyDuration(): string {
    const minutes: number = Math.floor(this.studyElapsedSeconds / 60);
    const seconds: number = this.studyElapsedSeconds % 60;
    return (minutes < 10 ? '0' : '') + minutes.toString() + ':' +
      (seconds < 10 ? '0' : '') + seconds.toString();
  }

  private spellingAccuracyText(): string {
    const total: number = this.knownCount + this.unknownCount;
    if (total <= 0) {
      return '0%';
    }
    return Math.round((this.knownCount / total) * 100).toString() + '%';
  }

  private sessionProgressWidth(): string {
    if (this.words.length <= 0) {
      return '0%';
    }
    const progress: number = Math.round(((this.currentIndex + 1) / this.words.length) * 100);
    return Math.max(4, Math.min(100, progress)).toString() + '%';
  }

  @Builder
  private buildStudyProgress() {
    Column() {
      Row() {
        Column() {
          Text(this.phaseTitle())
            .fontSize(11)
            .fontColor(ThemeColor.get(this.darkMode).textSecondary)

          Text(this.phaseIndexText())
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeColor.get(this.darkMode).textPrimary)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.todayProgressText())
          .fontSize(this.isUnknownStudy() ? 12 : 13)
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

          Text(this.sessionProgressWidth())
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
            .width(this.sessionProgressWidth())
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
  private buildSpellingCard() {
    Column() {
      Row() {
        Column() {
          Text(this.spellingModeTitle())
            .fontSize(11)
            .fontColor(ThemeColor.get(this.darkMode).textSecondary)

          Text(this.spellingPromptText())
            .width('100%')
            .fontSize(22)
            .lineHeight(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeColor.get(this.darkMode).textPrimary)
            .textAlign(TextAlign.Start)
            .wordBreak(WordBreak.BREAK_WORD)
            .margin({ top: 12 })

          if (this.currentWord().phonetic.length > 0 || this.currentPartOfSpeech().length > 0) {
            Row() {
              this.buildSpellingPronounceButton()

              Text((this.currentPartOfSpeech().length > 0 ? this.currentPartOfSpeech() + '  ' : '') + this.currentWord().phonetic)
                .fontSize(14)
                .fontColor(ThemeColor.get(this.darkMode).textSecondary)
                .layoutWeight(1)
            }
            .alignItems(VerticalAlign.Center)
            .margin({ top: 10 })
            .width('100%')
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .padding({ right: 10 })

        Column() {
          Text((this.currentIndex + 1).toString() + ' / ' + this.words.length.toString())
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeColor.get(this.darkMode).primary)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor(ThemeColor.get(this.darkMode).primaryLight)
            .borderRadius(12)

          if (this.spellingQuestionMode !== 'choice') {
            Button(this.hintButtonText())
              .buttonStyle(ButtonStyleMode.NORMAL)
              .controlSize(ControlSize.SMALL)
              .role(ButtonRole.NORMAL)
              .enabled(!this.spellingChecked && this.spellingHintLevel < 2)
              .margin({ top: 8 })
              .onClick(() => {
                this.handleSpellingHint();
              })
          }
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      if (this.spellingHintText.length > 0) {
        Column() {
          Text('提示：' + this.spellingHintText)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeColor.get(this.darkMode).primary)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(ThemeColor.get(this.darkMode).primaryLight)
            .borderRadius(12)
        }
        .width('100%')
        .margin({ top: 6 })
        .alignItems(HorizontalAlign.Start)
      }

      if (this.spellingQuestionMode === 'choice') {
        this.buildSpellingOptionButtons()
      } else {
        this.buildSpellingSlots()
      }

      if (this.spellingFeedback.length > 0) {
        Text(this.spellingFeedback)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.spellingFeedbackColor())
          .margin({ top: 6 })
          .width('100%')
          .textAlign(TextAlign.Center)
      }

      if (this.spellingChecked) {
        Button(this.spellingActionText())
          .width('100%')
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .controlSize(ControlSize.NORMAL)
          .role(ButtonRole.NORMAL)
          .enabled(!this.isSubmitting)
          .margin({ top: 8 })
          .onClick(() => {
            this.handleSpellingNext();
          })
      } else {
        Button(this.spellingQuestionMode === 'choice' ? '提交选择' : '提交答案')
          .width('100%')
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .controlSize(ControlSize.NORMAL)
          .role(ButtonRole.NORMAL)
          .enabled(!this.isSubmitting)
          .margin({ top: 10 })
          .onClick(() => {
            this.handleSpellingSubmit();
          })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 18, bottom: 18 })
    .backgroundColor(this.darkMode ? '#111827' : '#FFFFFF')
    .borderRadius(20)
    .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
    .shadow({ radius: 10, color: 'rgba(15, 23, 42, 0.05)', offsetY: 4 })
    .margin({ top: 18 })
  }

  @Builder
  private buildEmpty(message: string) {
    Column() {
      Text(message)
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)

      Button('返回首页')
        .width('100%')
        .buttonStyle(ButtonStyleMode.EMPHASIZED)
        .controlSize(ControlSize.NORMAL)
        .role(ButtonRole.NORMAL)
        .margin({ top: 28 })
        .onClick(() => {
          this.goBack();
        })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildGoalFinishedMetric(value: string, label: string, color: string) {
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
  private buildGoalFinished() {
    Column() {
      Image(this.darkMode ? $r('app.media.review_complete_dark') : $r('app.media.review_complete_light'))
        .width(64)
        .height(64)
        .objectFit(ImageFit.Contain)
        .accessibilityText('今日学习目标已完成')

      Text('今日学习目标已完成')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .textAlign(TextAlign.Center)
        .margin({ top: 18 })

      Text('本轮完成 ' + (this.knownCount + this.unknownCount).toString() + ' 个单词')
        .fontSize(14)
        .fontColor(ThemeColor.get(this.darkMode).textSecondary)
        .margin({ top: 8 })

      Column() {
        Row() {
          this.buildGoalFinishedMetric(this.knownCount.toString(), '拼写正确', ThemeColor.get(this.darkMode).success)

          Row()
            .width(1)
            .height(42)
            .backgroundColor(ThemeColor.get(this.darkMode).border)

          this.buildGoalFinishedMetric(this.unknownCount.toString(), '拼写错误', ThemeColor.get(this.darkMode).danger)

          Row()
            .width(1)
            .height(42)
            .backgroundColor(ThemeColor.get(this.darkMode).border)

          this.buildGoalFinishedMetric(this.spellingAccuracyText(), '正确率', ThemeColor.get(this.darkMode).primary)
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
            .accessibilityText('学习用时')

          Text('学习用时')
            .fontSize(14)
            .fontColor(ThemeColor.get(this.darkMode).textSecondary)
            .margin({ left: 8 })

          Blank()

          Text(this.formatStudyDuration())
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

      Button('返回首页')
        .width('100%')
        .constraintSize({ maxWidth: 340 })
        .buttonStyle(ButtonStyleMode.EMPHASIZED)
        .controlSize(ControlSize.NORMAL)
        .role(ButtonRole.NORMAL)
        .margin({ top: 22 })
        .onClick(() => {
          this.goBack();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 24, right: 24, bottom: 16 })
  }

  pageTransition() {
    PageTransitionEnter({ duration: 180, curve: Curve.EaseOut }).opacity(0)
    PageTransitionExit({ duration: 140, curve: Curve.EaseIn }).opacity(0)
  }

  build() {
    HdsNavDestination() {
      List({ scroller: this.pageScroller }) {
        if (this.isLoading) {
          ListItem() {
            this.buildEmpty('正在加载单词...')
          }
          .height('100%')
        } else if (this.emptyMessage.length > 0) {
          ListItem() {
            this.buildEmpty(this.emptyMessage)
          }
          .height('100%')
        } else if (this.isFinished) {
          ListItem() {
            if (this.showGoalBadge) {
              this.buildGoalFinished()
            } else {
              Column() {
                Text(this.finishTitle())
                  .fontSize(30)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(ThemeColor.get(this.darkMode).textPrimary)

                Text(this.finishSummary())
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(ThemeColor.get(this.darkMode).textSecondary)
                  .margin({ top: 12 })

                if (this.isUnknownStudy() && this.hasNextUnknownStudyGroup) {
                  Button('继续下一组')
                    .width('100%')
                    .buttonStyle(ButtonStyleMode.EMPHASIZED)
                    .controlSize(ControlSize.NORMAL)
                    .role(ButtonRole.NORMAL)
                    .margin({ top: 30 })
                    .onClick(() => {
                      this.startNextUnknownStudyGroup();
                    })
                }

                Button('返回首页')
                  .width('100%')
                  .buttonStyle((this.isUnknownStudy() && this.hasNextUnknownStudyGroup) ? ButtonStyleMode.NORMAL : ButtonStyleMode.EMPHASIZED)
                  .controlSize(ControlSize.NORMAL)
                  .role(ButtonRole.NORMAL)
                  .margin({ top: (this.isUnknownStudy() && this.hasNextUnknownStudyGroup) ? 12 : 30 })
                  .onClick(() => {
                    this.goBack();
                  })
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
            }
          }
          .height('100%')
        } else {
          ListItem() {
            this.buildStudyProgress()
          }

          ListItem() {
            if (this.studyPhase === 'spell') {
              this.buildSpellingCard()
            } else {
              WordCard({
                wordText: this.currentWord().word,
                phonetic: this.currentWord().phonetic,
                partOfSpeech: this.currentWord().partOfSpeech ? this.currentWord().partOfSpeech : '',
                translation: this.currentWord().translation,
                example: this.currentWord().example,
                showDetail: this.showDetail,
                cardBackground: ThemeColor.get(this.darkMode).cardBackground,
                textPrimary: ThemeColor.get(this.darkMode).textPrimary,
                textSecondary: ThemeColor.get(this.darkMode).textSecondary,
                primary: ThemeColor.get(this.darkMode).primary,
                dividerColor: ThemeColor.get(this.darkMode).border,
                compactMode: true,
                darkMode: this.darkMode,
                pronounceRequestId: this.pronounceRequestId,
                onPronounce: async () => {
                  await this.playCurrentWord();
                }
              })
              .width('100%')
              .margin({ top: 18 })
            }
          }

          if (this.audioMessage.length > 0) {
            ListItem() {
              Text(this.audioMessage)
                .fontSize(13)
                .fontColor(ThemeColor.get(this.darkMode).textSecondary)
                .margin({ top: 10 })
            }
          }

          if (this.studyPhase === 'learn') {
            ListItem() {
              Column() {
                Button('查看释义')
                  .width('100%')
                  .buttonStyle(ButtonStyleMode.NORMAL)
                  .controlSize(ControlSize.NORMAL)
                  .role(ButtonRole.NORMAL)
                  .enabled(!this.showDetail && !this.isSubmitting)
                  .onClick(() => {
                    this.revealDetail();
                  })

                Button('下一个')
                  .width('100%')
                  .buttonStyle(ButtonStyleMode.EMPHASIZED)
                  .controlSize(ControlSize.NORMAL)
                  .role(ButtonRole.NORMAL)
                  .enabled(!this.isSubmitting)
                  .margin({ top: 14 })
                  .onClick(() => {
                    this.handleNext();
                  })
              }
              .width('100%')
              .padding({ left: 14, right: 14, top: 14, bottom: 14 })
              .backgroundColor(this.darkMode ? '#111827' : '#FFFFFF')
              .borderRadius(20)
              .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
              .shadow({ radius: 10, color: 'rgba(15, 23, 42, 0.05)', offsetY: 4 })
              .margin({ top: 18 })
            }
          }
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 20, right: 20, top: 0, bottom: 28 })
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .enableScrollInteraction(true)
      .friction(0.75)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .titleBar(createHdsSubPageTitleBarOptions(
      this.pageTitle(),
      this.darkMode,
      this.materialEffectMode,
      undefined,
      this.getTitleMenuItems()
    ))
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

