import { common } from '@kit.AbilityKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import { buffer } from '@kit.ArkTS';
import { relationalStore } from '@kit.ArkData';
import { ImportResult, ImportWordItem } from '../model/ImportResult';
import { CsvParser } from '../utils/CsvParser';
import { DateUtil } from '../utils/DateUtil';
import { JsonParser } from '../utils/JsonParser';
import { YoudaoWordParser } from '../utils/YoudaoWordParser';
import { WordBookService } from './WordBookService';
import { WordService } from './WordService';
import { DatabaseService } from './DatabaseService';

export class ImportService {
  public static async importFromPicker(context: common.Context): Promise<ImportResult> {
    try {
      const uri: string = await ImportService.pickFile(context);
      if (uri.length === 0) {
        return ImportService.failResult('未选择文件');
      }
      return await ImportService.importFromUri(uri);
    } catch (error) {
      console.error('importFromPicker failed: ' + JSON.stringify(error));
      return ImportService.failResult('导入失败：' + JSON.stringify(error));
    }
  }

  private static async pickFile(context: common.Context): Promise<string> {
    try {
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      options.fileSuffixFilters = ['.csv', '.json'];
      const documentPicker = new picker.DocumentViewPicker(context);
      const uris: string[] = await documentPicker.select(options);
      if (uris.length > 0) {
        return uris[0];
      }
    } catch (error) {
      console.error('pickFile failed: ' + JSON.stringify(error));
    }
    return '';
  }

  private static async importFromUri(uri: string): Promise<ImportResult> {
    const lowerUri: string = uri.toLowerCase();
    if (lowerUri.indexOf('.csv') < 0 && lowerUri.indexOf('.json') < 0) {
      return ImportService.failResult('仅支持 .csv 和 .json 文件');
    }

    console.info('importFromUri: reading file uri=' + uri);
    const content: string = ImportService.readText(uri);
    console.info('importFromUri: content length=' + content.length.toString() + ', first 100 chars=' + content.substring(0, 100));
    if (content.trim().length === 0) {
      return ImportService.failResult('文件内容为空');
    }

    let words: ImportWordItem[] = [];
    try {
      if (lowerUri.indexOf('.json') >= 0) {
        // 先尝试 Youdao JSON Lines 格式（每行一个 JSON 对象）
        words = YoudaoWordParser.parseJsonLines(content);
        if (words.length === 0) {
          // 回退到标准 JSON 数组格式
          console.info('YoudaoWordParser returned 0 words, trying JsonParser...');
          words = JsonParser.parse(content);
        }
      } else {
        words = CsvParser.parse(content);
      }
    } catch (error) {
      console.error('parse import file failed: ' + JSON.stringify(error));
      return ImportService.failResult('文件解析失败：' + JSON.stringify(error));
    }

    if (words.length === 0) {
      return ImportService.failResult('没有解析到有效单词');
    }

    const bookName: string = '导入词书 ' + DateUtil.todayKey();
    return await ImportService.importWords(bookName, '从文件导入', words);
  }

