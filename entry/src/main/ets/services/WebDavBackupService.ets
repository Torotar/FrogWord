import { relationalStore } from '@kit.ArkData';
import { Constants } from '../utils/Constants';
import { DatabaseService } from './DatabaseService';

interface BackupWordBook {
  id: number;
  name: string;
  description: string;
  total_count: number;
  created_at: number;
}

interface BackupWord {
  id: number;
  word: string;
  phonetic: string;
  part_of_speech: string;
  pronunciation_url: string;
  translation: string;
  example: string;
  book_id: number;
  difficulty: number;
  created_at: number;
}

interface BackupStudyRecord {
  id: number;
  word_id: number;
  correct_count: number;
  wrong_count: number;
  last_review_time: number;
  next_review_time: number;
  interval_days: number;
  ease_factor: number;
  mastered: number;
}

interface BackupStudyDaily {
  id: number;
  date: string;
  learn_count: number;
  review_count: number;
  correct_count: number;
  wrong_count: number;
  duration: number;
}

interface BackupStudyEvent {
  id: number;
  date: string;
  word_id: number;
  scene: string;
  correct: number;
  created_at: number;
}

interface BackupStudySession {
  id: number;
  date: string;
  start_time: number;
  end_time: number;
  duration: number;
  scene: string;
  word_count: number;
}

interface WebDavBackupPayload {
  app: string;
  version: number;
  appVersion: string;
  createdAt: number;
  data: WebDavBackupData;
}

interface WebDavBackupData {
  word_book: BackupWordBook[];
  words: BackupWord[];
  study_record: BackupStudyRecord[];
  study_daily: BackupStudyDaily[];
  study_event: BackupStudyEvent[];
  study_session: BackupStudySession[];
}

export interface WebDavRestoreSummary {
  wordBookCount: number;
  wordCount: number;
  studyRecordCount: number;
}

export class WebDavBackupService {
  public static readonly BACKUP_FILE_NAME: string = 'wordcard-backup.json';

  public static async exportBackupJson(): Promise<string> {
    const payload: WebDavBackupPayload = {
      app: 'wordcard',
      version: Constants.DATABASE_VERSION,
      appVersion: Constants.APP_VERSION,
      createdAt: Date.now(),
      data: {
        word_book: await WebDavBackupService.queryWordBooks(),
        words: await WebDavBackupService.queryWords(),
        study_record: await WebDavBackupService.queryStudyRecords(),
        study_daily: await WebDavBackupService.queryStudyDaily(),
        study_event: await WebDavBackupService.queryStudyEvents(),
        study_session: await WebDavBackupService.queryStudySessions()
      }
    };
    return JSON.stringify(payload);
  }

  public static async restoreBackupJson(content: string): Promise<WebDavRestoreSummary> {
    const backupContent: string = WebDavBackupService.normalizeBackupContent(content);
    const payload: WebDavBackupPayload = JSON.parse(backupContent) as WebDavBackupPayload;
    WebDavBackupService.validatePayload(payload);
    await WebDavBackupService.clearTables();
    await WebDavBackupService.insertWordBooks(payload.data.word_book);
    await WebDavBackupService.insertWords(payload.data.words);
    await WebDavBackupService.insertStudyRecords(payload.data.study_record);
    await WebDavBackupService.insertStudyDaily(payload.data.study_daily);
    await WebDavBackupService.insertStudyEvents(payload.data.study_event);
    await WebDavBackupService.insertStudySessions(payload.data.study_session);
    return {
      wordBookCount: payload.data.word_book.length,
      wordCount: payload.data.words.length,
      studyRecordCount: payload.data.study_record.length
    };
  }

  private static validatePayload(payload: WebDavBackupPayload): void {
    if (!payload || payload.app !== 'wordcard' || !payload.data) {
      throw new Error('invalid backup payload');
    }
    if (!payload.data.word_book || !payload.data.words || !payload.data.study_record || !payload.data.study_daily ||
      !payload.data.study_event || !payload.data.study_session) {
      throw new Error('invalid backup data');
    }
  }

