import { common } from '@kit.AbilityKit';
import { Chip, ChipSize, SelectionMenu } from '@kit.ArkUI';
import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import inputMethod from '@ohos.inputMethod';
import router from '@ohos.router';
import { createHdsSubPageTitleBarOptions } from '../components/HdsSubPageTitleBarOptions';
import { WordListItem } from '../components/WordListItem';
import {
  DictionaryDefinition,
  DictionaryEnglishDefinition,
  DictionaryExample,
  DictionaryLookupResult,
  DictionaryNetworkDefinition,
  DictionaryPhrase,
  DictionarySpecialDefinition
} from '../model/DictionaryResult';
import { Word } from '../model/Word';
import { DatabaseService } from '../services/DatabaseService';
import { AudioService } from '../services/AudioService';
import { CambridgeDictionaryService } from '../services/CambridgeDictionaryService';
import { PreferencesService } from '../services/PreferencesService';
import { ThemeService } from '../services/ThemeService';
import { WordService } from '../services/WordService';
import { YoudaoDictionaryService } from '../services/YoudaoDictionaryService';
import { Constants } from '../utils/Constants';
import { DateUtil } from '../utils/DateUtil';
import { HomeSearchTransition, SearchTransitionRect } from '../utils/HomeSearchTransition';
import { HomeModuleTransition, HomeModuleTransitionRoute } from '../utils/HomeModuleTransition';
import { ThemeColor } from '../utils/ThemeColor';

interface SearchParams {
  mode?: string;
  title?: string;
  timeTab?: string;
  bookId?: number;
  searchResultRoute?: boolean;
  searchKeyword?: string;
  suppressInitialKeyboard?: boolean;
  autoFocusSearch?: boolean;
  homeSearchTransitionSource?: SearchTransitionRect;
  homeModuleTransition?: HomeModuleTransitionRoute;
}

interface WordModeVisual {
  code: string;
  eyebrow: string;
  title: string;
  subtitle: string;
  accent: string;
  accentSoft: string;
  gradientStart: string;
  gradientEnd: string;
  metricLabel: string;
  emptyTitle: string;
  emptyHint: string;
}

interface DictionaryDefinitionTab {
  code: string;
  title: string;
}

interface DictionaryExampleTab {
  code: string;
  title: string;
}

@Entry
@Component
struct SearchPage {
  @State private isLoading: boolean = false;
  @State private keyword: string = '';
  @State private searchHistory: string[] = [];
  @State private isEditingSearchHistory: boolean = false;
  @State private showingSearchResults: boolean = false;
  @State private title: string = '单词搜索';
  @State private mode: string = '';
  @State private words: Word[] = [];
  @State private filteredWords: Word[] = [];
  @State private message: string = '';
  @State private dictionaryResult: DictionaryLookupResult = this.emptyDictionaryResult();
  @State private audioMessage: string = '';
  @State private dictionaryPronounceFrame: number = 2;
  @State private selectedDictionaryDefinitionTab: string = 'network';
  @State private selectedExampleTab: string = 'bilingual';
  @State private activeDictionaryPronounceWord: string = '';
  @State private searchEngine: string = Constants.DEFAULT_SEARCH_ENGINE;
  @State private wordCount: number = 0;
  @State private wordTimeTab: string = '全部';
  @State private bookId: number = 0;
  @State private sortAscending: boolean = true;
  @State private searchFocused: boolean = false;
  @State private searchExpanded: boolean = false;
  @State private suppressInitialKeyboard: boolean = false;
  @State private autoFocusSearch: boolean = false;
  @State private statusSearchFocused: boolean = false;
  @State private statusSearchExpanded: boolean = false;
  @State private statusFloatingSearchVisible: boolean = false;
  @State private showStatusBackToTop: boolean = false;
  @State private mainSearchTranslateX: number = 0;
  @State private mainSearchTranslateY: number = 0;
  @State private mainSearchScaleX: number = 1;
  @State private mainSearchScaleY: number = 1;
  @State private mainSearchOpacity: number = 1;
  @State private searchHistoryOpacity: number = 1;
  @State private searchHistoryTranslateY: number = 0;
  @State private homeModuleContentStage: number = 7;
  private wordTimeTabs: string[] = ['全部', '日', '周', '月', '年'];
  private pageScroller: Scroller = new Scroller();
  private isSearchResultRoute: boolean = false;
  private searchRouteNavigating: boolean = false;
  private savedPageScrollY: number = 0;
  private shouldRestorePageScroll: boolean = false;
  private lastStatusScrollY: number = 0;
  private statusUpScrollDistance: number = 0;
  private dictionaryPronounceAnimationTimer: number = -1;
  private dictionaryPronounceAnimationId: number = 0;
  private homeSearchTransitionSource: SearchTransitionRect | undefined = undefined;
  private homeSearchTransitionPrepared: boolean = false;
  private homeSearchFocusRequested: boolean = false;
  private homeSearchInputEntranceFinished: boolean = false;
  private searchHistoryMounted: boolean = false;
  private searchHistoryEntranceStarted: boolean = false;
  private homeSearchAnimationTimer: number = -1;
  private homeSearchFocusTimer: number = -1;
  private homeModuleTransition: HomeModuleTransitionRoute | undefined = undefined;
  private homeModuleTransitionPrepared: boolean = false;
  private homeModuleFallbackTimer: number = -1;
  private homeModuleContentTimers: number[] = [];
  private mainSearchStartTranslateX: number = 0;
  private mainSearchStartTranslateY: number = 0;
  private mainSearchStartScaleX: number = 1;
  private mainSearchStartScaleY: number = 1;
  private readonly MAIN_SEARCH_INPUT_ID: string = 'search-page-main-input';
  private readonly MAIN_SEARCH_TRANSITION_ID: string = 'search-page-main-input-transition';
  private readonly STATUS_HEADER_TRANSITION_ID: string = 'search-page-status-header-transition';
  private readonly HOME_SEARCH_ANIMATION_START_DELAY: number = 32;
  private readonly HOME_MODULE_CONTENT_ENTRANCE_DELAY: number = 80;
  private readonly HOME_MODULE_CONTENT_ITEM_DELAY: number = 40;
  private readonly HOME_MODULE_MAX_ENTRY_ITEMS: number = 8;
  private readonly MAIN_SEARCH_CONTENT_OVERLAP: number = 12;
  private readonly MAIN_SEARCH_LOCAL_WORD_CARD_MARGIN: number = 12;
  private readonly MAIN_SEARCH_BOTTOM_SPACER: number = 64;
  @StorageLink('resolvedDarkMode') darkMode: boolean = false;
  @StorageLink('materialEffectMode') materialEffectMode: number = Constants.DEFAULT_MATERIAL_EFFECT_MODE;

  aboutToAppear(): void {
    this.readRouteParams();
    this.applyImmersiveBars();
    this.initPage();
  }

  onPageShow(): void {
    if (this.shouldRestorePageScroll) {
      this.restorePageScrollPosition();
      return;
    }
    this.refreshOnShow();
  }

  private async refreshOnShow(): Promise<void> {
    try {
      await this.applyImmersiveBars();
      const ctx = getContext(this) as common.Context;
      await PreferencesService.init(ctx);
      this.searchEngine = await PreferencesService.getSearchEngine();
      this.searchHistory = await PreferencesService.getSearchHistory();
      
      if (this.mode.length > 0) {
        await this.loadModeWords();
      } else if (this.isSearchResultRoute && this.keyword.trim().length > 0) {
        await this.loadSearchResults(this.keyword.trim());
      }
    } catch (error) {
      console.error('SearchPage refreshOnShow failed: ' + JSON.stringify(error));
    }
  }

  private async applyImmersiveBars(): Promise<void> {
    const context = getContext(this) as common.Context;
    await ThemeService.applySystemBars(context, this.darkMode);
  }

  private async initPage(): Promise<void> {
    try {
      const context = getContext(this) as common.Context;
      await DatabaseService.init(context);
      await PreferencesService.init(context);
      this.searchEngine = await PreferencesService.getSearchEngine();
      this.searchHistory = await PreferencesService.getSearchHistory();
      
      if (this.mode.length > 0) {
        await this.loadModeWords();
      }
      if (this.autoFocusSearch && this.mode.length === 0 && !this.hasHomeSearchTransition()) {
        this.searchFocused = true;
        this.searchExpanded = true;
      }
      if (this.suppressInitialKeyboard) {
        setTimeout(() => {
          this.searchFocused = false;
          this.searchExpanded = false;
          this.hideKeyboard();
        }, 120);
      }
    } catch (error) {
      console.error('SearchPage init failed: ' + JSON.stringify(error));
    }
  }

