import { ImportWordItem } from '../model/ImportResult';

interface JsonWordItem {
  word?: string;
  phonetic?: string;
  partOfSpeech?: string;
  pronunciationUrl?: string;
  translation?: string;
  example?: string;
  difficulty?: number;
}

export class JsonParser {
  public static parse(content: string): ImportWordItem[] {
    const words: ImportWordItem[] = [];
    const parsed: JsonWordItem[] = JSON.parse(content) as JsonWordItem[];
    if (!Array.isArray(parsed)) {
      return words;
    }

    for (let index: number = 0; index < parsed.length; index++) {
      const item: JsonWordItem = parsed[index];
      words.push({
        word: JsonParser.safeString(item.word),
        phonetic: JsonParser.safeString(item.phonetic),
        partOfSpeech: JsonParser.safeString(item.partOfSpeech),
        pronunciationUrl: JsonParser.safeString(item.pronunciationUrl),
        translation: JsonParser.safeString(item.translation),
        example: JsonParser.safeString(item.example),
        difficulty: JsonParser.normalizeDifficulty(item.difficulty)
      });
    }
    return words;
  }

  private static safeString(value?: string): string {
    return value ? value.trim() : '';
  }

  private static normalizeDifficulty(value?: number): number {
    if (!value || Number.isNaN(value) || value < 1 || value > 5) {
      return 1;
    }
    return Math.round(value);
  }
}
