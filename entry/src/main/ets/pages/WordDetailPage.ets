import { common } from '@kit.AbilityKit';
import router from '@ohos.router';
import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { SUB_PAGE_CONTENT_OVERLAP } from '../components/HdsSubPageLayout';
import { createHdsSubPageTitleBarOptions } from '../components/HdsSubPageTitleBarOptions';
import { DateUtil } from '../utils/DateUtil';
import { DatabaseService } from '../services/DatabaseService';
import { AiService } from '../services/AiService';
import { AudioService } from '../services/AudioService';
import { PreferencesService } from '../services/PreferencesService';
import { StudyRecordService } from '../services/StudyRecordService';
import { WordService } from '../services/WordService';
import { StudyRecord } from '../model/StudyRecord';
import { Word } from '../model/Word';
import { Constants } from '../utils/Constants';
import { ThemeColor } from '../utils/ThemeColor';

interface WordDetailParams {
  wordId?: number | string;
}

interface ExamplePair {
  english: string;
  chinese: string;
  part?: string;
}

interface WordVariant {
  part: string;
  value: string;
}

@Entry
@Component
struct WordDetailPage {
  @State private isLoading: boolean = true;
  @State private isAiLoading: boolean = false;
  @State private wordId: number = 0;
  @State private wordText: string = '';
  @State private phonetic: string = '';
  @State private partOfSpeech: string = '';
  @State private pronunciationUrl: string = '';
  @State private translation: string = '';
  @State private example: string = '';
  @State private difficulty: number = 1;
  @State private correctCount: number = 0;
  @State private wrongCount: number = 0;
  @State private intervalDays: number = 1;
  @State private nextReviewText: string = '暂无';
  @State private masteredText: string = '否';
  @State private message: string = '';
  @State private aiText: string = '';
  @State private audioMessage: string = '';
  @State private pronounceFrame: number = 2;
  @StorageLink('resolvedDarkMode') darkMode: boolean = false;
  @StorageLink('materialEffectMode') materialEffectMode: number = Constants.DEFAULT_MATERIAL_EFFECT_MODE;
  private pageScroller: Scroller = new Scroller();
  private readonly DETAIL_CARD_SPACING: number = 18;
  private readonly DETAIL_BOTTOM_SPACING: number = 64;
  private pronounceAnimationTimer: number = -1;
  private pronounceAnimationId: number = 0;

  aboutToAppear(): void {
    this.loadDetail();
  }

  aboutToDisappear(): void {
    this.stopPronounceAnimation();
  }

  private async loadDetail(): Promise<void> {
    this.isLoading = true;
    try {
      const context = getContext(this) as common.Context;
      await DatabaseService.init(context);
      await PreferencesService.init(context);
      
      const params: WordDetailParams = router.getParams() as WordDetailParams;
      this.wordId = params && params.wordId ? Number(params.wordId) : 0;
      if (this.wordId <= 0 || Number.isNaN(this.wordId)) {
        this.message = 'wordId 参数为空';
        return;
      }

      const word: Word | null = await WordService.getWordById(this.wordId);
      if (!word) {
        this.message = '未找到单词';
        return;
      }

      this.wordText = word.word;
      this.phonetic = word.phonetic;
      this.partOfSpeech = word.partOfSpeech ? word.partOfSpeech : '';
      this.pronunciationUrl = word.pronunciationUrl ? word.pronunciationUrl : '';
      this.translation = word.translation;
      this.example = word.example;
      this.difficulty = word.difficulty;

      const record: StudyRecord | null = await StudyRecordService.getRecordByWordId(this.wordId);
      if (record) {
        this.correctCount = record.correctCount;
        this.wrongCount = record.wrongCount;
        this.intervalDays = record.intervalDays;
        this.nextReviewText = DateUtil.formatTimestamp(record.nextReviewTime);
        this.masteredText = record.mastered === 1 ? '是' : '否';
      } else {
        this.correctCount = 0;
        this.wrongCount = 0;
        this.intervalDays = 1;
        this.nextReviewText = '暂无';
        this.masteredText = '否';
      }
    } catch (error) {
      console.error('loadDetail failed: ' + JSON.stringify(error));
      this.message = '加载详情失败';
    } finally {
      this.isLoading = false;
    }
  }