  private readRouteParams(): void {
    const params: SearchParams = router.getParams() as SearchParams;
    this.isSearchResultRoute = !!(params && params.searchResultRoute);
    if (this.isSearchResultRoute && params.searchKeyword) {
      this.keyword = params.searchKeyword;
      this.showingSearchResults = true;
    }
    this.suppressInitialKeyboard = !!(params && params.suppressInitialKeyboard);
    this.autoFocusSearch = !!(params && params.autoFocusSearch);
    this.homeSearchTransitionSource = params ? params.homeSearchTransitionSource : undefined;
    if (this.hasHomeSearchTransition()) {
      this.mainSearchOpacity = 0;
      this.searchHistoryOpacity = 0;
      this.searchHistoryTranslateY = 12;
    }
    if (params && params.mode) {
      this.mode = params.mode;
      this.title = params.title ? params.title : '单词列表';
      if (params.timeTab) {
        this.wordTimeTab = params.timeTab;
      }
      if (params.bookId && params.bookId > 0) {
        this.bookId = params.bookId;
      }
    } else if (params && params.bookId && params.bookId > 0) {
      this.bookId = params.bookId;
    }
    this.homeModuleTransition = params ? params.homeModuleTransition : undefined;
    if (this.hasHomeModuleTransition()) {
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

  private hasHomeSearchTransition(): boolean {
    return this.mode.length === 0 && HomeSearchTransition.isValid(this.homeSearchTransitionSource);
  }

  private hasHomeModuleTransition(): boolean {
    return this.isWordStatusPage() && HomeModuleTransition.isValidRoute(this.homeModuleTransition);
  }

  private readMainSearchRect(): SearchTransitionRect | undefined {
    return this.readTransitionRect(this.MAIN_SEARCH_TRANSITION_ID);
  }

  private readTransitionRect(componentId: string): SearchTransitionRect | undefined {
    try {
      const componentInfo = this.getUIContext().getComponentUtils().getRectangleById(componentId);
      const rect: SearchTransitionRect = {
        x: componentInfo.windowOffset.x,
        y: componentInfo.windowOffset.y,
        width: componentInfo.size.width,
        height: componentInfo.size.height
      };
      return HomeSearchTransition.isValid(rect) ? rect : undefined;
    } catch (error) {
      console.warn('SearchPage read transition rect failed: ' + JSON.stringify(error));
      return undefined;
    }
  }

  private beginHomeModuleEnterTransition(): void {
    if (!this.hasHomeModuleTransition() || this.homeModuleTransitionPrepared) {
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
    if (!this.hasHomeModuleTransition() || stage > this.HOME_MODULE_MAX_ENTRY_ITEMS + 2) {
      return 1;
    }
    return this.homeModuleContentStage >= stage ? 1 : 0;
  }

  private getHomeModuleContentOffset(stage: number): number {
    return this.getHomeModuleContentOpacity(stage) > 0 ? 0 : 16;
  }

  private beginHomeSearchEnterTransition(): void {
    if (!this.hasHomeSearchTransition() || this.homeSearchTransitionPrepared) {
      return;
    }
    const source: SearchTransitionRect | undefined = this.homeSearchTransitionSource;
    const target: SearchTransitionRect | undefined = this.readMainSearchRect();
    if (source === undefined || target === undefined) {
      this.mainSearchOpacity = 1;
      this.homeSearchTransitionPrepared = true;
      this.finishHomeSearchInputEntrance();
      return;
    }
    this.mainSearchStartTranslateX = px2vp(source.x + source.width / 2 - target.x - target.width / 2);
    this.mainSearchStartTranslateY = px2vp(source.y + source.height / 2 - target.y - target.height / 2);
    this.mainSearchStartScaleX = source.width / target.width;
    this.mainSearchStartScaleY = source.height / target.height;
    this.mainSearchTranslateX = this.mainSearchStartTranslateX;
    this.mainSearchTranslateY = this.mainSearchStartTranslateY;
    this.mainSearchScaleX = this.mainSearchStartScaleX;
    this.mainSearchScaleY = this.mainSearchStartScaleY;
    this.mainSearchOpacity = 0;
    this.homeSearchTransitionPrepared = true;
    this.homeSearchAnimationTimer = setTimeout((): void => {
      this.homeSearchAnimationTimer = -1;
      animateTo({ duration: 240, curve: Curve.EaseOut }, () => {
        this.mainSearchTranslateX = 0;
        this.mainSearchTranslateY = 0;
        this.mainSearchScaleX = 1;
        this.mainSearchScaleY = 1;
        this.mainSearchOpacity = 1;
      });
    }, this.HOME_SEARCH_ANIMATION_START_DELAY);
    this.homeSearchFocusTimer = setTimeout((): void => {
      this.homeSearchFocusTimer = -1;
      this.finishHomeSearchInputEntrance();
    }, this.HOME_SEARCH_ANIMATION_START_DELAY + 240);
  }

  private finishHomeSearchInputEntrance(): void {
    this.homeSearchInputEntranceFinished = true;
    this.requestHomeSearchFocus();
    this.revealSearchHistoryAfterHomeTransition();
  }

  private revealSearchHistoryAfterHomeTransition(): void {
    if (!this.hasHomeSearchTransition() || !this.homeSearchInputEntranceFinished ||
        !this.searchHistoryMounted || this.searchHistoryEntranceStarted) {
      return;
    }
    this.searchHistoryEntranceStarted = true;
    animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
      this.searchHistoryOpacity = 1;
      this.searchHistoryTranslateY = 0;
    });
  }

  private requestHomeSearchFocus(): void {
    if (!this.autoFocusSearch || this.homeSearchFocusRequested) {
      return;
    }
    this.homeSearchFocusRequested = true;
    focusControl.requestFocus(this.MAIN_SEARCH_INPUT_ID);
  }

  private returnToPreviousPage(): void {
    if (this.hasHomeSearchTransition()) {
      const source: SearchTransitionRect | undefined = this.readMainSearchRect();
      if (source !== undefined) {
        HomeSearchTransition.setReturnSource(source);
      }
    }
    if (this.hasHomeModuleTransition() && this.homeModuleTransition !== undefined) {
      const source: SearchTransitionRect | undefined = this.readTransitionRect(this.STATUS_HEADER_TRANSITION_ID);
      if (source !== undefined) {
        HomeModuleTransition.setReturnSource(this.homeModuleTransition.id, source);
      }
    }
    router.back();
  }

  private async loadModeWords(): Promise<void> {
    this.isLoading = true;
    try {
      // 未选择词书时，所有统计模式均返回空
      if (this.bookId <= 0 && this.mode.length > 0 && this.mode !== 'all') {
        this.words = [];
        this.filteredWords = [];
        this.wordCount = 0;
        this.isLoading = false;
        this.message = '请先选择词书';
        return;
      }
      if (this.mode === 'unstudied') {
        if (this.bookId > 0) {
          this.words = await WordService.getUnstudiedWordsByBookId(this.bookId);
        } else {
          this.words = await WordService.getWordsByStatType('unstudied');
        }
      } else if (this.mode === 'all' && this.bookId > 0) {
        this.words = await WordService.getWordsByBookId(this.bookId);
      } else if (this.wordTimeTab !== '全部') {
        const startDate: string = DateUtil.periodStartKey(this.wordTimeTab);
        const endDate: string = DateUtil.periodEndKey(this.wordTimeTab);
        this.words = await WordService.getWordsByPeriod(this.mode, startDate, endDate, this.bookId);
      } else {
        this.words = await WordService.getWordsByStatType(this.mode, this.bookId);
      }
      this.words = this.sortWordsByAlphabet(this.words);
      this.wordCount = this.words.length;
      this.applyWordFilter();
      this.message = this.words.length === 0 ? '暂无单词记录' : '';
    } catch (error) {
      console.error('loadModeWords failed: ' + JSON.stringify(error));
      this.message = '加载失败';
    } finally {
      this.isLoading = false;
    }
  }

  private onWordTimeTabChange(tab: string): void {
    this.wordTimeTab = tab;
    this.loadModeWords();
  }

  private async recordSearchHistory(keyword: string): Promise<void> {
    const nextHistory: string[] = [keyword];
    for (let index: number = 0; index < this.searchHistory.length; index++) {
      if (this.searchHistory[index] !== keyword && nextHistory.length < Constants.DEFAULT_SEARCH_HISTORY_LIMIT) {
        nextHistory.push(this.searchHistory[index]);
      }
    }
    this.searchHistory = nextHistory;
    await PreferencesService.setSearchHistory(nextHistory);
  }

  private useSearchHistory(keyword: string): void {
    if (this.isEditingSearchHistory) {
      return;
    }
    this.keyword = keyword;
    this.search();
  }

  private async removeSearchHistory(keyword: string): Promise<void> {
    const nextHistory: string[] = [];
    for (let index: number = 0; index < this.searchHistory.length; index++) {
      if (this.searchHistory[index] !== keyword) {
        nextHistory.push(this.searchHistory[index]);
      }
    }
    this.searchHistory = nextHistory;
    if (nextHistory.length === 0) {
      this.isEditingSearchHistory = false;
    }
    await PreferencesService.setSearchHistory(nextHistory);
  }

  private toggleSearchHistoryEditing(): void {
    if (this.searchHistory.length === 0) {
      return;
    }
    this.isEditingSearchHistory = !this.isEditingSearchHistory;
  }

  private async search(): Promise<void> {
    if (this.isLoading) {
      return;
    }
    this.mode = '';
    const trimmedKeyword: string = this.keyword.trim();
    if (trimmedKeyword.length === 0) {
      this.showingSearchResults = false;
      this.words = [];
      this.filteredWords = [];
      this.dictionaryResult = this.emptyDictionaryResult();
      this.selectedDictionaryDefinitionTab = 'network';
      this.selectedExampleTab = 'bilingual';
      this.audioMessage = '';
      this.message = '';
      return;
    }

    if (!this.isSearchResultRoute) {
      this.openSearchResultPage(trimmedKeyword);
      return;
    }

    await this.loadSearchResults(trimmedKeyword);
  }

  private openSearchResultPage(keyword: string): void {
    if (this.searchRouteNavigating) {
      return;
    }
    this.resetSearchResults();
    this.searchRouteNavigating = true;
    try {
      router.pushUrl({
        url: 'pages/SearchPage',
        params: {
          searchResultRoute: true,
          searchKeyword: keyword
        }
      }).then((): void => {
        this.searchRouteNavigating = false;
      }).catch((error: Error): void => {
        this.searchRouteNavigating = false;
        console.error('SearchPage open result page failed: ' + JSON.stringify(error));
      });
    } catch (error) {
      this.searchRouteNavigating = false;
      console.error('SearchPage open result page failed: ' + JSON.stringify(error));
    }
  }

  private async loadSearchResults(trimmedKeyword: string): Promise<void> {
    this.keyword = trimmedKeyword;
    this.showingSearchResults = true;
    this.isLoading = true;
    try {
      await this.recordSearchHistory(trimmedKeyword);
      this.dictionaryResult = this.emptyDictionaryResult();
      this.audioMessage = '';
      this.words = await WordService.searchWords(trimmedKeyword);
      this.filteredWords = [];
      this.dictionaryResult = await this.lookupDictionary(trimmedKeyword);
      this.resetDictionaryDefinitionTab();
      this.resetExampleTab();
      this.message = this.words.length === 0 && !this.dictionaryResult.success
        ? this.dictionaryResult.message
        : '';
    } catch (error) {
      console.error('search failed: ' + JSON.stringify(error));
      this.message = '搜索失败';
    } finally {
      this.isLoading = false;
    }
  }

  private async lookupDictionary(keyword: string): Promise<DictionaryLookupResult> {
    if (this.searchEngine === Constants.SEARCH_ENGINE_YOUDAO) {
      return await YoudaoDictionaryService.lookup(keyword);
    }
    return await CambridgeDictionaryService.lookup(keyword);
  }

  private async updateSearchEngine(index: number): Promise<void> {
    const nextEngine: string = index === 1 ? Constants.SEARCH_ENGINE_YOUDAO : Constants.SEARCH_ENGINE_CAMBRIDGE;
    if (this.searchEngine === nextEngine) {
      return;
    }
    this.searchEngine = nextEngine;
    await PreferencesService.setSearchEngine(nextEngine);
    if (this.mode.length === 0 && this.keyword.trim().length > 0) {
      await this.search();
    }
  }

  private searchEngineLabel(): string {
    return this.searchEngine === Constants.SEARCH_ENGINE_YOUDAO ? '有道词典' : '剑桥词典';
  }

  private canPlayDictionaryHeadword(): boolean {
    return this.dictionaryResult.audioUrl.length > 0 &&
      !/[\u3400-\u9FFF]/.test(this.dictionaryResult.query);
  }

  private async playDictionaryTermAudio(word: string, pronunciationUrl: string): Promise<void> {
    const context = getContext(this) as common.Context;
    this.audioMessage = await AudioService.playWord(
      word,
      pronunciationUrl,
      context
    );
  }

  private dictionaryPronounceIcon(word: string): Resource {
    if (this.activeDictionaryPronounceWord === word && this.dictionaryPronounceFrame === 0) {
      return this.darkMode ? $r('app.media.pronounce_dark_frame1') : $r('app.media.pronounce_light_frame1');
    }
    if (this.activeDictionaryPronounceWord === word && this.dictionaryPronounceFrame === 1) {
      return this.darkMode ? $r('app.media.pronounce_dark_frame2') : $r('app.media.pronounce_light_frame2');
    }
    return this.darkMode ? $r('app.media.pronounce_dark') : $r('app.media.pronounce_light');
  }

  private backToTopIcon(): Resource {
    return this.darkMode ? $r('app.media.back_to_top_dark') : $r('app.media.back_to_top_light');
  }

  private startDictionaryPronounceAnimation(word: string): number {
    this.stopDictionaryPronounceAnimation(false);
    const animationId: number = this.dictionaryPronounceAnimationId + 1;
    this.dictionaryPronounceAnimationId = animationId;
    this.activeDictionaryPronounceWord = word;
    this.dictionaryPronounceFrame = 0;
    this.dictionaryPronounceAnimationTimer = setInterval(() => {
      this.dictionaryPronounceFrame = (this.dictionaryPronounceFrame + 1) % 3;
    }, Constants.PRONUNCIATION_ANIMATION_FRAME_INTERVAL_MS);
    return animationId;
  }

  private stopDictionaryPronounceAnimation(resetFrame: boolean = true): void {
    if (this.dictionaryPronounceAnimationTimer >= 0) {
      clearInterval(this.dictionaryPronounceAnimationTimer);
      this.dictionaryPronounceAnimationTimer = -1;
    }
    if (resetFrame) {
      this.dictionaryPronounceFrame = 2;
      this.activeDictionaryPronounceWord = '';
    }
  }

  private async runDictionaryPronounceAnimation(word: string, playTask: Promise<void>): Promise<void> {
    const animationId: number = this.startDictionaryPronounceAnimation(word);
    try {
      await playTask;
    } finally {
      if (this.dictionaryPronounceAnimationId === animationId) {
        this.stopDictionaryPronounceAnimation();
      }
    }
  }

  private openWordDetail(wordId: number): void {
    this.capturePageScrollPosition();
    this.shouldRestorePageScroll = true;
    try {
      router.pushUrl({
        url: 'pages/WordDetailPage',
        params: {
          wordId: wordId
        }
      }).catch((error: Error): void => {
        this.shouldRestorePageScroll = false;
        console.error('SearchPage open word detail failed: ' + JSON.stringify(error));
      });
    } catch (error) {
      this.shouldRestorePageScroll = false;
      console.error('SearchPage open word detail failed: ' + JSON.stringify(error));
    }
  }

  private capturePageScrollPosition(): void {
    try {
      const offset = this.pageScroller.currentOffset();
      this.savedPageScrollY = Number(offset.yOffset);
    } catch (error) {
      console.error('SearchPage capture scroll position failed: ' + JSON.stringify(error));
    }
  }

  private restorePageScrollPosition(): void {
    if (!this.shouldRestorePageScroll) {
      return;
    }
    try {
      this.pageScroller.scrollTo({ xOffset: 0, yOffset: this.savedPageScrollY, animation: false });
      this.lastStatusScrollY = this.savedPageScrollY;
      this.shouldRestorePageScroll = false;
    } catch (error) {
      console.error('SearchPage restore scroll position failed: ' + JSON.stringify(error));
    }
  }

  private startUnknownStudy(): void {
    const params: Record<string, Object> = {};
    if (this.bookId > 0) {
      params['bookId'] = this.bookId;
    }
    params['mode'] = 'unknown';
    params['timeTab'] = this.wordTimeTab;
    router.pushUrl({ url: 'pages/StudyPage', params: params });
  }

  private goBack(): void {
    this.returnToPreviousPage();
  }

  private hideKeyboard(): void {
    inputMethod.getController().hideTextInput().catch((error: Error) => {
      console.error('SearchPage hide keyboard failed: ' + JSON.stringify(error));
    });
  }

  private collapseStatusSearch(): void {
    if (this.statusSearchFocused || this.statusSearchExpanded) {
      animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
        this.statusSearchFocused = false;
        this.statusSearchExpanded = false;
      });
    }
    this.hideKeyboard();
  }

  private setSearchFocused(focused: boolean): void {
    if (this.searchFocused === focused) {
      return;
    }
    animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
      this.searchFocused = focused;
      if (focused) {
        this.searchExpanded = true;
      }
    });
  }

  private collapseSearch(): void {
    if (this.searchFocused || this.searchExpanded) {
      animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
        this.searchFocused = false;
        this.searchExpanded = false;
      });
    }
    this.hideKeyboard();
  }

  private setFloatingStatusSearchVisible(visible: boolean): void {
    if (this.statusFloatingSearchVisible === visible) {
      return;
    }
    animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
      this.statusFloatingSearchVisible = visible;
    });
  }

  private setStatusBackToTopVisible(visible: boolean): void {
    if (this.showStatusBackToTop === visible) {
      return;
    }
    animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
      this.showStatusBackToTop = visible;
    });
  }

  private scrollStatusListToTop(): void {
    this.collapseStatusSearch();
    this.setFloatingStatusSearchVisible(false);
    this.setStatusBackToTopVisible(false);
    this.statusUpScrollDistance = 0;
    this.lastStatusScrollY = 0;
    this.pageScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: true });
  }

  private updateFloatingStatusSearchOnScroll(): void {
    try {
      const offset = this.pageScroller.currentOffset();
      const currentY: number = Number(offset.yOffset);
      const deltaY: number = currentY - this.lastStatusScrollY;
      this.lastStatusScrollY = currentY;

      if (currentY < 140) {
        this.statusUpScrollDistance = 0;
        this.setFloatingStatusSearchVisible(false);
        this.setStatusBackToTopVisible(false);
        return;
      }

      this.setStatusBackToTopVisible(currentY >= 360);

      if (deltaY > 0) {
        this.statusUpScrollDistance = 0;
        this.setFloatingStatusSearchVisible(false);
        return;
      }

      if (deltaY < 0) {
        this.statusUpScrollDistance += Math.abs(deltaY);
        if (this.statusUpScrollDistance >= 64) {
          this.setFloatingStatusSearchVisible(true);
        }
      }
    } catch (error) {
      console.error('SearchPage update floating search failed: ' + JSON.stringify(error));
    }
  }

  private handleBackPressed(): boolean {
    if (this.isSearchResultRoute) {
      this.returnToPreviousPage();
      return true;
    }
    if (this.mode.length === 0 && this.showingSearchResults) {
      this.resetSearchResults();
      return true;
    }
    if (this.statusSearchFocused || this.statusSearchExpanded) {
      this.collapseStatusSearch();
      return true;
    }
    if (this.searchFocused || this.searchExpanded) {
      this.collapseSearch();
      return true;
    }
    this.returnToPreviousPage();
    return true;
  }

  private resetSearchResults(): void {
    this.showingSearchResults = false;
    this.keyword = '';
    this.words = [];
    this.filteredWords = [];
    this.dictionaryResult = this.emptyDictionaryResult();
    this.selectedDictionaryDefinitionTab = 'network';
    this.selectedExampleTab = 'bilingual';
    this.audioMessage = '';
    this.message = '';
    this.isEditingSearchHistory = false;
    this.searchFocused = false;
    this.searchExpanded = false;
    this.hideKeyboard();
  }

  aboutToDisappear(): void {
    if (this.homeSearchAnimationTimer >= 0) {
      clearTimeout(this.homeSearchAnimationTimer);
      this.homeSearchAnimationTimer = -1;
    }
    if (this.homeSearchFocusTimer >= 0) {
      clearTimeout(this.homeSearchFocusTimer);
      this.homeSearchFocusTimer = -1;
    }
    if (this.homeModuleFallbackTimer >= 0) {
      clearTimeout(this.homeModuleFallbackTimer);
      this.homeModuleFallbackTimer = -1;
    }
    this.clearHomeModuleContentTimers();
    this.stopDictionaryPronounceAnimation();
    AudioService.stop();
    this.hideKeyboard();
  }

  private emptyDictionaryResult(): DictionaryLookupResult {
    return {
      success: false,
      sourceName: '',
      query: '',
      word: '',
      phonetic: '',
      partOfSpeech: '',
      audioUrl: '',
      definitionPairs: [],
      definitions: [],
      translations: [],
      bilingualExamples: [],
      mediaExamples: [],
      authorityExamples: [],
      networkDefinitions: [],
      specialDefinitions: [],
      englishDefinitions: [],
      phrases: [],
      etymology: '',
      suggestions: [],
      sourceUrl: '',
      message: ''
    };
  }

  private availableDictionaryDefinitionTabs(): DictionaryDefinitionTab[] {
    const tabs: DictionaryDefinitionTab[] = [];
    if (this.dictionaryResult.networkDefinitions.length > 0) {
      tabs.push({ code: 'network', title: '网络释义' });
    }
    if (this.dictionaryResult.specialDefinitions.length > 0) {
      tabs.push({ code: 'special', title: '专业释义' });
    }
    if (this.dictionaryResult.englishDefinitions.length > 0) {
      tabs.push({ code: 'english', title: '英英释义' });
    }
    return tabs;
  }

  private resetDictionaryDefinitionTab(): void {
    const tabs: DictionaryDefinitionTab[] = this.availableDictionaryDefinitionTabs();
    this.selectedDictionaryDefinitionTab = tabs.length > 0 ? tabs[0].code : 'network';
  }

  private availableDictionaryExampleTabs(): DictionaryExampleTab[] {
    const tabs: DictionaryExampleTab[] = [];
    if (this.dictionaryResult.bilingualExamples.length > 0) {
      tabs.push({ code: 'bilingual', title: '双语例句' });
    }
    if (this.dictionaryResult.mediaExamples.length > 0) {
      tabs.push({ code: 'original', title: '原声例句' });
    }
    if (this.dictionaryResult.authorityExamples.length > 0) {
      tabs.push({ code: 'authority', title: '权威例句' });
    }
    return tabs;
  }

  private resetExampleTab(): void {
    const tabs: DictionaryExampleTab[] = this.availableDictionaryExampleTabs();
    this.selectedExampleTab = tabs.length > 0 ? tabs[0].code : 'bilingual';
  }

  private selectedDictionaryExamples(): DictionaryExample[] {
    if (this.selectedExampleTab === 'original') {
      return this.dictionaryResult.mediaExamples;
    }
    if (this.selectedExampleTab === 'authority') {
      return this.dictionaryResult.authorityExamples;
    }
    return this.dictionaryResult.bilingualExamples;
  }

  private isWordStatusPage(): boolean {
    return this.mode === 'unknown' || this.mode === 'mastered' || this.mode === 'unstudied' || this.mode === 'all' ||
      this.mode === 'learnToday';
  }

  private applyWordFilter(): void {
    if (!this.isWordStatusPage()) {
      this.filteredWords = this.sortWordsByAlphabet(this.words);
      return;
    }
    const key: string = this.keyword.trim().toLowerCase();
    if (key.length === 0) {
      this.filteredWords = this.sortWordsByAlphabet(this.words);
      return;
    }

    const result: Word[] = [];
    for (let index: number = 0; index < this.words.length; index++) {
      const item: Word = this.words[index];
      if (item.word.toLowerCase().startsWith(key)) {
        result.push(item);
      }
    }
    this.filteredWords = this.sortWordsByAlphabet(result);
  }

  private sortWordsByAlphabet(source: Word[]): Word[] {
    const sorted: Word[] = source.slice();
    sorted.sort((left: Word, right: Word): number => {
      const result: number = left.word.toLowerCase().localeCompare(right.word.toLowerCase());
      return this.sortAscending ? result : -result;
    });
    return sorted;
  }

  private getDisplayCountText(): string {
    if (!this.isWordStatusPage()) {
      return '共 ' + this.wordCount.toString() + ' 词';
    }
    if (this.keyword.trim().length > 0) {
      return this.filteredWords.length.toString() + ' / ' + this.wordCount.toString() + ' 词';
    }
    return '共 ' + this.wordCount.toString() + ' 词';
  }

  private getModeVisual(): WordModeVisual {
    if (this.mode === 'unknown') {
      return {
        code: 'HARD',
        eyebrow: '需要巩固',
        title: '不认识单词',
        subtitle: '把答错过的词集中摊开，优先处理最容易遗忘的部分。',
        accent: '#E35D5B',
        accentSoft: this.darkMode ? '#3A1F24' : '#FFF0F0',
        gradientStart: this.darkMode ? '#2A151A' : '#FFF4F2',
        gradientEnd: this.darkMode ? '#18222D' : '#F4FBFF',
        metricLabel: '待攻克',
        emptyTitle: '暂时没有不认识的单词',
        emptyHint: '学习或复习时标记“不认识”的词会出现在这里。'
      };
    }
    if (this.mode === 'mastered') {
      return {
        code: 'OK',
        eyebrow: '稳定掌握',
        title: '已掌握单词',
        subtitle: '这里沉淀的是已经通过多轮记忆验证的单词。',
        accent: '#18A06E',
        accentSoft: this.darkMode ? '#123329' : '#EAF9F1',
        gradientStart: this.darkMode ? '#102B25' : '#F0FFF7',
        gradientEnd: this.darkMode ? '#172033' : '#F7F8FF',
        metricLabel: '已掌握',
        emptyTitle: '还没有已掌握单词',
        emptyHint: '持续正确作答后，单词会自动进入已掌握列表。'
      };
    }
    if (this.mode === 'unstudied') {
      return {
        code: 'NEW',
        eyebrow: '还未开始',
        title: '待学习单词',
        subtitle: '新词先排队，保持节奏，不用一次把整本书啃完。',
        accent: '#2F80ED',
        accentSoft: this.darkMode ? '#152A45' : '#EAF3FF',
        gradientStart: this.darkMode ? '#132A45' : '#EDF6FF',
        gradientEnd: this.darkMode ? '#202238' : '#FFF9EF',
        metricLabel: '待开启',
        emptyTitle: '这本词书已经没有待学习单词',
        emptyHint: '可以切到全部单词回看，也可以导入新的词书继续扩展。'
      };
    }
    if (this.mode === 'learnToday') {
      return {
        code: 'NEW',
        eyebrow: '今日新学',
        title: '新学单词',
        subtitle: '这里整理当前周期内已经学习过的新词，方便复盘学习内容。',
        accent: '#2F80ED',
        accentSoft: this.darkMode ? '#152A45' : '#EAF3FF',
        gradientStart: this.darkMode ? '#132A45' : '#EDF6FF',
        gradientEnd: this.darkMode ? '#202238' : '#FFF9EF',
        metricLabel: '已新学',
        emptyTitle: '当前还没有新学单词',
        emptyHint: '完成学习后，新学过的单词会出现在这里。'
      };
    }
    return {
      code: 'ALL',
      eyebrow: '完整词库',
      title: '全部单词',
      subtitle: '按字母顺序浏览整本词书，适合快速查找和回看。',
      accent: '#B7791F',
      accentSoft: this.darkMode ? '#332815' : '#FFF7E6',
      gradientStart: this.darkMode ? '#2F2818' : '#FFF9EA',
      gradientEnd: this.darkMode ? '#172232' : '#F1F7FF',
      metricLabel: '总收录',
      emptyTitle: '当前没有单词',
      emptyHint: '导入词书后，全部单词会显示在这里。'
    };
  }

  private getSortLabel(): string {
    return this.sortAscending ? 'A-Z' : 'Z-A';
  }

  private isTimedStatusPage(): boolean {
    return this.mode === 'unknown' || this.mode === 'mastered' || this.mode === 'learnToday';
  }

  private shouldShowStatusTabs(): boolean {
    return this.mode.length > 0 && this.mode !== 'unstudied' && this.mode !== 'all' && !this.isTimedStatusPage();
  }

  private statusHeaderTopMargin(): number {
    return 12;
  }

  private statusHeaderBorderRadius(): number {
    return 18;
  }

  private shouldShowFloatingStatusSearch(): boolean {
    return this.statusFloatingSearchVisible || (this.statusSearchExpanded && this.lastStatusScrollY >= 140);
  }

  private setStatusSearchFocused(focused: boolean): void {
    if (this.statusSearchFocused === focused) {
      return;
    }
    animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
      this.statusSearchFocused = focused;
      if (focused) {
        this.statusSearchExpanded = true;
      }
    });
  }

  private onSortChange(label: string): void {
    this.sortAscending = label === 'A-Z';
    this.words = this.sortWordsByAlphabet(this.words);
    this.applyWordFilter();
  }

  @Builder
  private buildStatusHeader() {
    Column() {
      Row() {
        Row()
          .width(4)
          .height(44)
          .backgroundColor(this.getModeVisual().accent)
          .borderRadius(2)

        Column() {
          Text(this.getModeVisual().metricLabel)
            .fontSize(11)
            .fontColor(this.darkMode ? '#94A3B8' : '#6B7280')
          Text(this.getDisplayCountText())
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.darkMode ? '#F8FAFC' : '#111827')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 10 })

        if (this.mode === 'unknown' && this.wordCount > 0) {
          Row() {
            Text('重新学习')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
          }
          .height(40)
          .padding({ left: 16, right: 16 })
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .backgroundColor(this.getModeVisual().accent)
          .borderRadius(12)
          .onClick(() => {
            this.startUnknownStudy();
          })
        } else {
          Blank()
            .width(1)
        }
      }
      .width('100%')
      .height(64)
      .padding({ left: 12, right: 12 })
      .alignItems(VerticalAlign.Center)
      .margin({ top: this.statusHeaderTopMargin() })
      .backgroundColor(this.darkMode ? '#111827' : '#FFFFFF')
      .borderRadius(this.statusHeaderBorderRadius())
      .border({ width: 1, color: this.darkMode ? '#243044' : '#E5EDF6' })
      .shadow({ radius: 10, color: 'rgba(15, 23, 42, 0.05)', offsetY: 4 })
    }
    .width('100%')
    .id(this.STATUS_HEADER_TRANSITION_ID)
    .opacity(this.getHomeModuleContentOpacity(1))
    .translate({ y: this.getHomeModuleContentOffset(1) })
    .onAreaChange((): void => {
      this.beginHomeModuleEnterTransition();
    })
  }

  @Builder
  private buildStatusTabs() {
    if (this.shouldShowStatusTabs()) {
      Row() {
        ForEach(this.wordTimeTabs, (tab: string) => {
          Text(tab)
            .fontSize(13)
            .fontWeight(this.wordTimeTab === tab ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.wordTimeTab === tab ? Color.White : (this.darkMode ? '#94A3B8' : '#64748B'))
            .padding({ top: 6, bottom: 6 })
            .backgroundColor(this.wordTimeTab === tab ? this.getModeVisual().accent : Color.Transparent)
            .borderRadius(10)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              this.onWordTimeTabChange(tab);
            })
        }, (tab: string) => tab)
      }
      .width('100%')
      .padding(3)
      .backgroundColor(this.darkMode ? '#111827' : '#EEF4FA')
      .borderRadius(12)
      .margin({ top: 10 })
      .opacity(this.getHomeModuleContentOpacity(2))
      .translate({ y: this.getHomeModuleContentOffset(2) })
    }
  }

  @Builder
  private buildStatusSearchBar() {
    Row() {
      Search({ value: this.keyword, placeholder: '在当前列表中筛选单词、音标或释义' })
        .height(this.statusSearchExpanded ? 48 : 42)
        .layoutWeight(1)
        .backgroundColor(this.darkMode ? '#111827' : '#FFFFFF')
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .placeholderColor(ThemeColor.get(this.darkMode).textSecondary)
        .border({ width: 1, color: this.darkMode ? '#2B3546' : '#DCE6F1' })
        .padding({ left: 6, right: 14 })
        .borderRadius(12)
        .onFocus(() => {
          this.setStatusSearchFocused(true);
        })
        .onBlur(() => {
          this.setStatusSearchFocused(false);
        })
        .onChange((value: string) => {
          this.keyword = value;
          this.applyWordFilter();
        })

      if (!this.statusSearchExpanded) {
        Select(['A-Z', 'Z-A'].map((label: string): SelectOption => ({
          value: label
        })))
        .selected(this.sortAscending ? 0 : 1)
        .value(this.getSortLabel())
        .height(42)
        .padding({ left: 10, right: 10 })
        .backgroundColor(this.getModeVisual().accentSoft)
        .borderRadius(12)
        .font({
          size: 12,
          weight: FontWeight.Medium
        })
        .fontColor(this.darkMode ? '#CBD5E1' : '#4B5563')
        .selectedOptionFont({
          size: 16,
          weight: FontWeight.Medium
        })
        .optionFont({
          size: 16,
          weight: FontWeight.Normal
        })
        .onSelect((index: number, value?: string) => {
          this.onSortChange(value ?? (index === 0 ? 'A-Z' : 'Z-A'));
        })
        .margin({ left: 8 })

        if (this.isTimedStatusPage()) {
          Select(this.wordTimeTabs.map((tab: string): SelectOption => ({
            value: tab
          })))
          .selected(this.wordTimeTabs.indexOf(this.wordTimeTab))
          .value(this.wordTimeTab)
          .height(42)
          .padding({ left: 10, right: 10 })
          .backgroundColor(this.getModeVisual().accentSoft)
          .borderRadius(12)
          .font({
            size: 12,
            weight: FontWeight.Medium
          })
          .fontColor(this.darkMode ? '#CBD5E1' : '#4B5563')
          .selectedOptionFont({
            size: 16,
            weight: FontWeight.Medium
          })
          .optionFont({
            size: 16,
            weight: FontWeight.Normal
          })
          .onSelect((index: number, value?: string) => {
            this.onWordTimeTabChange(value ?? this.wordTimeTabs[index]);
          })
          .margin({ left: 8 })
        }
      }
    }
    .width('100%')
    .height(this.statusSearchExpanded ? 64 : 42)
    .alignItems(VerticalAlign.Center)
    .margin({ top: 10 })
    .opacity(this.getHomeModuleContentOpacity(2))
    .translate({ y: this.getHomeModuleContentOffset(2) })
  }

  @Builder
  private buildFloatingStatusSearchBar() {
    Row() {
      Search({ value: this.keyword, placeholder: '在当前列表中筛选单词、音标或释义' })
        .height(42)
        .layoutWeight(1)
        .backgroundColor(this.darkMode ? '#111827' : '#FFFFFF')
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .placeholderColor(ThemeColor.get(this.darkMode).textSecondary)
        .border({ width: 1, color: this.darkMode ? '#2B3546' : '#DCE6F1' })
        .padding({ left: 6, right: 14 })
        .borderRadius(12)
        .onFocus(() => {
          this.setStatusSearchFocused(true);
        })
        .onBlur(() => {
          this.setStatusSearchFocused(false);
        })
        .onChange((value: string) => {
          this.keyword = value;
          this.applyWordFilter();
        })

      if (!this.statusSearchExpanded) {
        Select(['A-Z', 'Z-A'].map((label: string): SelectOption => ({
          value: label
        })))
        .selected(this.sortAscending ? 0 : 1)
        .value(this.getSortLabel())
        .height(42)
        .padding({ left: 10, right: 10 })
        .backgroundColor(this.getModeVisual().accentSoft)
        .borderRadius(12)
        .font({
          size: 12,
          weight: FontWeight.Medium
        })
        .fontColor(this.darkMode ? '#CBD5E1' : '#4B5563')
        .selectedOptionFont({
          size: 16,
          weight: FontWeight.Medium
        })
        .optionFont({
          size: 16,
          weight: FontWeight.Normal
        })
        .onSelect((index: number, value?: string) => {
          this.onSortChange(value ?? (index === 0 ? 'A-Z' : 'Z-A'));
        })
        .margin({ left: 8 })
      }
    }
    .width('100%')
    .height(42)
  }

  @Builder
  private buildStatusBackToTopButton() {
    Row() {
      Image(this.backToTopIcon())
        .width(24)
        .height(24)
        .objectFit(ImageFit.Contain)
    }
    .width(44)
    .height(44)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.darkMode ? '#1F2937' : '#FFFFFF')
    .border({ width: 1, color: this.darkMode ? '#374151' : '#DCE6F1' })
    .borderRadius(22)
    .shadow({
      radius: 10,
      color: this.darkMode ? 'rgba(0, 0, 0, 0.14)' : 'rgba(15, 23, 42, 0.05)',
      offsetY: 4
    })
    .onClick(() => {
      this.scrollStatusListToTop();
    })
  }

  @Builder
  private buildStatusEmpty() {
    Column() {
      Text(this.message.length > 0 && this.wordCount === 0 ? this.message : this.getModeVisual().emptyTitle)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.darkMode ? '#F8FAFC' : '#111827')
        .textAlign(TextAlign.Center)
      Text(this.keyword.trim().length > 0 ? '换个关键词试试，当前列表里没有匹配项。' : this.getModeVisual().emptyHint)
        .fontSize(13)
        .fontColor(ThemeColor.get(this.darkMode).textSecondary)
        .lineHeight(20)
        .textAlign(TextAlign.Center)
        .margin({ top: 8 })
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 42, bottom: 42 })
    .margin({ top: 18 })
    .backgroundColor(this.darkMode ? '#111827' : Color.White)
    .borderRadius(20)
    .border({ width: 1, color: this.darkMode ? '#243044' : '#E5EDF6' })
    .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
  }

  @Builder
  private textSelectionMenu() {
    SelectionMenu({});
  }

  @Builder
  private buildSearchEngineMenu() {
    Menu() {
      MenuItem({ content: '剑桥词典' })
        .contentFont({ size: 16, weight: FontWeight.Normal })
        .onClick(() => {
          this.updateSearchEngine(0);
        })
      MenuItem({ content: '有道词典' })
        .contentFont({ size: 16, weight: FontWeight.Normal })
        .onClick(() => {
          this.updateSearchEngine(1);
        })
    }
  }

  private dictionaryMatchStart(text: string): number {
    const term: string = this.dictionaryHighlightTerm(text);
    if (term.length === 0) {
      return -1;
    }
    return text.toLowerCase().indexOf(term.toLowerCase());
  }

  private dictionaryHighlightTerm(text: string): string {
    if (text.length === 0) {
      return '';
    }
    const candidates: string[] = [];
    const query: string = this.dictionaryResult.query.trim();
    const word: string = this.dictionaryResult.word.trim();
    if (query.length > 0) {
      candidates.push(query);
    }
    if (word.length > 0 && word.toLowerCase() !== query.toLowerCase()) {
      candidates.push(word);
    }
    for (let index = 0; index < this.dictionaryResult.networkDefinitions.length; index++) {
      const term: string = this.dictionaryResult.networkDefinitions[index].term.trim();
      if (term.length > 0 && term.toLowerCase() !== query.toLowerCase() &&
        term.toLowerCase() !== word.toLowerCase()) {
        candidates.push(term);
      }
    }
    const textLower: string = text.toLowerCase();
    for (let index = 0; index < candidates.length; index++) {
      if (textLower.indexOf(candidates[index].toLowerCase()) >= 0) {
        return candidates[index];
      }
    }
    return '';
  }

  private dictionaryHighlightPrefix(text: string): string {
    const start: number = this.dictionaryMatchStart(text);
    return start >= 0 ? text.substring(0, start) : text;
  }

  private dictionaryHighlightValue(text: string): string {
    const start: number = this.dictionaryMatchStart(text);
    const term: string = this.dictionaryHighlightTerm(text);
    return start >= 0 ? text.substring(start, start + term.length) : '';
  }

  private dictionaryHighlightSuffix(text: string): string {
    const start: number = this.dictionaryMatchStart(text);
    const term: string = this.dictionaryHighlightTerm(text);
    return start >= 0 ? text.substring(start + term.length) : '';
  }

  @Builder
  private buildDictionarySectionTitle(title: string) {
    Text(title)
      .fontSize(15)
      .fontWeight(FontWeight.Bold)
      .fontColor(ThemeColor.get(this.darkMode).textPrimary)
      .width('100%')
  }

  @Builder
  private buildHighlightedDictionaryText(text: string, useSecondaryColor: boolean,
    fontSize: number, lineHeight: number) {
    if (this.dictionaryHighlightValue(text).length > 0) {
      Text() {
        Span(this.dictionaryHighlightPrefix(text))
          .fontColor(useSecondaryColor ? ThemeColor.get(this.darkMode).textSecondary :
            ThemeColor.get(this.darkMode).textPrimary)
        Span(this.dictionaryHighlightValue(text))
          .fontColor(ThemeColor.get(this.darkMode).primary)
          .fontWeight(FontWeight.Bold)
        Span(this.dictionaryHighlightSuffix(text))
          .fontColor(useSecondaryColor ? ThemeColor.get(this.darkMode).textSecondary :
            ThemeColor.get(this.darkMode).textPrimary)
      }
      .fontSize(fontSize)
      .lineHeight(lineHeight)
      .width('100%')
      .copyOption(CopyOptions.LocalDevice)
      .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
      .bindSelectionMenu(TextSpanType.TEXT, this.textSelectionMenu, TextResponseType.LONG_PRESS)
    } else {
      Text(text)
        .fontSize(fontSize)
        .fontColor(useSecondaryColor ? ThemeColor.get(this.darkMode).textSecondary :
          ThemeColor.get(this.darkMode).textPrimary)
        .lineHeight(lineHeight)
        .width('100%')
        .copyOption(CopyOptions.LocalDevice)
        .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
        .bindSelectionMenu(TextSpanType.TEXT, this.textSelectionMenu, TextResponseType.LONG_PRESS)
    }
  }

  @Builder
  private buildDictionaryHeadwordText(text: string) {
    Text(text)
      .fontSize(16)
      .fontWeight(FontWeight.Bold)
      .fontColor(ThemeColor.get(this.darkMode).primary)
      .lineHeight(24)
      .copyOption(CopyOptions.LocalDevice)
      .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
      .bindSelectionMenu(TextSpanType.TEXT, this.textSelectionMenu, TextResponseType.LONG_PRESS)
  }

  @Builder
  private buildDictionaryExample(item: DictionaryExample, showTranslation: boolean, sourceLabel: string) {
    Column() {
      Row() {
        Column() {
          this.buildHighlightedDictionaryText(item.sentence, false, 14, 21)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (item.audioUrl && item.audioUrl.length > 0) {
          Image(this.dictionaryPronounceIcon(item.sentence))
            .width(20)
            .height(20)
            .objectFit(ImageFit.Contain)
            .margin({ left: 8, top: 1 })
            .accessibilityText('播放例句发音')
            .onClick(() => {
              this.runDictionaryPronounceAnimation(
                item.sentence, this.playDictionaryTermAudio(item.sentence, item.audioUrl ? item.audioUrl : ''));
            })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      if (showTranslation && item.translation.length > 0) {
        Column() {
          this.buildHighlightedDictionaryText(item.translation, true, 13, 20)
        }
          .width('100%')
          .margin({ top: 3 })
      }

      if (item.source && item.source.length > 0) {
        Column() {
          this.buildHighlightedDictionaryText(sourceLabel + item.source, true, 13, 20)
        }
          .width('100%')
          .margin({ top: showTranslation && item.translation.length > 0 ? 3 : 4 })
      }
    }
    .width('100%')
    .margin({ top: 8 })
  }

  @Builder
  private buildSwitchableDictionaryDefinitions() {
    if (this.availableDictionaryDefinitionTabs().length > 0) {
      Column() {
        Row() {
          ForEach(this.availableDictionaryDefinitionTabs(), (tab: DictionaryDefinitionTab) => {
            Column() {
              Text(tab.title)
                .fontSize(14)
                .fontWeight(this.selectedDictionaryDefinitionTab === tab.code ? FontWeight.Bold : FontWeight.Medium)
                .fontColor(this.selectedDictionaryDefinitionTab === tab.code
                  ? ThemeColor.get(this.darkMode).primary : ThemeColor.get(this.darkMode).textSecondary)
                .lineHeight(20)
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ top: 2, bottom: 6 })

              Divider()
                .strokeWidth(2)
                .color(ThemeColor.get(this.darkMode).primary)
                .width(28)
                .opacity(this.selectedDictionaryDefinitionTab === tab.code ? 1 : 0)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
            .onClick(() => {
              this.selectedDictionaryDefinitionTab = tab.code;
            })
          }, (tab: DictionaryDefinitionTab) => tab.code)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (this.selectedDictionaryDefinitionTab === 'network') {
          ForEach(this.dictionaryResult.networkDefinitions, (item: DictionaryNetworkDefinition) => {
            Row() {
              Column() {
                Text(item.term)
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(ThemeColor.get(this.darkMode).primary)
                  .lineHeight(21)
                  .width('100%')
                  .copyOption(CopyOptions.LocalDevice)
                  .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
                  .bindSelectionMenu(TextSpanType.TEXT, this.textSelectionMenu, TextResponseType.LONG_PRESS)

                if (item.summary.length > 0) {
                  Column() {
                    this.buildHighlightedDictionaryText(item.summary, true, 13, 20)
                  }
                  .width('100%')
                  .margin({ top: 2 })
                }
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
            .margin({ top: 10 })
          }, (item: DictionaryNetworkDefinition) => item.term)
        } else if (this.selectedDictionaryDefinitionTab === 'special') {
          ForEach(this.dictionaryResult.specialDefinitions, (item: DictionarySpecialDefinition) => {
            Column() {
              Text(item.major)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(ThemeColor.get(this.darkMode).primary)
                .width('100%')

              ForEach(item.terms, (term: string) => {
                Column() {
                  this.buildHighlightedDictionaryText('- ' + term, true, 13, 20)
                }
                .width('100%')
                  .margin({ top: 3 })
              }, (term: string) => item.major + '-' + term)
            }
            .width('100%')
            .margin({ top: 10 })
          }, (item: DictionarySpecialDefinition) => item.major)
        } else {
          ForEach(this.dictionaryResult.englishDefinitions, (item: DictionaryEnglishDefinition) => {
            Row() {
              if (item.partOfSpeech.length > 0) {
                Text(item.partOfSpeech)
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(ThemeColor.get(this.darkMode).primary)
                  .width(32)
              }

              Column() {
                this.buildHighlightedDictionaryText(item.definition, false, 13, 20)
              }
                .width('100%')
                .layoutWeight(1)
                .margin({ left: item.partOfSpeech.length > 0 ? 8 : 0 })
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
            .margin({ top: 10 })
          }, (item: DictionaryEnglishDefinition) => item.partOfSpeech + '-' + item.definition)
        }
      }
      .width('100%')
      .padding(18)
      .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
      .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
      .borderRadius(18)
      .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
    }
  }

  @Builder
  private buildDictionaryCard() {
    Column({ space: 12 }) {
      Column() {
      Row() {
        Column() {
          Text(this.searchEngineLabel())
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeColor.get(this.darkMode).primary)
            .padding({ top: 6, right: 12, bottom: 6 })
            .bindMenu(this.buildSearchEngineMenu())

          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            Text(this.dictionaryResult.word)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(ThemeColor.get(this.darkMode).textPrimary)
              .copyOption(CopyOptions.LocalDevice)
              .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
              .bindSelectionMenu(TextSpanType.TEXT, this.textSelectionMenu, TextResponseType.LONG_PRESS)

            if (this.canPlayDictionaryHeadword()) {
              Image(this.dictionaryPronounceIcon(this.dictionaryResult.word))
                .width(20)
                .height(20)
                .objectFit(ImageFit.Contain)
                .margin({ left: 6, top: 4 })
                .accessibilityText('播放 ' + this.dictionaryResult.word + ' 发音')
                .onClick(() => {
                  this.runDictionaryPronounceAnimation(
                    this.dictionaryResult.word,
                    this.playDictionaryTermAudio(this.dictionaryResult.word, this.dictionaryResult.audioUrl));
                })
            }
          }
          .width('100%')
          .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      Row() {
        if (this.dictionaryResult.phonetic.length > 0) {
          Text(this.dictionaryResult.phonetic)
            .fontSize(14)
            .fontColor(ThemeColor.get(this.darkMode).textSecondary)
            .copyOption(CopyOptions.LocalDevice)
            .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
            .bindSelectionMenu(TextSpanType.TEXT, this.textSelectionMenu, TextResponseType.LONG_PRESS)
        }
        if (this.dictionaryResult.partOfSpeech.length > 0) {
          Text(this.dictionaryResult.partOfSpeech)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeColor.get(this.darkMode).primary)
            .margin({ left: this.dictionaryResult.phonetic.length > 0 ? 8 : 0 })
            .copyOption(CopyOptions.LocalDevice)
            .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
            .bindSelectionMenu(TextSpanType.TEXT, this.textSelectionMenu, TextResponseType.LONG_PRESS)
        }
      }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ top: 8 })

      if (this.dictionaryResult.message.length > 0) {
        Text(this.dictionaryResult.message)
          .fontSize(13)
          .fontColor(ThemeColor.get(this.darkMode).textSecondary)
          .width('100%')
          .margin({ top: 8 })
          .copyOption(CopyOptions.LocalDevice)
          .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
          .bindSelectionMenu(TextSpanType.TEXT, this.textSelectionMenu, TextResponseType.LONG_PRESS)
      }

      if (this.dictionaryResult.suggestions.length > 0) {
        Text('相关词：' + this.dictionaryResult.suggestions.join(' / '))
          .fontSize(13)
          .fontColor(ThemeColor.get(this.darkMode).textSecondary)
          .width('100%')
          .margin({ top: 8 })
          .copyOption(CopyOptions.LocalDevice)
          .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
          .bindSelectionMenu(TextSpanType.TEXT, this.textSelectionMenu, TextResponseType.LONG_PRESS)
      }
      }
      .width('100%')
      .padding(18)
      .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
      .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
      .borderRadius(18)
      .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })

      if (this.dictionaryResult.definitionPairs.length > 0) {
        Column() {
        this.buildDictionarySectionTitle('中文释义')

        ForEach(this.dictionaryResult.definitionPairs, (item: DictionaryDefinition) => {
          Column() {
            if (item.translation.length > 0) {
              if (item.pronunciationUrl && item.pronunciationUrl.length > 0) {
                Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
                  this.buildDictionaryHeadwordText(item.translation)

                Image(this.dictionaryPronounceIcon(item.translation))
                  .width(20)
                  .height(20)
                  .objectFit(ImageFit.Contain)
                  .margin({ left: 6, top: 2 })
                  .accessibilityText('播放 ' + item.translation + ' 发音')
                  .onClick(() => {
                    this.runDictionaryPronounceAnimation(
                      item.translation, this.playDictionaryTermAudio(
                        item.translation, item.pronunciationUrl ? item.pronunciationUrl : ''));
                  })
                }
                .width('100%')
              } else {
                this.buildHighlightedDictionaryText('- ' + item.translation, false, 14, 21)
              }
            }

            if (item.definition.length > 0) {
              Column() {
                this.buildHighlightedDictionaryText(item.definition, true, 13, 20)
              }
                .width('100%')
                .margin({ top: item.translation.length > 0 ? 3 : 0 })
            }
          }
          .width('100%')
          .margin({ top: 8 })
        }, (item: DictionaryDefinition) => item.definition + item.translation)
        }
        .width('100%')
        .padding(18)
        .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
        .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
        .borderRadius(18)
        .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
      } else if (this.dictionaryResult.translations.length > 0) {
        Column() {
        this.buildDictionarySectionTitle('中文释义')

        ForEach(this.dictionaryResult.translations, (item: string) => {
          Column() {
            this.buildHighlightedDictionaryText('- ' + item, false, 14, 21)
          }
            .width('100%')
            .margin({ top: 6 })
        }, (item: string) => item)
        }
        .width('100%')
        .padding(18)
        .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
        .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
        .borderRadius(18)
        .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
      }

      this.buildSwitchableDictionaryDefinitions()

      if (this.dictionaryResult.phrases.length > 0) {
        Column() {
        this.buildDictionarySectionTitle('短语')

        ForEach(this.dictionaryResult.phrases, (item: DictionaryPhrase) => {
          Column() {
            Text(item.phrase)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(ThemeColor.get(this.darkMode).primary)
              .width('100%')
              .copyOption(CopyOptions.LocalDevice)
              .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
              .bindSelectionMenu(TextSpanType.TEXT, this.textSelectionMenu, TextResponseType.LONG_PRESS)

            if (item.translation.length > 0) {
              Column() {
                Text(item.translation)
                  .fontSize(13)
                  .fontColor(ThemeColor.get(this.darkMode).textSecondary)
                  .lineHeight(20)
                  .width('100%')
                  .copyOption(CopyOptions.LocalDevice)
                  .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
                  .bindSelectionMenu(TextSpanType.TEXT, this.textSelectionMenu, TextResponseType.LONG_PRESS)
              }
                .width('100%')
                .margin({ top: 2 })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ top: 8 })
        }, (item: DictionaryPhrase) => item.phrase)
        }
        .width('100%')
        .padding(18)
        .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
        .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
        .borderRadius(18)
        .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
      }

      if (this.availableDictionaryExampleTabs().length > 0) {
        Column() {
        Row() {
          ForEach(this.availableDictionaryExampleTabs(), (tab: DictionaryExampleTab) => {
            Column() {
              Text(tab.title)
                .fontSize(14)
                .fontWeight(this.selectedExampleTab === tab.code ? FontWeight.Bold : FontWeight.Medium)
                .fontColor(this.selectedExampleTab === tab.code
                  ? ThemeColor.get(this.darkMode).primary : ThemeColor.get(this.darkMode).textSecondary)
                .lineHeight(20)
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ top: 2, bottom: 6 })

              Divider()
                .strokeWidth(2)
                .color(ThemeColor.get(this.darkMode).primary)
                .width(28)
                .opacity(this.selectedExampleTab === tab.code ? 1 : 0)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
            .onClick(() => {
              this.selectedExampleTab = tab.code;
            })
          }, (tab: DictionaryExampleTab) => tab.code)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        ForEach(this.selectedDictionaryExamples(), (item: DictionaryExample) => {
          this.buildDictionaryExample(
            item,
            this.selectedExampleTab !== 'authority',
            this.selectedExampleTab === 'original' ? '素材来源：' : '来源：')
        }, (item: DictionaryExample) => this.selectedExampleTab + '-' + item.sentence + item.translation)
        }
        .width('100%')
        .padding(18)
        .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
        .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
        .borderRadius(18)
        .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
      }

      if (this.dictionaryResult.etymology.length > 0) {
        Column() {
        this.buildDictionarySectionTitle('词源')

        Column() {
          this.buildHighlightedDictionaryText(this.dictionaryResult.etymology, true, 14, 21)
        }
          .width('100%')
          .margin({ top: 6 })
        }
        .width('100%')
        .padding(18)
        .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
        .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
        .borderRadius(18)
        .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
      }

      if (this.audioMessage.length > 0) {
        Text(this.audioMessage)
          .fontSize(13)
          .fontColor(ThemeColor.get(this.darkMode).danger)
          .width('100%')
          .margin({ top: 10 })
          .copyOption(CopyOptions.LocalDevice)
          .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
          .bindSelectionMenu(TextSpanType.TEXT, this.textSelectionMenu, TextResponseType.LONG_PRESS)
      }
    }
    .width('100%')
  }

  private loadingTitle(): string {
    return this.mode.length === 0 ? '正在搜索单词' : '正在整理单词';
  }

  private loadingDescription(): string {
    return this.mode.length === 0 ? '正在查询词典释义' : '正在读取单词列表';
  }

  @Builder
  private buildSearchHistory() {
    Column() {
      Row() {
        Text('搜索历史')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeColor.get(this.darkMode).textPrimary)
          .layoutWeight(1)

        Text(this.isEditingSearchHistory ? '完成' : '编辑')
          .fontSize(14)
          .fontColor(ThemeColor.get(this.darkMode).primary)
          .padding({ left: 8, top: 6, bottom: 6 })
          .onClick(() => {
            this.toggleSearchHistoryEditing();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        ForEach(this.searchHistory, (item: string) => {
          Row() {
            Chip({
              label: {
                text: item,
                fontSize: 14,
                fontColor: this.isEditingSearchHistory
                  ? ThemeColor.get(this.darkMode).danger
                  : ThemeColor.get(this.darkMode).textPrimary
              },
              size: ChipSize.NORMAL,
              allowClose: false,
              enabled: true,
              backgroundColor: this.isEditingSearchHistory
                ? (this.darkMode ? '#3F1D2B' : '#FEE2E2')
                : (this.darkMode ? '#1E293B' : '#F1F5F9'),
              borderRadius: 14,
              onClicked: (): void => {
                if (this.isEditingSearchHistory) {
                  this.removeSearchHistory(item);
                } else {
                  this.useSearchHistory(item);
                }
              },
              accessibilityDescription: this.isEditingSearchHistory
                ? '删除搜索历史：' + item
                : '使用搜索历史：' + item
            })
          }
          .margin({ right: 8, bottom: 8 })
        }, (item: string) => item)
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .margin({ top: 0, bottom: 2 })
    .opacity(this.searchHistoryOpacity)
    .translate({ y: this.searchHistoryTranslateY })
    .onAppear((): void => {
      this.searchHistoryMounted = true;
      this.revealSearchHistoryAfterHomeTransition();
    })
  }

  @Builder
  private buildSearchLoadingOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
      }
      .width('100%')
      .height('100%')
      .backgroundColor(ThemeColor.get(this.darkMode).background)
      .opacity(0.8)

      Column({ space: 12 }) {
        LoadingProgress()
          .width(48)
          .height(48)
          .color(ThemeColor.get(this.darkMode).primary)

        Text(this.loadingTitle())
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeColor.get(this.darkMode).textPrimary)
          .textAlign(TextAlign.Center)

        Text(this.loadingDescription())
          .fontSize(14)
          .lineHeight(22)
          .fontColor(ThemeColor.get(this.darkMode).textSecondary)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding({ left: 24, right: 24 })
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Block)
    .accessibilityGroup(true)
    .accessibilityText(this.loadingTitle() + '。' + this.loadingDescription())
    .zIndex(200)
  }

  pageTransition() {
    if (this.hasHomeSearchTransition() || this.hasHomeModuleTransition()) {
      PageTransitionEnter({ duration: 0, type: RouteType.Push });
      PageTransitionExit({ duration: 240, curve: Curve.EaseIn, type: RouteType.Pop }).opacity(0);
    } else {
      PageTransitionEnter({ duration: 180, curve: Curve.EaseOut }).opacity(0)
      PageTransitionExit({ duration: 140, curve: Curve.EaseIn }).opacity(0)
    }
  }

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Top }) {
      if (this.isWordStatusPage()) {
      List({ scroller: this.pageScroller, space: 12 }) {
        ListItem() {
    Column() {
            if (!this.statusSearchExpanded) {
              this.buildStatusHeader()
              if (this.shouldShowStatusTabs()) {
                this.buildStatusTabs()
              }
            }
            this.buildStatusSearchBar()
          }
          .width('100%')
        }

        if (!this.isLoading) {
          if (this.filteredWords.length === 0) {
            ListItem() {
              this.buildStatusEmpty()
            }
            .opacity(this.getHomeModuleContentOpacity(3))
            .translate({ y: this.getHomeModuleContentOffset(3) })
          } else {
            ForEach(this.filteredWords, (item: Word, index?: number) => {
              ListItem() {
                WordListItem({
                  word: item,
                  cardBackground: this.darkMode ? '#1B2638' : '#FFFFFF',
                  textPrimary: ThemeColor.get(this.darkMode).textPrimary,
                  textSecondary: ThemeColor.get(this.darkMode).textSecondary,
                  darkMode: this.darkMode,
                  showPartOfSpeech: false,
                  onItemClick: () => {
                    this.openWordDetail(item.id);
                  }
                })
              }
              .opacity(this.getHomeModuleContentOpacity((index ?? 0) + 3))
              .translate({ y: this.getHomeModuleContentOffset((index ?? 0) + 3) })
            }, (item: Word) => item.id.toString())
          }
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 20, right: 20, top: 0, bottom: 0 })
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .enableScrollInteraction(true)
      .friction(0.75)
      .onScroll((xOffset: number, yOffset: number) => {
        this.capturePageScrollPosition();
        this.collapseStatusSearch();
        this.updateFloatingStatusSearchOnScroll();
      })
      .onTouch((event: TouchEvent): void => {
        if (event.type === TouchType.Move) {
          this.collapseStatusSearch();
        }
      })
      .scrollBar(BarState.Auto)
      .backgroundColor(ThemeColor.get(this.darkMode).background)
    } else {
      List({ scroller: this.pageScroller, space: 6 }) {

        if (this.mode.length > 0 && this.mode !== 'unstudied' && this.mode !== 'all') {
          ListItem() {
            Row() {
              ForEach(this.wordTimeTabs, (tab: string) => {
                Text(tab)
                  .fontSize(13)
                  .fontWeight(this.wordTimeTab === tab ? FontWeight.Medium : FontWeight.Normal)
                  .fontColor(this.wordTimeTab === tab ? Color.White : (this.darkMode ? '#94A3B8' : '#8C8CA8'))
                  .padding({ top: 6, bottom: 6 })
                  .backgroundColor(this.wordTimeTab === tab ? '#8B5CF6' : Color.Transparent)
                  .borderRadius(12)
                  .layoutWeight(1)
                  .textAlign(TextAlign.Center)
                  .onClick(() => {
                    this.onWordTimeTabChange(tab);
                  })
              }, (tab: string) => tab)
            }
            .width('100%')
            .padding(3)
            .backgroundColor(this.darkMode ? '#1E293B' : '#F0EDF6')
            .borderRadius(16)
            .margin({ top: 18 })
          }
        }

        ListItem() {
          Column() {
            Search({ value: this.keyword, placeholder: '搜索单词或释义' })
              .height(48)
              .width('100%')
              .defaultFocus(this.autoFocusSearch && this.mode.length === 0 && !this.hasHomeSearchTransition())
              .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
              .fontColor(ThemeColor.get(this.darkMode).textPrimary)
              .placeholderColor(ThemeColor.get(this.darkMode).textSecondary)
              .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
              .padding({ left: 8, right: 8 })
              .borderRadius(16)
              .searchButton('搜索', {
                fontSize: 14,
                fontColor: '#8B5CF6'
              })
              .onFocus(() => {
                this.setSearchFocused(true);
              })
              .onBlur(() => {
                this.setSearchFocused(false);
              })
              .onChange((value: string) => {
                this.keyword = value;
              })
              .onSubmit(() => {
                this.search();
              })
              .id(this.MAIN_SEARCH_INPUT_ID)
          }
          .id(this.MAIN_SEARCH_TRANSITION_ID)
          .translate({ x: this.mainSearchTranslateX, y: this.mainSearchTranslateY })
          .scale({ x: this.mainSearchScaleX, y: this.mainSearchScaleY })
          .opacity(this.mainSearchOpacity)
          .onAreaChange((): void => {
            this.beginHomeSearchEnterTransition();
          })
          .width('100%')
          .margin({ top: 0 })
        }

        if (this.mode.length === 0 && this.searchHistory.length > 0 &&
            !this.showingSearchResults && this.keyword.trim().length === 0) {
          ListItem() {
            this.buildSearchHistory()
          }
        }

        if (!this.isLoading) {
          if (this.words.length === 0 && !this.dictionaryResult.success && this.message.length > 0) {
            ListItem() {
              Column() {
                Text(this.message)
                  .fontSize(16)
                  .fontColor(ThemeColor.get(this.darkMode).textSecondary)
                  .margin({ top: 40 })
              }
              .width('100%')
            }
          } else {
            if (this.dictionaryResult.success) {
              ListItem() {
                this.buildDictionaryCard()
              }
            }

            ForEach(this.words, (item: Word) => {
              ListItem() {
                Column() {
                  WordListItem({
                    word: item,
                    cardBackground: this.darkMode ? '#1B2638' : ThemeColor.get(this.darkMode).cardBackground,
                    textPrimary: ThemeColor.get(this.darkMode).textPrimary,
                    textSecondary: ThemeColor.get(this.darkMode).textSecondary,
                    darkMode: this.darkMode,
                    onItemClick: () => {
                      this.openWordDetail(item.id);
                    }
                  })
                }
                .width('100%')
                .margin({ top: this.MAIN_SEARCH_LOCAL_WORD_CARD_MARGIN })
              }
            }, (item: Word) => item.id.toString())

            if (this.showingSearchResults && (this.dictionaryResult.success || this.words.length > 0)) {
              ListItem() {
                Column().width('100%').height(this.MAIN_SEARCH_BOTTOM_SPACER)
              }
              .width('100%')
              .reuseId('search-result-bottom-spacer')
            }
          }
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 20, right: 20, top: 0, bottom: 0 })
      .contentStartOffset(-this.MAIN_SEARCH_CONTENT_OVERLAP)
      .contentEndOffset(this.MAIN_SEARCH_CONTENT_OVERLAP)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .enableScrollInteraction(true)
      .friction(0.75)
      .onScroll((xOffset: number, yOffset: number) => {
        this.capturePageScrollPosition();
        this.collapseSearch();
      })
      .onTouch((event: TouchEvent): void => {
        if (event.type === TouchType.Move) {
          this.collapseSearch();
        }
      })
      .scrollBar(BarState.Auto)
      .backgroundColor(ThemeColor.get(this.darkMode).background)
    }
      if (this.isWordStatusPage() && this.shouldShowFloatingStatusSearch()) {
        Column() {
          this.buildFloatingStatusSearchBar()
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 8, bottom: 8 })
        .backgroundColor(ThemeColor.get(this.darkMode).background)
      }
      if (this.isWordStatusPage() && this.showStatusBackToTop) {
        Stack({ alignContent: Alignment.BottomEnd }) {
          Row() {
            this.buildStatusBackToTopButton()
          }
          .width(44)
          .height(44)
          .margin({ right: 20, bottom: 84 })
          .hitTestBehavior(HitTestMode.Default)
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.Transparent)
        .zIndex(101)
      }
      if (this.isLoading) {
        this.buildSearchLoadingOverlay()
      }
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .titleBar(createHdsSubPageTitleBarOptions(this.isWordStatusPage() ? this.getModeVisual().title : this.title,
      this.darkMode, this.materialEffectMode, () => {
        this.handleBackPressed();
      }))
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .onBackPressed(() => {
      if (this.isSearchResultRoute) {
        return false;
      }
      return this.handleBackPressed();
    })
    .bindToScrollable([this.pageScroller])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor(ThemeColor.get(this.darkMode).background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}

