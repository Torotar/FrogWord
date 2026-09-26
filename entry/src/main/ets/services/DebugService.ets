import { relationalStore } from '@kit.ArkData';
import { DEFAULT_WORDS } from '../data/DefaultWords';
import { DateUtil } from '../utils/DateUtil';
import { Logger } from '../utils/Logger';
import { DatabaseService } from './DatabaseService';
import { StudyRecordService } from './StudyRecordService';

export interface DatabaseSummary {
  databaseReady: boolean;
  totalWords: number;
  bookCount: number;
  studyRecordCount: number;
  todayLearnCount: number;
  pendingReviewCount: number;
  healthMessage: string;
}

export class DebugService {
  private static readonly TAG: string = 'DebugService';

  public static async getDatabaseSummary(): Promise<DatabaseSummary> {
    const summary: DatabaseSummary = {
      databaseReady: false,
      totalWords: 0,
      bookCount: 0,
      studyRecordCount: 0,
      todayLearnCount: 0,
      pendingReviewCount: 0,
      healthMessage: ''
    };

    try {
      summary.totalWords = await DebugService.queryCount('SELECT COUNT(*) AS count FROM words');
      summary.bookCount = await DebugService.queryCount('SELECT COUNT(*) AS count FROM word_book');
      summary.studyRecordCount = await DebugService.queryCount('SELECT COUNT(*) AS count FROM study_record');
      summary.todayLearnCount = await DebugService.queryCount(
        'SELECT IFNULL(SUM(learn_count), 0) AS count FROM study_daily WHERE date = ?',
        [DateUtil.todayKey()]
      );
      summary.pendingReviewCount = await DebugService.queryCount(
        'SELECT COUNT(*) AS count FROM study_record WHERE mastered = 0 AND next_review_time > 0 AND next_review_time <= ?',
        [Date.now()]
      );
      summary.databaseReady = true;
      summary.healthMessage = await DebugService.checkDatabaseHealth();
      Logger.info(DebugService.TAG, 'database summary loaded');
    } catch (error) {
      Logger.error(DebugService.TAG, 'getDatabaseSummary failed', error as Error);
      summary.healthMessage = '数据库状态读取失败';
    }
    return summary;
  }

  public static async clearStudyRecords(): Promise<void> {
    await StudyRecordService.resetAllRecords();
    Logger.warn(DebugService.TAG, 'study records cleared from debug page');
  }

  public static async resetDefaultWords(): Promise<void> {
    try {
      await DatabaseService.executeSql('DELETE FROM study_record');
      await DatabaseService.executeSql('DELETE FROM study_daily');
      await DatabaseService.executeSql('DELETE FROM study_event');
      await DatabaseService.executeSql('DELETE FROM words WHERE book_id = 1');
      await DatabaseService.executeSql('DELETE FROM word_book WHERE id = 1');
      await DatabaseService.executeSql(
        'INSERT INTO word_book(id, name, description, total_count, created_at) VALUES(?, ?, ?, ?, ?)',
        [1, '默认词库', 'WordFlow 内置常用英语词库', DEFAULT_WORDS.length, Date.now()]
      );
      for (const word of DEFAULT_WORDS) {
        await DatabaseService.executeSql(
          'INSERT INTO words(id, word, phonetic, part_of_speech, pronunciation_url, translation, example, book_id, difficulty, created_at) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            word.id,
            word.word,
            word.phonetic,
            word.partOfSpeech ? word.partOfSpeech : '',
            word.pronunciationUrl ? word.pronunciationUrl : '',
            word.translation,
            word.example,
            1,
            word.difficulty,
            Date.now()
          ]
        );
      }
      Logger.warn(DebugService.TAG, 'default words reset');
    } catch (error) {
      Logger.error(DebugService.TAG, 'resetDefaultWords failed', error as Error);
    }
  }

  public static async checkDatabaseHealth(): Promise<string> {
    try {
      const wordCount: number = await DebugService.queryCount('SELECT COUNT(*) AS count FROM words');
      const bookCount: number = await DebugService.queryCount('SELECT COUNT(*) AS count FROM word_book');
      if (bookCount <= 0) {
        return '异常：词书表为空';
      }
      if (wordCount <= 0) {
        return '异常：单词表为空';
      }
      return '正常';
    } catch (error) {
      Logger.error(DebugService.TAG, 'checkDatabaseHealth failed', error as Error);
      return '异常：健康检查失败';
    }
  }

  private static async queryCount(sql: string, bindArgs: relationalStore.ValueType[] = []): Promise<number> {
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await DatabaseService.querySql(sql, bindArgs);
      if (resultSet.goToFirstRow()) {
        return resultSet.getLong(resultSet.getColumnIndex('count'));
      }
    } catch (error) {
      Logger.error(DebugService.TAG, 'queryCount failed: ' + sql, error as Error);
    } finally {
      if (resultSet) {
        resultSet.close();
      }
    }
    return 0;
  }
}
