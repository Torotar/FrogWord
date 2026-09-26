import { ImportWordItem } from '../model/ImportResult';

export class CsvParser {
  public static parse(content: string): ImportWordItem[] {
    const words: ImportWordItem[] = [];
    const lines: string[] = content.replace('\uFEFF', '').split('\n');

    for (let index: number = 0; index < lines.length; index++) {
      const rawLine: string = lines[index].trim();
      if (rawLine.length === 0) {
        continue;
      }
      if (index === 0 && rawLine.toLowerCase().indexOf('word') === 0) {
        continue;
      }

      const columns: string[] = CsvParser.splitLine(rawLine);
      if (columns.length < 3) {
        continue;
      }

      words.push({
        word: columns[0].trim(),
        phonetic: CsvParser.getColumn(columns, 1),
        partOfSpeech: CsvParser.extractPartOfSpeech(CsvParser.getColumn(columns, 2)),
        pronunciationUrl: '',
        translation: CsvParser.getColumn(columns, 2),
        example: CsvParser.getColumn(columns, 3),
        difficulty: CsvParser.parseDifficulty(CsvParser.getColumn(columns, 4))
      });
    }

    return words;
  }

  private static splitLine(line: string): string[] {
    const result: string[] = [];
    let current: string = '';
    let inQuotes: boolean = false;

    for (let index: number = 0; index < line.length; index++) {
      const char: string = line.charAt(index);
      if (char === '"') {
        inQuotes = !inQuotes;
      } else if (char === ',' && !inQuotes) {
        result.push(current);
        current = '';
      } else {
        current += char;
      }
    }
    result.push(current);
    return result;
  }

  private static getColumn(columns: string[], index: number): string {
    if (index >= columns.length) {
      return '';
    }
    return columns[index].trim().replace(/^"|"$/g, '');
  }

  private static parseDifficulty(value: string): number {
    const difficulty: number = Number(value);
    if (Number.isNaN(difficulty) || difficulty < 1 || difficulty > 5) {
      return 1;
    }
    return Math.round(difficulty);
  }

  private static extractPartOfSpeech(translation: string): string {
    const match = translation.match(/^([a-zA-Z]+)\.\s*/);
    return match && match.length > 1 ? match[1] : '';
  }
}