  public static async importWords(bookName: string, description: string, words: ImportWordItem[]): Promise<ImportResult> {
    if (words.length === 0) {
      return ImportService.failResult('没有解析到有效单词');
    }

    const bookId: number = await WordBookService.createWordBook(bookName, description);
    if (bookId <= 0) {
      console.error('importWords: createWordBook returned ' + bookId.toString() + ' for ' + bookName);
      return ImportService.failResult('创建词书失败');
    }
    console.info('importWords: created wordBook id=' + bookId.toString() + ' for ' + bookName);

    // 去重 + 归一化
    const seen: string[] = [];
    const validWords: ImportWordItem[] = [];
    for (let index: number = 0; index < words.length; index++) {
      const item: ImportWordItem = ImportService.normalize(words[index]);
      if (item.word.length === 0 || item.translation.length === 0) {
        continue;
      }
      if (ImportService.contains(seen, item.word)) {
        continue;
      }
      seen.push(item.word);
      validWords.push(item);
    }

    const store = DatabaseService.getStore();
    const now: number = Date.now();
    const BATCH_SIZE: number = 100;
    let insertedCount: number = 0;

    try {
      for (let batchStart: number = 0; batchStart < validWords.length; batchStart += BATCH_SIZE) {
        const batchEnd: number = Math.min(batchStart + BATCH_SIZE, validWords.length);
        const batch: ImportWordItem[] = validWords.slice(batchStart, batchEnd);

        // 构建批量 INSERT: INSERT INTO words(word,...) VALUES (?,?,...), (?,?,...), ...
        let sql: string = 'INSERT INTO words(word, phonetic, part_of_speech, pronunciation_url, translation, example, book_id, difficulty, created_at) VALUES ';
        const params: relationalStore.ValueType[] = [];
        const placeholders: string[] = [];
        for (const word of batch) {
          placeholders.push('(?, ?, ?, ?, ?, ?, ?, ?, ?)');
          params.push(word.word);
          params.push(word.phonetic);
          params.push(word.partOfSpeech ? word.partOfSpeech : '');
          params.push(word.pronunciationUrl ? word.pronunciationUrl : '');
          params.push(word.translation);
          params.push(word.example);
          params.push(bookId);
          params.push(word.difficulty);
          params.push(now);
        }
        sql += placeholders.join(', ');

        await store.executeSql(sql, params);
        insertedCount += batch.length;

        console.info('import progress: ' + insertedCount.toString() + '/' + validWords.length.toString() +
          ' (batch ' + (Math.floor(batchStart / BATCH_SIZE) + 1).toString() +
          '/' + Math.ceil(validWords.length / BATCH_SIZE).toString() + ')');
      }
      console.info('import batch completed, total=' + insertedCount.toString());
    } catch (batchError) {
      console.error('import batch insert failed: ' + JSON.stringify(batchError));
      await WordBookService.deleteWordBook(bookId);
      return ImportService.failResult('批量导入失败：' + JSON.stringify(batchError));
    }

    await WordBookService.updateTotalCount(bookId);
    console.info('import success bookId=' + bookId.toString() + ', inserted=' + insertedCount.toString() +
      ', skipped=' + (validWords.length - insertedCount).toString());
    if (insertedCount === 0) {
      await WordBookService.deleteWordBook(bookId);
    }
    return {
      success: insertedCount > 0,
      bookName: bookName,
      successCount: insertedCount,
      skipCount: words.length - validWords.length,
      failCount: 0,
      message: insertedCount > 0 ? '导入完成' : '没有成功导入单词，已清理空词书'
    };
  }

  private static readText(uri: string): string {
    let file: fileIo.File | undefined = undefined;
    try {
      file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      // 尝试用 stat.size 读取，如果为 0 则尝试分段读取
      let stat: fileIo.Stat | undefined = undefined;
      try {
        stat = fileIo.statSync(uri);
      } catch (statError) {
        console.warn('readText statSync failed, trying fallback: ' + JSON.stringify(statError));
      }
      const bufSize: number = (stat && stat.size > 0) ? stat.size : 1048576; // 默认 1MB
      const arrayBuffer: ArrayBuffer = new ArrayBuffer(bufSize);
      const readLength: number = fileIo.readSync(file.fd, arrayBuffer);
      return buffer.from(arrayBuffer, 0, readLength).toString();
    } catch (error) {
      console.error('readText failed: ' + JSON.stringify(error));
      return '';
    } finally {
      if (file) {
        fileIo.closeSync(file);
      }
    }
  }

  private static normalize(item: ImportWordItem): ImportWordItem {
    const difficulty: number = item.difficulty < 1 || item.difficulty > 5 ? 1 : item.difficulty;
    return {
      word: item.word.trim(),
      phonetic: item.phonetic.trim(),
      partOfSpeech: item.partOfSpeech ? item.partOfSpeech.trim() : '',
      pronunciationUrl: item.pronunciationUrl ? item.pronunciationUrl.trim() : '',
      translation: item.translation.trim(),
      example: item.example.trim(),
      difficulty: Math.round(difficulty)
    };
  }

  private static contains(words: string[], word: string): boolean {
    const normalized: string = word.toLowerCase();
    for (let index: number = 0; index < words.length; index++) {
      if (words[index].toLowerCase() === normalized) {
        return true;
      }
    }
    return false;
  }

  private static failResult(message: string): ImportResult {
    return {
      success: false,
      bookName: '',
      successCount: 0,
      skipCount: 0,
      failCount: 0,
      message: message
    };
  }
}
