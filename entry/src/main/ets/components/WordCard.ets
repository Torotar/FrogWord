import { Constants } from '../utils/Constants';

interface CardExamplePair {
  english: string;
  chinese: string;
  part?: string;
}

@Component
export struct WordCard {
  @Prop wordText: string = '';
  @Prop phonetic: string = '';
  @Prop partOfSpeech: string = '';
  @Prop translation: string = '';
  @Prop example: string = '';
  @Prop showDetail: boolean = false;
  @Prop cardBackground: string = '#FFFFFF';
  @Prop textPrimary: string = '#0F172A';
  @Prop textSecondary: string = '#64748B';
  @Prop primary: string = '#2563EB';
  @Prop dividerColor: string = '#E2E8F0';
  @Prop compactMode: boolean = false;
  @Prop darkMode: boolean = false;
  @Prop @Watch('onPronounceRequest') pronounceRequestId: number = 0;
  @State private pronounceFrame: number = 2;
  private pronounceAnimationTimer: number = -1;
  private pronounceAnimationId: number = 0;
  onPronounce?: () => Promise<void>;

  aboutToDisappear(): void {
    this.stopPronounceAnimation();
  }

  private onPronounceRequest(): void {
    if (this.pronounceRequestId <= 0 || !this.onPronounce) {
      return;
    }
    this.runPronounceAnimation(this.onPronounce());
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

  private displayPartOfSpeech(): string {
    if (this.partOfSpeech.trim().length > 0) {
      return this.partOfSpeech.trim();
    }
    const match = this.translation.match(/^([a-zA-Z]+)\.\s*/);
    return match && match.length > 1 ? match[1] : '';
  }

  private wordFontSize(): number {
    if (this.wordText.length > 34) {
      return this.compactMode ? 20 : 22;
    }
    if (this.wordText.length > 28) {
      return this.compactMode ? 22 : 24;
    }
    if (this.wordText.length > 22) {
      return this.compactMode ? 24 : 28;
    }
    if (this.wordText.length > 16) {
      return this.compactMode ? 28 : 32;
    }
    if (this.wordText.length > 12) {
      return this.compactMode ? 32 : 36;
    }
    if (this.wordText.length > 10) {
      return this.compactMode ? 34 : 38;
    }
    return this.compactMode ? 38 : 42;
  }

  private compactCardBackground(): string {
    return this.cardBackground;
  }

  private splitItems(value: string, limit: number): string[] {
    const result: string[] = [];
    const normalized: string = value.replace(/\r/g, '\n').replace(/\uFF1B/g, ';').replace(/\u3002/g, '.');
    const rawItems: string[] = normalized.split(/\n+|;+/);
    for (let index: number = 0; index < rawItems.length && result.length < limit; index++) {
      const item: string = rawItems[index].trim();
      if (item.length > 0) {
        result.push(item);
      }
    }
    return result;
  }

  private examplePairs(): CardExamplePair[] {
    const result: CardExamplePair[] = [];
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
    if (result.length === 0 && this.example.trim().length > 0) {
      const fallbackItems: string[] = this.splitItems(this.example, 4);
      for (let index: number = 0; index < fallbackItems.length; index++) {
        result.push({ english: fallbackItems[index], chinese: '' });
      }
    }
    return result;
  }

  private partExamples(): CardExamplePair[] {
    const parts: string[] = this.splitItems(this.displayPartOfSpeech().replace(/\//g, ';'), 4);
    const examples: CardExamplePair[] = this.examplePairs();
    const result: CardExamplePair[] = [];
    if (parts.length === 0) {
      return examples.length > 0 ? [examples[0]] : [];
    }
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
  private pronounceButton() {
    if (this.onPronounce) {
      Image(this.pronounceIcon())
        .width(this.compactMode ? 24 : 26)
        .height(this.compactMode ? 24 : 26)
        .objectFit(ImageFit.Contain)
        .onClick(() => {
          if (this.onPronounce) {
            this.runPronounceAnimation(this.onPronounce());
          }
        })
    }
  }

  @Builder
  private wordTitle() {
    Row() {
      Text(this.wordText)
        .fontSize(this.wordFontSize())
        .height(this.compactMode ? 48 : 54)
        .lineHeight(this.compactMode ? 48 : 54)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.textPrimary)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .width('100%')
    }
    .width('100%')
    .height(this.compactMode ? 48 : 54)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private wordHeader() {
    Column() {
      this.wordTitle()

      if (this.onPronounce || this.displayPartOfSpeech().length > 0 || this.phonetic.length > 0) {
        Row() {
          if (this.onPronounce) {
            this.pronounceButton()
          }

          if (this.displayPartOfSpeech().length > 0) {
            Text(this.displayPartOfSpeech())
              .fontSize(this.compactMode ? 14 : 15)
              .fontColor(this.textSecondary)
              .fontWeight(FontWeight.Regular)
              .margin({ left: this.onPronounce ? 8 : 0 })
          }

          if (this.phonetic.length > 0) {
            Text(this.phonetic)
              .fontSize(this.compactMode ? 16 : 18)
              .fontColor(this.textSecondary)
              .margin({ left: (this.onPronounce || this.displayPartOfSpeech().length > 0) ? 10 : 0 })
          }
        }
        .height(this.compactMode ? 26 : 28)
        .alignItems(VerticalAlign.Center)
        .margin({ top: this.compactMode ? 8 : 10 })
      }
    }
    .width('100%')
    .height(this.compactMode ? 84 : 94)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private highlightedExample(text: string) {
    if (this.exampleHighlight(text).length > 0) {
      Text() {
        Span(this.examplePrefix(text))
          .fontColor(this.textSecondary)
        Span(this.exampleHighlight(text))
          .fontColor(this.primary)
          .fontWeight(FontWeight.Bold)
        Span(this.exampleSuffix(text))
          .fontColor(this.textSecondary)
      }
      .fontSize(this.compactMode ? 15 : 16)
      .lineHeight(this.compactMode ? 22 : 24)
      .textAlign(TextAlign.Start)
      .width('100%')
    } else {
      Text(text)
        .fontSize(this.compactMode ? 15 : 16)
        .fontColor(this.textSecondary)
        .lineHeight(this.compactMode ? 22 : 24)
        .textAlign(TextAlign.Start)
        .width('100%')
    }
  }

  @Builder
  private exampleList() {
    Column() {
      ForEach(this.partExamples(), (item: CardExamplePair, index: number) => {
        Column() {
          if (item.english.length > 0) {
            this.highlightedExample(item.english)
          }
          if (item.chinese.length > 0) {
            Text(item.chinese)
              .fontSize(this.compactMode ? 14 : 15)
              .fontColor(this.textSecondary)
              .lineHeight(this.compactMode ? 21 : 23)
              .textAlign(TextAlign.Start)
              .width('100%')
              .margin({ top: 4 })
          }
        }
        .width('100%')
        .margin({ top: index === 0 ? 0 : 14 })
      }, (item: CardExamplePair, index: number) => index.toString() + item.english + item.chinese)
    }
    .width('100%')
    .margin({ top: this.compactMode ? 14 : 18 })
  }

  build() {
    Column() {
      this.wordHeader()

      if (this.showDetail) {
        Divider()
          .color(this.dividerColor)
          .margin({
            top: this.compactMode ? 20 : 28,
            bottom: this.compactMode ? 18 : 24
          })

        Text(this.translation)
          .fontSize(this.compactMode ? 20 : 22)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.primary)
          .textAlign(TextAlign.Center)

        this.exampleList()
      }
    }
    .width('100%')
    .constraintSize({
      minHeight: this.showDetail ? (this.compactMode ? 280 : 320) : (this.compactMode ? 148 : 168)
    })
    .padding(this.compactMode ? { left: 24, right: 24, top: 30, bottom: 30 } : { left: 28, right: 28, top: 34, bottom: 34 })
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.compactCardBackground())
    .borderRadius(this.compactMode ? 20 : 22)
    .border({ width: 1, color: this.dividerColor })
    .shadow({
      radius: this.compactMode ? 10 : 14,
      color: this.compactMode ? 'rgba(15, 23, 42, 0.05)' : 'rgba(15, 23, 42, 0.06)',
      offsetY: this.compactMode ? 4 : 6
    })
  }
}
