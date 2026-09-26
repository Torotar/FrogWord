import { SelectionMenu } from '@kit.ArkUI';
import { Word } from '../model/Word';

interface TranslationPart {
  part: string;
  meaning: string;
}

@Component
export struct WordListItem {
  word: Word = {
    id: 0,
    word: '',
    phonetic: '',
    partOfSpeech: '',
    pronunciationUrl: '',
    translation: '',
    example: '',
    bookId: 0,
    difficulty: 1,
    createdAt: 0
  };
  @Prop cardBackground: string = '#FFFFFF';
  @Prop textPrimary: string = '#0F172A';
  @Prop textSecondary: string = '#64748B';
  @Prop darkMode: boolean = false;
  @Prop showPartOfSpeech: boolean = true;
  onItemClick?: () => void;

  private translationParts(): TranslationPart[] {
    const result: TranslationPart[] = [];
    const rawItems: string[] = this.word.translation.replace(/\r/g, '\n').split(/;|\n/);
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

  @Builder
  private textSelectionMenu() {
    SelectionMenu({});
  }

  @Builder
  private wordContent() {
    Row() {
      Column() {
        Row() {
          Text(this.word.word)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textPrimary)
            .copyOption(CopyOptions.LocalDevice)
            .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
            .bindSelectionMenu(TextSpanType.TEXT, this.textSelectionMenu, TextResponseType.LONG_PRESS)

          Text(this.word.phonetic)
            .fontSize(13)
            .fontColor(this.textSecondary)
            .margin({ left: 8 })
            .copyOption(CopyOptions.LocalDevice)
            .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
            .bindSelectionMenu(TextSpanType.TEXT, this.textSelectionMenu, TextResponseType.LONG_PRESS)

          if (this.showPartOfSpeech && this.word.partOfSpeech && this.word.partOfSpeech.length > 0) {
            Text(this.word.partOfSpeech)
              .fontSize(12)
              .fontColor(this.textSecondary)
              .margin({ left: 8 })
              .copyOption(CopyOptions.LocalDevice)
              .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
              .bindSelectionMenu(TextSpanType.TEXT, this.textSelectionMenu, TextResponseType.LONG_PRESS)
          }
        }
        .width('100%')

        if (this.translationParts().length > 0) {
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            ForEach(this.translationParts(), (item: TranslationPart) => {
              Row() {
                Text(item.part)
                  .fontSize(12)
                  .fontColor(this.textSecondary)
                  .copyOption(CopyOptions.LocalDevice)
                  .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
                  .bindSelectionMenu(TextSpanType.TEXT, this.textSelectionMenu, TextResponseType.LONG_PRESS)
                Text(item.meaning)
                  .fontSize(13)
                  .fontColor(this.textSecondary)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ left: 3 })
                  .copyOption(CopyOptions.LocalDevice)
                  .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
                  .bindSelectionMenu(TextSpanType.TEXT, this.textSelectionMenu, TextResponseType.LONG_PRESS)
              }
              .margin({ right: 12, top: 6 })
            }, (item: TranslationPart) => item.part + item.meaning)
          }
          .width('100%')
        } else {
          Text(this.word.translation)
            .fontSize(14)
            .fontColor(this.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 6 })
            .copyOption(CopyOptions.LocalDevice)
            .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
            .bindSelectionMenu(TextSpanType.TEXT, this.textSelectionMenu, TextResponseType.LONG_PRESS)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Image(this.darkMode ? $r('app.media.back_dark') : $r('app.media.back_light'))
        .width(11)
        .height(11)
        .objectFit(ImageFit.Contain)
        .scale({ x: -1, y: 1 })
    }
    .width('100%')
    .padding(16)
  }

  build() {
    Row() {
      this.wordContent()
    }
    .width('100%')
    .backgroundColor(this.cardBackground)
    .borderRadius(16)
    .border({ width: 1, color: this.darkMode ? '#334155' : '#E2E8F0' })
    .shadow({ radius: 10, color: 'rgba(15, 23, 42, 0.05)', offsetY: 4 })
    .onClick(() => {
      if (this.onItemClick) {
        this.onItemClick();
      }
    })
  }
}