  private async explainByAi(): Promise<void> {
    this.isAiLoading = true;
    this.aiText = '正在请求 AI 解释...';
    try {
      this.aiText = await AiService.generateWordExplanation(this.wordText);
    } catch (error) {
      console.error('explainByAi failed: ' + JSON.stringify(error));
      this.aiText = 'AI 解释失败：' + JSON.stringify(error);
    } finally {
      this.isAiLoading = false;
    }
  }

  private async playPronunciation(): Promise<void> {
    const context = getContext(this) as common.Context;
    this.audioMessage = await AudioService.playWord(this.wordText, this.pronunciationUrl, context);
  }

  private pronounceIcon(): Resource {
    if (this.pronounceFrame === 0) {
      return this.darkMode ? $r('app.media.pronounce_dark_frame1') : $r('app.media.pronounce_light_frame1');
    }
    if (this.pronounceFrame === 1) {
      return this.darkMode ? $r('app.media.pronounce_dark_frame2') : $r('app.media.pronounce_light_frame2');
    }
    return this.darkMode ? $r('app.media.pronounce_dark') : $r('app.media.pronounce_light');
  }

  private startPronounceAnimation(): number {
    this.stopPronounceAnimation(false);
    const animationId: number = this.pronounceAnimationId + 1;
    this.pronounceAnimationId = animationId;
    this.pronounceFrame = 0;
    this.pronounceAnimationTimer = setInterval(() => {
      this.pronounceFrame = (this.pronounceFrame + 1) % 3;
    }, Constants.PRONUNCIATION_ANIMATION_FRAME_INTERVAL_MS);
    return animationId;
  }

  private stopPronounceAnimation(resetFrame: boolean = true): void {
    if (this.pronounceAnimationTimer >= 0) {
      clearInterval(this.pronounceAnimationTimer);
      this.pronounceAnimationTimer = -1;
    }
    if (resetFrame) {
      this.pronounceFrame = 2;
    }
  }

  private async runPronounceAnimation(playTask: Promise<void>): Promise<void> {
    const animationId: number = this.startPronounceAnimation();
    try {
      await playTask;
    } finally {
      if (this.pronounceAnimationId === animationId) {
        this.stopPronounceAnimation();
      }
    }
  }

  private goBack(): void {
    router.back();
  }

  private displayPartOfSpeech(): string {
    if (this.partOfSpeech.trim().length > 0) {
      return this.partOfSpeech.trim();
    }
    const match = this.translation.match(/^([a-zA-Z]+)\.\s*/);
    return match && match.length > 1 ? match[1] : '';
  }

  private splitItems(value: string, limit: number): string[] {
    const result: string[] = [];
    const normalized: string = value.replace(/\r/g, '\n').replace(/；/g, ';').replace(/。/g, '.');
    const rawItems: string[] = normalized.split(/\n+|;+/);
    for (let index: number = 0; index < rawItems.length && result.length < limit; index++) {
      const item: string = rawItems[index].trim();
      if (item.length > 0) {
        result.push(item);
      }
    }
    return result;
  }

  private examplePairs(): ExamplePair[] {
    const result: ExamplePair[] = [];
    const groups: string[] = this.example.replace(/\r/g, '\n').split(/\n\s*\n+/);
    for (let index: number = 0; index < groups.length && result.length < 4; index++) {
      const lines: string[] = groups[index].split('\n');
      let english: string = '';
      let chinese: string = '';
      for (let lineIndex: number = 0; lineIndex < lines.length; lineIndex++) {
        const line: string = lines[lineIndex].trim();
        if (line.length === 0) {
          continue;
        }
        if (english.length === 0) {
          english = line;
        } else if (chinese.length === 0) {
          chinese = line;
        } else {
          chinese = chinese + '\n' + line;
        }
      }
      if (english.length > 0 || chinese.length > 0) {
        result.push({ english: english, chinese: chinese });
      }
    }
    if (result.length === 0) {
      const fallbackItems: string[] = this.splitItems(this.example, 4);
      for (let index: number = 0; index < fallbackItems.length; index++) {
        result.push({ english: fallbackItems[index], chinese: '' });
      }
    }
    return result;
  }

