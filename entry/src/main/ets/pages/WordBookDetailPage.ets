import { common } from '@kit.AbilityKit';
import router from '@ohos.router';
import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { SUB_PAGE_CONTENT_OVERLAP } from '../components/HdsSubPageLayout';
import { createHdsSubPageTitleBarOptions } from '../components/HdsSubPageTitleBarOptions';
import { WordListItem } from '../components/WordListItem';
import { Word } from '../model/Word';
import { WordBook } from '../model/WordBook';
import { DatabaseService } from '../services/DatabaseService';
import { PreferencesService } from '../services/PreferencesService';
import { WordBookService } from '../services/WordBookService';
import { WordService } from '../services/WordService';
import { Constants } from '../utils/Constants';
import { ThemeColor } from '../utils/ThemeColor';

interface WordBookDetailParams {
  bookId?: number;
}

@Entry
@Component
struct WordBookDetailPage {
  @State private isLoading: boolean = true;
  @StorageLink('resolvedDarkMode') darkMode: boolean = false;
  @StorageLink('materialEffectMode') materialEffectMode: number = Constants.DEFAULT_MATERIAL_EFFECT_MODE;
  @State private bookId: number = 0;
  @State private book: WordBook = {
    id: 0,
    name: '词书详情',
    description: '',
    totalCount: 0,
    createdAt: 0
  };
  @State private words: Word[] = [];
  @State private visibleWords: Word[] = [];
  @State private keyword: string = '';
  @State private message: string = '';
  private pageScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.initPage();
  }

  private async initPage(): Promise<void> {
    this.isLoading = true;
    try {
      const context = getContext(this) as common.Context;
      await DatabaseService.init(context);
      await PreferencesService.init(context);
      

      const params: WordBookDetailParams = router.getParams() as WordBookDetailParams;
      this.bookId = params && params.bookId ? Number(params.bookId) : 0;
      if (this.bookId <= 0) {
        this.message = '词书参数错误';
        return;
      }

      const currentBook: WordBook | null = await WordBookService.getBookById(this.bookId);
      if (!currentBook) {
        this.message = '词书不存在';
        return;
      }

      this.book = currentBook;
      this.words = await WordService.getWordsByBookId(this.bookId);
      this.applyFilter();
      this.message = this.words.length === 0 ? '该词书暂无单词' : '';
    } catch (error) {
      console.error('WordBookDetailPage init failed: ' + JSON.stringify(error));
      this.message = '词书详情加载失败';
    } finally {
      this.isLoading = false;
    }
  }

  private applyFilter(): void {
    const key: string = this.keyword.trim().toLowerCase();
    if (key.length === 0) {
      this.visibleWords = this.words;
      return;
    }

    const result: Word[] = [];
    for (let index: number = 0; index < this.words.length; index++) {
      const item: Word = this.words[index];
      const text: string = (item.word + ' ' + item.translation).toLowerCase();
      if (text.indexOf(key) >= 0) {
        result.push(item);
      }
    }
    this.visibleWords = result;
  }

  private openWordDetail(wordId: number): void {
    router.pushUrl({
      url: 'pages/WordDetailPage',
      params: {
        wordId: wordId
      }
    });
  }

  private startStudy(): void {
    router.pushUrl({
      url: 'pages/StudyPage',
      params: {
        bookId: this.bookId
      }
    });
  }

  private startReview(): void {
    router.pushUrl({
      url: 'pages/ReviewPage',
      params: {
        bookId: this.bookId
      }
    });
  }

  pageTransition() {
    PageTransitionEnter({ duration: 180, curve: Curve.EaseOut }).opacity(0)
    PageTransitionExit({ duration: 140, curve: Curve.EaseIn }).opacity(0)
  }

  build() {
    HdsNavDestination() {
      Scroll(this.pageScroller) {
        Column() {
      if (this.isLoading) {
        Text('正在加载词书...')
          .fontSize(16)
          .fontColor(ThemeColor.get(this.darkMode).textSecondary)
          .margin({ top: 16 })
      } else {
        Column() {
          Text(this.book.name)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeColor.get(this.darkMode).textPrimary)
            .width('100%')
          Text(this.book.description.length > 0 ? this.book.description : '暂无描述')
            .fontSize(14)
            .fontColor(ThemeColor.get(this.darkMode).textSecondary)
            .width('100%')
            .margin({ top: 8 })
          Text(this.words.length.toString() + ' 个单词')
            .fontSize(13)
            .fontColor(ThemeColor.get(this.darkMode).primary)
            .width('100%')
            .margin({ top: 8 })

          Row() {
            Button('开始学习')
              .width('48%')
              .buttonStyle(ButtonStyleMode.EMPHASIZED)
              .controlSize(ControlSize.NORMAL)
              .role(ButtonRole.NORMAL)
              .onClick(() => {
                this.startStudy();
              })

            Button('开始复习')
              .width('48%')
              .buttonStyle(ButtonStyleMode.NORMAL)
              .controlSize(ControlSize.NORMAL)
              .role(ButtonRole.NORMAL)
              .onClick(() => {
                this.startReview();
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .margin({ top: 16 })
        }
        .width('100%')
        .padding(18)
        .margin({ top: 12 })
        .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
        .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
        .borderRadius(18)
        .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })

        Search({ value: this.keyword, placeholder: '搜索当前词书单词或释义' })
          .width('100%')
          .height(48)
          .fontColor(ThemeColor.get(this.darkMode).textPrimary)
          .placeholderColor(ThemeColor.get(this.darkMode).textSecondary)
          .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
          .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
          .borderRadius(16)
          .padding({ left: 16, right: 16 })
          .margin({ top: 16 })
          .onChange((value: string) => {
            this.keyword = value;
            this.applyFilter();
          })

        if (this.visibleWords.length === 0) {
          Text(this.message.length > 0 ? this.message : '没有匹配的单词')
            .fontSize(16)
            .fontColor(ThemeColor.get(this.darkMode).textSecondary)
            .margin({ top: 40 })
        } else {
          ForEach(this.visibleWords, (item: Word) => {
            WordListItem({
              word: item,
              cardBackground: this.darkMode ? '#1B2638' : ThemeColor.get(this.darkMode).cardBackground,
              textPrimary: ThemeColor.get(this.darkMode).textPrimary,
              textSecondary: ThemeColor.get(this.darkMode).textSecondary,
              onItemClick: () => {
                this.openWordDetail(item.id);
              }
            })
            .margin({ top: 14 })
          }, (item: Word) => item.id.toString())
        }
      }
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 0, bottom: 40 + SUB_PAGE_CONTENT_OVERLAP })
        .translate({ y: -SUB_PAGE_CONTENT_OVERLAP })
      }
      .width('100%')
      .height('100%')
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .enableScrollInteraction(true)
      .friction(0.75)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .titleBar(createHdsSubPageTitleBarOptions(this.book.name, this.darkMode, this.materialEffectMode))
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