  private static normalizeBackupContent(content: string): string {
    const text: string = content.trim();
    if (text.length === 0) {
      throw new Error('备份文件内容为空，请先重新上传数据');
    }
    if (text === '[object ArrayBuffer]') {
      throw new Error('备份文件读取失败，请更新后重新拉取');
    }
    if (text.startsWith('<')) {
      throw new Error('云端返回的不是备份文件，请检查同步路径');
    }
    if (!text.startsWith('{')) {
      throw new Error('备份文件格式不正确，请先重新上传数据');
    }
    return text.charCodeAt(0) === 0xFEFF ? text.substring(1) : text;
  }

  private static async clearTables(): Promise<void> {
    await DatabaseService.executeSqlThrow('DELETE FROM study_session');
    await DatabaseService.executeSqlThrow('DELETE FROM study_event');
    await DatabaseService.executeSqlThrow('DELETE FROM study_daily');
    await DatabaseService.executeSqlThrow('DELETE FROM study_record');
    await DatabaseService.executeSqlThrow('DELETE FROM words');
    await DatabaseService.executeSqlThrow('DELETE FROM word_book');
  }

  private static async queryWordBooks(): Promise<BackupWordBook[]> {
    const rows: BackupWordBook[] = [];
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await DatabaseService.querySql(
        'SELECT id, name, IFNULL(description, "") AS description, IFNULL(total_count, 0) AS total_count, ' +
          'IFNULL(created_at, 0) AS created_at FROM word_book ORDER BY id ASC'
      );
      while (resultSet.goToNextRow()) {
        rows.push({
          id: resultSet.getLong(resultSet.getColumnIndex('id')),
          name: resultSet.getString(resultSet.getColumnIndex('name')),
          description: resultSet.getString(resultSet.getColumnIndex('description')),
          total_count: resultSet.getLong(resultSet.getColumnIndex('total_count')),
          created_at: resultSet.getLong(resultSet.getColumnIndex('created_at'))
        });
      }
    } finally {
      if (resultSet) {
        resultSet.close();
      }
    }
    return rows;
  }

  private static async queryWords(): Promise<BackupWord[]> {
    const rows: BackupWord[] = [];
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await DatabaseService.querySql(
        'SELECT id, word, IFNULL(phonetic, "") AS phonetic, IFNULL(part_of_speech, "") AS part_of_speech, ' +
          'IFNULL(pronunciation_url, "") AS pronunciation_url, translation, IFNULL(example, "") AS example, ' +
          'IFNULL(book_id, 0) AS book_id, IFNULL(difficulty, 1) AS difficulty, IFNULL(created_at, 0) AS created_at ' +
          'FROM words ORDER BY id ASC'
      );
      while (resultSet.goToNextRow()) {
        rows.push({
          id: resultSet.getLong(resultSet.getColumnIndex('id')),
          word: resultSet.getString(resultSet.getColumnIndex('word')),
          phonetic: resultSet.getString(resultSet.getColumnIndex('phonetic')),
          part_of_speech: resultSet.getString(resultSet.getColumnIndex('part_of_speech')),
          pronunciation_url: resultSet.getString(resultSet.getColumnIndex('pronunciation_url')),
          translation: resultSet.getString(resultSet.getColumnIndex('translation')),
          example: resultSet.getString(resultSet.getColumnIndex('example')),
          book_id: resultSet.getLong(resultSet.getColumnIndex('book_id')),
          difficulty: resultSet.getLong(resultSet.getColumnIndex('difficulty')),
          created_at: resultSet.getLong(resultSet.getColumnIndex('created_at'))
        });
      }
    } finally {
      if (resultSet) {
        resultSet.close();
      }
    }
    return rows;
  }

  private static async queryStudyRecords(): Promise<BackupStudyRecord[]> {
    const rows: BackupStudyRecord[] = [];
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await DatabaseService.querySql(
        'SELECT id, word_id, IFNULL(correct_count, 0) AS correct_count, IFNULL(wrong_count, 0) AS wrong_count, ' +
          'IFNULL(last_review_time, 0) AS last_review_time, IFNULL(next_review_time, 0) AS next_review_time, ' +
          'IFNULL(interval_days, 1) AS interval_days, IFNULL(ease_factor, 2.5) AS ease_factor, ' +
          'IFNULL(mastered, 0) AS mastered FROM study_record ORDER BY id ASC'
      );
      while (resultSet.goToNextRow()) {
        rows.push({
          id: resultSet.getLong(resultSet.getColumnIndex('id')),
          word_id: resultSet.getLong(resultSet.getColumnIndex('word_id')),
          correct_count: resultSet.getLong(resultSet.getColumnIndex('correct_count')),
          wrong_count: resultSet.getLong(resultSet.getColumnIndex('wrong_count')),
          last_review_time: resultSet.getLong(resultSet.getColumnIndex('last_review_time')),
          next_review_time: resultSet.getLong(resultSet.getColumnIndex('next_review_time')),
          interval_days: resultSet.getLong(resultSet.getColumnIndex('interval_days')),
          ease_factor: resultSet.getDouble(resultSet.getColumnIndex('ease_factor')),
          mastered: resultSet.getLong(resultSet.getColumnIndex('mastered'))
        });
      }
    } finally {
      if (resultSet) {
        resultSet.close();
      }
    }
    return rows;
  }

  private static async queryStudyDaily(): Promise<BackupStudyDaily[]> {
    const rows: BackupStudyDaily[] = [];
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await DatabaseService.querySql(
        'SELECT id, date, IFNULL(learn_count, 0) AS learn_count, IFNULL(review_count, 0) AS review_count, ' +
          'IFNULL(correct_count, 0) AS correct_count, IFNULL(wrong_count, 0) AS wrong_count, ' +
          'IFNULL(duration, 0) AS duration FROM study_daily ORDER BY id ASC'
      );
      while (resultSet.goToNextRow()) {
        rows.push({
          id: resultSet.getLong(resultSet.getColumnIndex('id')),
          date: resultSet.getString(resultSet.getColumnIndex('date')),
          learn_count: resultSet.getLong(resultSet.getColumnIndex('learn_count')),
          review_count: resultSet.getLong(resultSet.getColumnIndex('review_count')),
          correct_count: resultSet.getLong(resultSet.getColumnIndex('correct_count')),
          wrong_count: resultSet.getLong(resultSet.getColumnIndex('wrong_count')),
          duration: resultSet.getLong(resultSet.getColumnIndex('duration'))
        });
      }
    } finally {
      if (resultSet) {
        resultSet.close();
      }
    }
    return rows;
  }

  private static async queryStudyEvents(): Promise<BackupStudyEvent[]> {
    const rows: BackupStudyEvent[] = [];
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await DatabaseService.querySql(
        'SELECT id, date, word_id, scene, IFNULL(correct, 0) AS correct, IFNULL(created_at, 0) AS created_at ' +
          'FROM study_event ORDER BY id ASC'
      );
      while (resultSet.goToNextRow()) {
        rows.push({
          id: resultSet.getLong(resultSet.getColumnIndex('id')),
          date: resultSet.getString(resultSet.getColumnIndex('date')),
          word_id: resultSet.getLong(resultSet.getColumnIndex('word_id')),
          scene: resultSet.getString(resultSet.getColumnIndex('scene')),
          correct: resultSet.getLong(resultSet.getColumnIndex('correct')),
          created_at: resultSet.getLong(resultSet.getColumnIndex('created_at'))
        });
      }
    } finally {
      if (resultSet) {
        resultSet.close();
      }
    }
    return rows;
  }

  private static async queryStudySessions(): Promise<BackupStudySession[]> {
    const rows: BackupStudySession[] = [];
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await DatabaseService.querySql(
        'SELECT id, date, start_time, end_time, IFNULL(duration, 0) AS duration, scene, ' +
          'IFNULL(word_count, 0) AS word_count FROM study_session ORDER BY id ASC'
      );
      while (resultSet.goToNextRow()) {
        rows.push({
          id: resultSet.getLong(resultSet.getColumnIndex('id')),
          date: resultSet.getString(resultSet.getColumnIndex('date')),
          start_time: resultSet.getLong(resultSet.getColumnIndex('start_time')),
          end_time: resultSet.getLong(resultSet.getColumnIndex('end_time')),
          duration: resultSet.getLong(resultSet.getColumnIndex('duration')),
          scene: resultSet.getString(resultSet.getColumnIndex('scene')),
          word_count: resultSet.getLong(resultSet.getColumnIndex('word_count'))
        });
      }
    } finally {
      if (resultSet) {
        resultSet.close();
      }
    }
    return rows;
  }

  private static async insertWordBooks(rows: BackupWordBook[]): Promise<void> {
    for (let index = 0; index < rows.length; index++) {
      const row: BackupWordBook = rows[index];
      await DatabaseService.executeSqlThrow(
        'INSERT INTO word_book(id, name, description, total_count, created_at) VALUES(?, ?, ?, ?, ?)',
        [row.id, row.name, row.description, row.total_count, row.created_at]
      );
    }
  }

  private static async insertWords(rows: BackupWord[]): Promise<void> {
    for (let index = 0; index < rows.length; index++) {
      const row: BackupWord = rows[index];
      await DatabaseService.executeSqlThrow(
        'INSERT INTO words(id, word, phonetic, part_of_speech, pronunciation_url, translation, example, book_id, difficulty, created_at) ' +
          'VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [row.id, row.word, row.phonetic, row.part_of_speech, row.pronunciation_url, row.translation, row.example,
          row.book_id, row.difficulty, row.created_at]
      );
    }
  }

  private static async insertStudyRecords(rows: BackupStudyRecord[]): Promise<void> {
    for (let index = 0; index < rows.length; index++) {
      const row: BackupStudyRecord = rows[index];
      await DatabaseService.executeSqlThrow(
        'INSERT INTO study_record(id, word_id, correct_count, wrong_count, last_review_time, next_review_time, interval_days, ease_factor, mastered) ' +
          'VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [row.id, row.word_id, row.correct_count, row.wrong_count, row.last_review_time, row.next_review_time,
          row.interval_days, row.ease_factor, row.mastered]
      );
    }
  }

  private static async insertStudyDaily(rows: BackupStudyDaily[]): Promise<void> {
    for (let index = 0; index < rows.length; index++) {
      const row: BackupStudyDaily = rows[index];
      await DatabaseService.executeSqlThrow(
        'INSERT INTO study_daily(id, date, learn_count, review_count, correct_count, wrong_count, duration) VALUES(?, ?, ?, ?, ?, ?, ?)',
        [row.id, row.date, row.learn_count, row.review_count, row.correct_count, row.wrong_count, row.duration]
      );
    }
  }

  private static async insertStudyEvents(rows: BackupStudyEvent[]): Promise<void> {
    for (let index = 0; index < rows.length; index++) {
      const row: BackupStudyEvent = rows[index];
      await DatabaseService.executeSqlThrow(
        'INSERT INTO study_event(id, date, word_id, scene, correct, created_at) VALUES(?, ?, ?, ?, ?, ?)',
        [row.id, row.date, row.word_id, row.scene, row.correct, row.created_at]
      );
    }
  }

  private static async insertStudySessions(rows: BackupStudySession[]): Promise<void> {
    for (let index = 0; index < rows.length; index++) {
      const row: BackupStudySession = rows[index];
      await DatabaseService.executeSqlThrow(
        'INSERT INTO study_session(id, date, start_time, end_time, duration, scene, word_count) VALUES(?, ?, ?, ?, ?, ?, ?)',
        [row.id, row.date, row.start_time, row.end_time, row.duration, row.scene, row.word_count]
      );
    }
  }
}
