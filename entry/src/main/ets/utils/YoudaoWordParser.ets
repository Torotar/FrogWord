import { ImportWordItem } from '../model/ImportResult';

interface YoudaoSentence {
  sContent?: string;
  sCn?: string;
}

interface YoudaoSentenceGroup {
  sentences?: YoudaoSentence[];
}

interface YoudaoTrans {
  tranCn?: string;
  tranOther?: string;
  pos?: string;
}

interface YoudaoWordContent {
  usphone?: string;
  ukphone?: string;
  usspeech?: string;
  ukspeech?: string;
  speech?: string;
  trans?: YoudaoTrans[];
  sentence?: YoudaoSentenceGroup;
}

interface YoudaoWord {
  wordHead?: string;
  content?: YoudaoWordContent;
}

interface YoudaoOuterContent {
  word?: YoudaoWord;
}

interface YoudaoWordLine {
  wordRank?: number;
  headWord?: string;
  content?: YoudaoOuterContent;
}

export class YoudaoWordParser {
  public static parseJsonLines(content: string): ImportWordItem[] {
    const words: ImportWordItem[] = [];
    const lines: string[] = content.split('\n');
    for (let index: number = 0; index < lines.length; index++) {
      const line: string = lines[index].trim();
      if (line.length === 0) {
        continue;
      }

      try {
        const item: YoudaoWordLine = JSON.parse(line) as YoudaoWordLine;
        const word: ImportWordItem = YoudaoWordParser.toImportWord(item);
        if (word.word.length > 0 && word.translation.length > 0) {
          words.push(word);
        }
      } catch (error) {
        console.error('parse youdao word line failed: ' + JSON.stringify(error));
      }
    }
    return words;
  }

  private static toImportWord(item: YoudaoWordLine): ImportWordItem {
    const wordContent: YoudaoWordContent | undefined = item.content?.word?.content;
    const word: string = YoudaoWordParser.safeString(item.headWord || item.content?.word?.wordHead);
    const phonetic: string = YoudaoWordParser.buildPhonetic(wordContent);
    const partOfSpeech: string = YoudaoWordParser.buildPartOfSpeech(wordContent);
    const pronunciationUrl: string = YoudaoWordParser.buildPronunciationUrl(wordContent, word);
    const translation: string = YoudaoWordParser.buildTranslation(wordContent);
    const example: string = YoudaoWordParser.buildExample(wordContent);

    return {
      word: word,
      phonetic: phonetic,
      partOfSpeech: partOfSpeech,
      pronunciationUrl: pronunciationUrl,
      translation: translation,
      example: example,
      difficulty: YoudaoWordParser.rankToDifficulty(item.wordRank)
    };
  }

  private static buildPhonetic(content?: YoudaoWordContent): string {
    if (!content) {
      return '';
    }
    const phone: string = YoudaoWordParser.safeString(content.usphone || content.ukphone);
    return phone.length > 0 ? '/' + phone.replace(/\//g, '') + '/' : '';
  }

  private static buildPartOfSpeech(content?: YoudaoWordContent): string {
    if (!content || !content.trans || content.trans.length === 0) {
      return '';
    }

    const parts: string[] = [];
    for (let index: number = 0; index < content.trans.length; index++) {
      const part: string = YoudaoWordParser.normalizePartOfSpeech(content.trans[index].pos);
      if (part.length > 0 && !YoudaoWordParser.contains(parts, part)) {
        parts.push(part);
      }
    }
    return parts.join(' / ');
  }

  private static buildPronunciationUrl(content: YoudaoWordContent | undefined, word: string): string {
    const speech: string = content
      ? YoudaoWordParser.safeString(content.usspeech || content.ukspeech || content.speech)
      : '';
    if (speech.length > 0) {
      return YoudaoWordParser.buildYoudaoSpeechUrl(speech);
    }
    const safeWord: string = word.trim();
    return safeWord.length > 0 ? 'http://dict.youdao.com/dictvoice?audio=' + encodeURIComponent(safeWord) + '&type=2' : '';
  }

  private static buildYoudaoSpeechUrl(speech: string): string {
    const splitIndex: number = speech.indexOf('&');
    if (splitIndex < 0) {
      return 'http://dict.youdao.com/dictvoice?audio=' + encodeURIComponent(speech);
    }
    const audio: string = speech.substring(0, splitIndex);
    const query: string = speech.substring(splitIndex);
    return 'http://dict.youdao.com/dictvoice?audio=' + encodeURIComponent(audio) + query;
  }

  private static buildTranslation(content?: YoudaoWordContent): string {
    if (!content || !content.trans || content.trans.length === 0) {
      return YoudaoWordParser.buildSentenceCnFallback(content);
    }

    const translations: string[] = [];
    for (let index: number = 0; index < content.trans.length && index < 3; index++) {
      const text: string = YoudaoWordParser.safeString(content.trans[index].tranCn || content.trans[index].tranOther);
      if (text.length > 0) {
        const pos: string = YoudaoWordParser.normalizePartOfSpeech(content.trans[index].pos);
        translations.push(pos.length > 0 ? pos + '. ' + text : text);
      }
    }
    return translations.length > 0 ? translations.join('; ') : YoudaoWordParser.buildSentenceCnFallback(content);
  }

  private static buildExample(content?: YoudaoWordContent): string {
    const sentences: YoudaoSentence[] | undefined = content?.sentence?.sentences;
    if (!sentences || sentences.length === 0) {
      return '';
    }
    const examples: string[] = [];
    for (let index: number = 0; index < sentences.length && examples.length < 4; index++) {
      const english: string = YoudaoWordParser.safeString(sentences[index].sContent);
      const chinese: string = YoudaoWordParser.safeString(sentences[index].sCn);
      if (english.length > 0 && chinese.length > 0) {
        examples.push(english + '\n' + chinese);
      } else if (english.length > 0) {
        examples.push(english);
      } else if (chinese.length > 0) {
        examples.push(chinese);
      }
    }
    return examples.join('\n\n');
  }

  private static buildSentenceCnFallback(content?: YoudaoWordContent): string {
    const sentences: YoudaoSentence[] | undefined = content?.sentence?.sentences;
    if (!sentences || sentences.length === 0) {
      return '';
    }
    return YoudaoWordParser.safeString(sentences[0].sCn);
  }

  private static normalizePartOfSpeech(value?: string): string {
    return YoudaoWordParser.safeString(value).replace(/\.$/, '');
  }

  private static contains(items: string[], value: string): boolean {
    for (let index: number = 0; index < items.length; index++) {
      if (items[index] === value) {
        return true;
      }
    }
    return false;
  }

  private static rankToDifficulty(rank?: number): number {
    if (!rank || rank <= 300) {
      return 1;
    }
    if (rank <= 1000) {
      return 2;
    }
    if (rank <= 2500) {
      return 3;
    }
    if (rank <= 5000) {
      return 4;
    }
    return 5;
  }

  private static safeString(value?: string): string {
    return value ? value.trim() : '';
  }
}