  private partExamples(): ExamplePair[] {
    const parts: string[] = this.splitItems(this.displayPartOfSpeech().replace(/\//g, ';'), 4);
    const examples: ExamplePair[] = this.examplePairs();
    const result: ExamplePair[] = [];
    for (let index: number = 0; index < parts.length && index < examples.length; index++) {
      let existed: boolean = false;
      for (let resultIndex: number = 0; resultIndex < result.length; resultIndex++) {
        if (result[resultIndex].part === parts[index]) {
          existed = true;
          break;
        }
      }
      if (existed) {
        continue;
      }
      result.push({
        english: examples[index].english,
        chinese: examples[index].chinese,
        part: parts[index]
      });
    }
    return result.length > 1 ? result : [];
  }

  private variantPartOfSpeech(): string {
    const raw: string = this.displayPartOfSpeech().trim().toLowerCase();
    if (raw.length === 0) {
      return '';
    }
    if (raw.indexOf('verb') >= 0 || /(^|[\s/,;])v\.?($|[\s/,;])/.test(raw)) {
      return 'v';
    }
    if (raw.indexOf('noun') >= 0 || /(^|[\s/,;])n\.?($|[\s/,;])/.test(raw)) {
      return 'n';
    }
    if (raw.indexOf('adjective') >= 0 || raw.indexOf('adj') >= 0) {
      return 'adj';
    }
    if (raw.indexOf('adverb') >= 0 || raw.indexOf('adv') >= 0) {
      return 'adv';
    }
    const firstPart: string = raw.split(/[\s/,;]+/)[0].replace(/\.+$/, '');
    return firstPart;
  }

  private variants(): WordVariant[] {
    const safeWord: string = this.wordText.trim().toLowerCase();
    if (safeWord.length === 0) {
      return [];
    }
    const part: string = this.variantPartOfSpeech();
    const result: WordVariant[] = [];
    if (safeWord.endsWith('y') && safeWord.length > 1) {
      result.push({ part: part, value: safeWord.substring(0, safeWord.length - 1) + 'ies' });
    } else if (safeWord.endsWith('s') || safeWord.endsWith('x') || safeWord.endsWith('ch') || safeWord.endsWith('sh')) {
      result.push({ part: part, value: safeWord + 'es' });
    } else {
      result.push({ part: part, value: safeWord + 's' });
    }
    if (safeWord.endsWith('e')) {
      result.push({ part: part, value: safeWord.substring(0, safeWord.length - 1) + 'ing' });
      result.push({ part: part, value: safeWord + 'd' });
    } else {
      result.push({ part: part, value: safeWord + 'ing' });
      result.push({ part: part, value: safeWord + 'ed' });
    }
    return result;
  }

  private exampleMatchStart(text: string): number {
    const safeWord: string = this.wordText.trim().toLowerCase();
    if (safeWord.length === 0 || text.length === 0) {
      return -1;
    }
    return text.toLowerCase().indexOf(safeWord);
  }

  private examplePrefix(text: string): string {
    const start: number = this.exampleMatchStart(text);
    return start >= 0 ? text.substring(0, start) : text;
  }

  private exampleHighlight(text: string): string {
    const start: number = this.exampleMatchStart(text);
    return start >= 0 ? text.substring(start, start + this.wordText.trim().length) : '';
  }

  private exampleSuffix(text: string): string {
    const start: number = this.exampleMatchStart(text);
    return start >= 0 ? text.substring(start + this.wordText.trim().length) : '';
  }

  @Builder
  private sectionTitle(title: string) {
    Text(title)
      .fontSize(15)
      .fontWeight(FontWeight.Bold)
      .fontColor(ThemeColor.get(this.darkMode).textPrimary)
      .width('100%')
  }

  @Builder
  private emptyText(text: string) {
    Text(text)
      .fontSize(14)
      .fontColor(ThemeColor.get(this.darkMode).textSecondary)
      .lineHeight(21)
      .width('100%')
      .margin({ top: 10 })
  }

  @Builder
  private highlightedExample(text: string) {
    if (this.exampleHighlight(text).length > 0) {
      Text() {
        Span(this.examplePrefix(text))
          .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        Span(this.exampleHighlight(text))
          .fontColor(ThemeColor.get(this.darkMode).primary)
          .fontWeight(FontWeight.Bold)
        Span(this.exampleSuffix(text))
          .fontColor(ThemeColor.get(this.darkMode).textPrimary)
      }
      .fontSize(14)
      .lineHeight(22)
      .width('100%')
    } else {
      Text(text)
        .fontSize(14)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .lineHeight(22)
        .width('100%')
    }
  }

  @Builder
  private variantChip(item: WordVariant) {
    Row() {
      if (item.part.length > 0) {
        Text(item.part + '.')
          .fontSize(12)
          .fontColor(ThemeColor.get(this.darkMode).textSecondary)
          .fontWeight(FontWeight.Medium)
      }
      Text(item.value)
        .fontSize(13)
        .fontColor(ThemeColor.get(this.darkMode).primary)
        .fontWeight(FontWeight.Medium)
    }
    .alignItems(VerticalAlign.Center)
    .padding({ left: 9, right: 9, top: 6, bottom: 6 })
    .backgroundColor(this.darkMode ? '#17233A' : '#F1F7FF')
    .borderRadius(14)
    .margin({ right: 6, bottom: 6 })
  }

  pageTransition() {
    PageTransitionEnter({ duration: 180, curve: Curve.EaseOut }).opacity(0)
    PageTransitionExit({ duration: 140, curve: Curve.EaseIn }).opacity(0)
  }

  build() {
    HdsNavDestination() {
      List({ scroller: this.pageScroller }) {
        ListItem() {
          Column() {

          if (this.isLoading) {
            Text('正在加载详情...')
              .fontSize(16)
              .fontColor(ThemeColor.get(this.darkMode).textSecondary)
              .margin({ top: 40 })
          } else if (this.message.length > 0 && this.wordText.length === 0) {
            Text(this.message)
              .fontSize(16)
              .fontColor(ThemeColor.get(this.darkMode).textSecondary)
              .margin({ top: 40 })
          } else {
            Column() {
            Text(this.wordText)
              .fontSize(38)
              .fontWeight(FontWeight.Bold)
              .fontColor(ThemeColor.get(this.darkMode).textPrimary)
              .width('100%')
              .textAlign(TextAlign.Start)
              .margin({ top: 2 })

            Row() {
              Image(this.pronounceIcon())
                .width(22)
                .height(22)
                .objectFit(ImageFit.Contain)
                .onClick(() => {
                  this.runPronounceAnimation(this.playPronunciation());
                })

              if (this.phonetic.length > 0) {
                Text(this.phonetic)
                  .fontSize(16)
                  .fontColor(ThemeColor.get(this.darkMode).textSecondary)
                  .margin({ left: 10 })
              }

            }
            .justifyContent(FlexAlign.Start)
            .alignItems(VerticalAlign.Center)
            .width('100%')
            .margin({ top: 12 })

            Text(this.translation)
              .fontSize(21)
              .fontColor(ThemeColor.get(this.darkMode).primary)
              .fontWeight(FontWeight.Bold)
              .width('100%')
              .textAlign(TextAlign.Start)
              .lineHeight(30)
              .margin({ top: 18 })

            if (this.audioMessage.length > 0) {
              Text(this.audioMessage)
                .fontSize(13)
                .fontColor(ThemeColor.get(this.darkMode).danger)
                .margin({ top: 10 })
            }
          }
          .width('100%')
          .padding({ left: 18, right: 18, top: 12, bottom: 20 })
          .margin({ top: this.DETAIL_CARD_SPACING })
          .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
          .borderRadius(18)
          .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
          .shadow({
            radius: 14,
            color: 'rgba(15, 23, 42, 0.06)',
            offsetY: 6
          })

          Column() {
            this.sectionTitle('单词变形')
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.variants(), (item: WordVariant) => {
                this.variantChip(item)
              }, (item: WordVariant) => item.part + '-' + item.value)
            }
            .width('100%')
            .margin({ top: 12 })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 16 })
          .margin({ top: this.DETAIL_CARD_SPACING })
          .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
          .borderRadius(18)
          .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
          .shadow({
            radius: 10,
            color: 'rgba(15, 23, 42, 0.05)',
            offsetY: 4
          })

          if (this.examplePairs().length > 0) {
            Column() {
              this.sectionTitle('词书例句')
              ForEach(this.examplePairs(), (item: ExamplePair, index: number) => {
                Row() {
                  Text((index + 1).toString())
                    .fontSize(11)
                    .fontColor(ThemeColor.get(this.darkMode).primary)
                    .fontWeight(FontWeight.Bold)
                    .width(22)
                    .height(22)
                    .textAlign(TextAlign.Center)
                    .backgroundColor(this.darkMode ? '#17233A' : '#F1F7FF')
                    .borderRadius(11)

                  Column() {
                    if (item.english.length > 0) {
                      this.highlightedExample(item.english)
                    }

                    if (item.chinese.length > 0) {
                      Text(item.chinese)
                        .fontSize(13)
                        .fontColor(ThemeColor.get(this.darkMode).textSecondary)
                        .lineHeight(20)
                        .width('100%')
                        .margin({ top: 6 })
                    }
                  }
                  .layoutWeight(1)
                  .margin({ left: 10 })
                }
                .width('100%')
                .alignItems(VerticalAlign.Top)
                .margin({ top: 12 })
              }, (item: ExamplePair, index: number) => index.toString() + item.english + item.chinese)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 16 })
            .margin({ top: this.DETAIL_CARD_SPACING })
            .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
            .borderRadius(18)
            .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
            .shadow({
              radius: 10,
              color: 'rgba(15, 23, 42, 0.05)',
              offsetY: 4
            })
          }

          if (this.partExamples().length > 0) {
            Column() {
              this.sectionTitle('不同词性例句')
              ForEach(this.partExamples(), (item: ExamplePair) => {
                Row() {
                  if (item.part && item.part.length > 0) {
                    Text(item.part)
                      .fontSize(12)
                      .fontColor(ThemeColor.get(this.darkMode).primary)
                      .fontWeight(FontWeight.Bold)
                      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                      .backgroundColor(this.darkMode ? '#17233A' : '#F1F7FF')
                      .borderRadius(12)
                      .margin({ right: 10 })
                  }

                  Column() {
                    if (item.english.length > 0) {
                      this.highlightedExample(item.english)
                    }

                    if (item.chinese.length > 0) {
                      Text(item.chinese)
                        .fontSize(13)
                        .fontColor(ThemeColor.get(this.darkMode).textSecondary)
                        .lineHeight(20)
                        .width('100%')
                        .margin({ top: 6 })
                    }
                  }
                  .layoutWeight(1)
                }
                .width('100%')
                .alignItems(VerticalAlign.Top)
                .margin({ top: 12 })
              }, (item: ExamplePair) => item.english + item.chinese)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 16 })
            .margin({ top: this.DETAIL_CARD_SPACING })
            .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
            .borderRadius(18)
            .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
            .shadow({
              radius: 10,
              color: 'rgba(15, 23, 42, 0.05)',
              offsetY: 4
            })
          }

          Column() {
            Button(this.isAiLoading ? '请求中...' : 'AI 解释')
              .width('100%')
              .buttonStyle(ButtonStyleMode.EMPHASIZED)
              .controlSize(ControlSize.NORMAL)
              .role(ButtonRole.NORMAL)
              .enabled(!this.isAiLoading)
              .onClick(() => {
                this.explainByAi();
              })
          }
          .width('100%')
          .padding(14)
          .margin({ top: this.DETAIL_CARD_SPACING })
          .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
          .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
          .borderRadius(18)
          .shadow({
            radius: 10,
            color: 'rgba(15, 23, 42, 0.05)',
            offsetY: 4
          })

          if (this.message.length > 0) {
            Text(this.message)
              .fontSize(14)
              .fontColor(ThemeColor.get(this.darkMode).primary)
              .margin({ top: 14 })
          }

          if (this.aiText.length > 0) {
            Text(this.aiText)
              .width('100%')
              .fontSize(14)
              .fontColor(ThemeColor.get(this.darkMode).textPrimary)
              .lineHeight(22)
              .padding(16)
              .margin({ top: this.DETAIL_CARD_SPACING })
              .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
              .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
              .borderRadius(16)
              .shadow({ radius: 10, color: 'rgba(15, 23, 42, 0.05)', offsetY: 4 })
          }
          }
          }
          .width('100%')
        }
        .width('100%')
        .reuseId('word-detail-content')

        ListItem() {
          Column().width('100%').height(this.DETAIL_BOTTOM_SPACING)
        }
        .width('100%')
        .reuseId('word-detail-bottom-spacer')
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
    .titleBar(createHdsSubPageTitleBarOptions('单词详情', this.darkMode, this.materialEffectMode))
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .bindToScrollable([this.pageScroller])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    .backgroundColor(ThemeColor.get(this.darkMode).background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}

