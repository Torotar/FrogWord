import { relationalStore } from '@kit.ArkData';
import { Word } from '../model/Word';
import { DueReviewWord } from '../model/DueReviewWord';
import { StudyStats } from '../model/StudyStats';
import { DatabaseService } from './DatabaseService';
import { DateUtil } from '../utils/DateUtil';

export class WordService {
  public static async getUnmasteredWords(limit: number): Promise<Word[]> {
    const sql: string =
      'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
      'FROM words w LEFT JOIN study_record sr ON w.id = sr.word_id ' +
      'WHERE sr.word_id IS NULL ' +
      'ORDER BY w.id ASC LIMIT ?';
    return await WordService.queryWords(sql, [limit]);
  }

  public static async getAllUnmasteredWords(bookId: number = 0): Promise<Word[]> {
    const hb: boolean = bookId > 0;
    const sql: string = hb
      ? 'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w LEFT JOIN study_record sr ON w.id = sr.word_id ' +
        'WHERE IFNULL(sr.mastered, 0) = 0 AND w.book_id = ? ' +
        'ORDER BY LOWER(w.word) ASC'
      : 'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w LEFT JOIN study_record sr ON w.id = sr.word_id ' +
        'WHERE IFNULL(sr.mastered, 0) = 0 ' +
        'ORDER BY LOWER(w.word) ASC';
    return await WordService.queryWords(sql, hb ? [bookId] : []);
  }

  public static async getUnmasteredWordsByBookId(bookId: number, limit: number): Promise<Word[]> {
    const sql: string =
      'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
      'FROM words w LEFT JOIN study_record sr ON w.id = sr.word_id ' +
      'WHERE sr.word_id IS NULL AND w.book_id = ? ' +
      'ORDER BY LOWER(w.word) ASC, w.id ASC LIMIT ?';
    return await WordService.queryWords(sql, [bookId, limit]);
  }

  public static async getRandomUnmasteredWordsByBookId(bookId: number): Promise<Word[]> {
    const sql: string =
      'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
      'FROM words w LEFT JOIN study_record sr ON w.id = sr.word_id ' +
      'WHERE sr.word_id IS NULL AND w.book_id = ? ' +
      'ORDER BY RANDOM()';
    return await WordService.queryWords(sql, [bookId]);
  }

  public static async getDueReviewWords(): Promise<Word[]> {
    const sql: string =
      'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
      'FROM words w INNER JOIN study_record sr ON w.id = sr.word_id ' +
      'WHERE sr.mastered = 0 AND sr.next_review_time > 0 AND sr.next_review_time <= ? ' +
      'ORDER BY sr.next_review_time ASC, LOWER(w.word) ASC';
    return await WordService.queryWords(sql, [Date.now()]);
  }

  /**
   * 获取带学习记录详情的待复习单词列表
   */
  public static async getDueReviewWordDetails(): Promise<DueReviewWord[]> {
    const sql: string =
      'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at, ' +
      'sr.last_review_time, sr.next_review_time, sr.correct_count, sr.wrong_count, sr.interval_days, sr.ease_factor, sr.mastered ' +
      'FROM words w INNER JOIN study_record sr ON w.id = sr.word_id ' +
      'ORDER BY sr.mastered ASC, sr.next_review_time ASC, LOWER(w.word) ASC';
    return await WordService.queryDueReviewWords(sql, []);
  }

  public static async getDueReviewWordDetailsByBookId(bookId: number): Promise<DueReviewWord[]> {
    const sql: string =
      'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at, ' +
      'sr.last_review_time, sr.next_review_time, sr.correct_count, sr.wrong_count, sr.interval_days, sr.ease_factor, sr.mastered ' +
      'FROM words w INNER JOIN study_record sr ON w.id = sr.word_id ' +
      'WHERE w.book_id = ? ' +
      'ORDER BY sr.mastered ASC, sr.next_review_time ASC, LOWER(w.word) ASC';
    return await WordService.queryDueReviewWords(sql, [bookId]);
  }

  public static async getDueReviewWordsByBookId(bookId: number): Promise<Word[]> {
    const sql: string =
      'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
      'FROM words w INNER JOIN study_record sr ON w.id = sr.word_id ' +
      'WHERE sr.mastered = 0 AND sr.next_review_time > 0 AND sr.next_review_time <= ? AND w.book_id = ? ' +
      'ORDER BY sr.next_review_time ASC, LOWER(w.word) ASC';
    return await WordService.queryWords(sql, [Date.now(), bookId]);
  }

  public static async getStats(bookId: number = 0): Promise<StudyStats> {
    const hb: boolean = bookId > 0;
    const b: relationalStore.ValueType[] = [bookId];
    console.info('getStats called with bookId=' + bookId.toString() + ', hb=' + hb.toString());

    // 未选择词书时返回全零统计
    if (!hb) {
      return {
        todayLearnCount: 0,
        todayReviewCount: 0,
        todayCorrectCount: 0,
        todayWrongCount: 0,
        pendingReviewCount: 0,
        unknownWordCount: 0,
        masteredCount: 0,
        totalWordCount: 0,
        unmasteredCount: 0,
        inLearningCount: 0,
        totalCorrectCount: 0,
        totalWrongCount: 0,
        accuracyRate: 0,
        studyDuration: 0
      };
    }

    // Verify book exists and has words
    const wordCount: number = await WordService.queryCount(
      'SELECT COUNT(*) AS count FROM words WHERE book_id = ?', b);
    console.info('getStats: words with book_id=' + bookId.toString() + ' = ' + wordCount.toString());

    const t: relationalStore.ValueType[] = [DateUtil.todayKey()];

    const todayLearnCount: number = await WordService.queryCount(
      'SELECT IFNULL(SUM(learn_count), 0) AS count FROM study_daily WHERE date = ?', t);
    const todayReviewCount: number = await WordService.queryCount(
      'SELECT IFNULL(SUM(review_count), 0) AS count FROM study_daily WHERE date = ?', t);
    const todayCorrectCount: number = await WordService.queryCount(
      'SELECT IFNULL(SUM(correct_count), 0) AS count FROM study_daily WHERE date = ?', t);
    const todayWrongCount: number = await WordService.queryCount(
      'SELECT IFNULL(SUM(wrong_count), 0) AS count FROM study_daily WHERE date = ?', t);

    const pendingReviewCount: number = await WordService.queryCount(
      'SELECT COUNT(*) AS count FROM study_record sr INNER JOIN words w ON sr.word_id = w.id WHERE w.book_id = ? AND sr.mastered = 0 AND sr.next_review_time > 0 AND sr.next_review_time <= ?',
      [bookId, Date.now()]
    );

    const unknownWordCount: number = await WordService.queryCount(
      'SELECT COUNT(*) AS count FROM study_record sr INNER JOIN words w ON sr.word_id = w.id WHERE w.book_id = ? AND sr.mastered = 0 AND sr.wrong_count > 0',
      b
    );

    const masteredCount: number = await WordService.queryCount(
      'SELECT COUNT(*) AS count FROM study_record sr INNER JOIN words w ON sr.word_id = w.id WHERE w.book_id = ? AND sr.mastered = 1',
      b
    );

    const totalWordCount: number = await WordService.queryCount(
      'SELECT COUNT(*) AS count FROM words WHERE book_id = ?', b
    );

    const unmasteredCount: number = await WordService.queryCount(
      'SELECT COUNT(*) AS count FROM words w LEFT JOIN study_record sr ON w.id = sr.word_id WHERE w.book_id = ? AND IFNULL(sr.mastered, 0) = 0',
      b
    );

    const inLearningCount: number = await WordService.queryCount(
      'SELECT COUNT(*) AS count FROM study_record sr INNER JOIN words w ON sr.word_id = w.id WHERE w.book_id = ? AND sr.mastered = 0 AND sr.wrong_count = 0',
      b
    );

    const totalCorrectCount: number = await WordService.queryCount(
      'SELECT IFNULL(SUM(sr.correct_count), 0) AS count FROM study_record sr INNER JOIN words w ON sr.word_id = w.id WHERE w.book_id = ?',
      b
    );

    const totalWrongCount: number = await WordService.queryCount(
      'SELECT IFNULL(SUM(sr.wrong_count), 0) AS count FROM study_record sr INNER JOIN words w ON sr.word_id = w.id WHERE w.book_id = ?',
      b
    );

    return {
      todayLearnCount,
      todayReviewCount,
      todayCorrectCount,
      todayWrongCount,
      pendingReviewCount,
      unknownWordCount,
      masteredCount,
      totalWordCount,
      unmasteredCount,
      inLearningCount,
      totalCorrectCount,
      totalWrongCount,
      accuracyRate: 0,
      studyDuration: 0
    };
  }

  public static async searchWords(keyword: string): Promise<Word[]> {
    const trimmedKeyword: string = keyword.trim();
    if (trimmedKeyword.length === 0) {
      return [];
    }

    const likeKeyword: string = '%' + trimmedKeyword + '%';
    const sql: string =
      'SELECT id, word, phonetic, part_of_speech, pronunciation_url, translation, example, book_id, difficulty, created_at FROM words ' +
      'WHERE word LIKE ? OR translation LIKE ? ORDER BY word ASC LIMIT 50';
    return await WordService.queryWords(sql, [likeKeyword, likeKeyword]);
  }

  public static async getWordById(id: number): Promise<Word | null> {
    const words: Word[] = await WordService.queryWords(
      'SELECT id, word, phonetic, part_of_speech, pronunciation_url, translation, example, book_id, difficulty, created_at FROM words WHERE id = ? LIMIT 1',
      [id]
    );
    return words.length > 0 ? words[0] : null;
  }

  public static async getWordsByBookId(bookId: number): Promise<Word[]> {
    return await WordService.queryWords(
      'SELECT id, word, phonetic, part_of_speech, pronunciation_url, translation, example, book_id, difficulty, created_at FROM words ' +
        'WHERE book_id = ? ORDER BY LOWER(word) ASC',
      [bookId]
    );
  }

  public static async getAllWords(limit: number = 200, bookId: number = 0): Promise<Word[]> {
    const hb: boolean = bookId > 0;
    const sql: string = hb
      ? 'SELECT id, word, phonetic, part_of_speech, pronunciation_url, translation, example, book_id, difficulty, created_at FROM words WHERE book_id = ? ORDER BY LOWER(word) ASC LIMIT ?'
      : 'SELECT id, word, phonetic, part_of_speech, pronunciation_url, translation, example, book_id, difficulty, created_at FROM words ORDER BY LOWER(word) ASC LIMIT ?';
    return await WordService.queryWords(sql, hb ? [bookId, limit] : [limit]);
  }

  // 从未学习过的单词（没有 study_record）
  public static async getUnstudiedWords(): Promise<Word[]> {
    return await WordService.queryWords(
      'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w LEFT JOIN study_record sr ON w.id = sr.word_id ' +
        'WHERE sr.word_id IS NULL ORDER BY LOWER(w.word) ASC',
      []
    );
  }

  // 按词书获取从未学习过的单词
  public static async getUnstudiedWordsByBookId(bookId: number): Promise<Word[]> {
    return await WordService.queryWords(
      'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w LEFT JOIN study_record sr ON w.id = sr.word_id ' +
        'WHERE sr.word_id IS NULL AND w.book_id = ? ORDER BY LOWER(w.word) ASC',
      [bookId]
    );
  }

  public static async getMasteredWords(bookId: number = 0): Promise<Word[]> {
    const hb: boolean = bookId > 0;
    const sql: string = hb
      ? 'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w INNER JOIN study_record sr ON w.id = sr.word_id WHERE sr.mastered = 1 AND w.book_id = ? ORDER BY LOWER(w.word) ASC'
      : 'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w INNER JOIN study_record sr ON w.id = sr.word_id WHERE sr.mastered = 1 ORDER BY LOWER(w.word) ASC';
    return await WordService.queryWords(sql, hb ? [bookId] : []);
  }

  public static async getPendingReviewWords(bookId: number = 0): Promise<Word[]> {
    const hb: boolean = bookId > 0;
    const sql: string = hb
      ? 'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w INNER JOIN study_record sr ON w.id = sr.word_id ' +
        'WHERE sr.mastered = 0 AND sr.next_review_time > 0 AND sr.next_review_time <= ? AND w.book_id = ? ' +
        'ORDER BY sr.next_review_time ASC, LOWER(w.word) ASC'
      : 'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w INNER JOIN study_record sr ON w.id = sr.word_id ' +
        'WHERE sr.mastered = 0 AND sr.next_review_time > 0 AND sr.next_review_time <= ? ' +
        'ORDER BY sr.next_review_time ASC, LOWER(w.word) ASC';
    return await WordService.queryWords(sql, hb ? [Date.now(), bookId] : [Date.now()]);
  }

  public static async getTodayEventWords(scene: string, bookId: number = 0): Promise<Word[]> {
    const hb: boolean = bookId > 0;
    const eventSql: string = hb
      ? 'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w INNER JOIN study_event se ON w.id = se.word_id WHERE se.date = ? AND se.scene = ? AND w.book_id = ? ' +
        'GROUP BY w.id ORDER BY LOWER(w.word) ASC LIMIT 100'
      : 'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w INNER JOIN study_event se ON w.id = se.word_id WHERE se.date = ? AND se.scene = ? ' +
        'GROUP BY w.id ORDER BY LOWER(w.word) ASC LIMIT 100';
    const eventArgs: relationalStore.ValueType[] = hb ? [DateUtil.todayKey(), scene, bookId] : [DateUtil.todayKey(), scene];
    const eventWords: Word[] = await WordService.queryWords(eventSql, eventArgs);
    if (eventWords.length > 0 || scene !== 'learn') {
      return eventWords;
    }

    const compatSql: string = hb
      ? 'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w INNER JOIN study_record sr ON w.id = sr.word_id WHERE sr.last_review_time >= ? AND w.book_id = ? ' +
        'ORDER BY LOWER(w.word) ASC LIMIT 100'
      : 'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w INNER JOIN study_record sr ON w.id = sr.word_id WHERE sr.last_review_time >= ? ' +
        'ORDER BY LOWER(w.word) ASC LIMIT 100';
    return await WordService.queryWords(compatSql, hb ? [DateUtil.todayStartTimestamp(), bookId] : [DateUtil.todayStartTimestamp()]);
  }

  public static async getEventWordsByScene(scene: string, bookId: number = 0): Promise<Word[]> {
    const hb: boolean = bookId > 0;
    const eventSql: string = hb
      ? 'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w INNER JOIN study_event se ON w.id = se.word_id WHERE se.scene = ? AND w.book_id = ? ' +
        'GROUP BY w.id ORDER BY LOWER(w.word) ASC LIMIT 100'
      : 'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w INNER JOIN study_event se ON w.id = se.word_id WHERE se.scene = ? ' +
        'GROUP BY w.id ORDER BY LOWER(w.word) ASC LIMIT 100';
    const eventWords: Word[] = await WordService.queryWords(eventSql, hb ? [scene, bookId] : [scene]);
    if (eventWords.length > 0 || scene !== 'learn') {
      return eventWords;
    }

    const compatSql: string = hb
      ? 'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w INNER JOIN study_record sr ON w.id = sr.word_id WHERE sr.last_review_time > 0 AND w.book_id = ? ' +
        'ORDER BY LOWER(w.word) ASC LIMIT 100'
      : 'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w INNER JOIN study_record sr ON w.id = sr.word_id WHERE sr.last_review_time > 0 ' +
        'ORDER BY LOWER(w.word) ASC LIMIT 100';
    return await WordService.queryWords(compatSql, hb ? [bookId] : []);
  }

  public static async getRecentStudiedWords(limit: number = 20, bookId: number = 0): Promise<Word[]> {
    const hb: boolean = bookId > 0;
    const sql: string = hb
      ? 'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w INNER JOIN study_event se ON w.id = se.word_id WHERE w.book_id = ? GROUP BY w.id ORDER BY MAX(se.created_at) DESC LIMIT ?'
      : 'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w INNER JOIN study_event se ON w.id = se.word_id GROUP BY w.id ORDER BY MAX(se.created_at) DESC LIMIT ?';
    return await WordService.queryWords(sql, hb ? [bookId, limit] : [limit]);
  }

  public static async existsWordInBook(word: string, bookId: number): Promise<boolean> {
    const count: number = await WordService.queryCount(
      'SELECT COUNT(*) AS count FROM words WHERE word = ? AND book_id = ?',
      [word, bookId]
    );
    return count > 0;
  }

  public static async insertWord(word: string, phonetic: string, translation: string, example: string, bookId: number, difficulty: number): Promise<void> {
    try {
      await DatabaseService.getStore().executeSql(
        'INSERT INTO words(word, phonetic, part_of_speech, pronunciation_url, translation, example, book_id, difficulty, created_at) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [word, phonetic, '', '', translation, example, bookId, difficulty, Date.now()]
      );
      console.info('insertWord success word=' + word + ', bookId=' + bookId.toString());
    } catch (error) {
      console.error('insertWord failed: ' + JSON.stringify(error));
    }
  }

  public static async insertWordAndReturnResult(
    word: string,
    phonetic: string,
    translation: string,
    example: string,
    bookId: number,
    difficulty: number
  ): Promise<boolean> {
    try {
      await DatabaseService.getStore().executeSql(
        'INSERT INTO words(word, phonetic, part_of_speech, pronunciation_url, translation, example, book_id, difficulty, created_at) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [word, phonetic, '', '', translation, example, bookId, difficulty, Date.now()]
      );
      return true;
    } catch (error) {
      console.error('insertWordAndReturnResult failed word=' + word + ', error=' + JSON.stringify(error));
      return false;
    }
  }

  public static async getUnknownWords(bookId: number = 0): Promise<Word[]> {
    const hb: boolean = bookId > 0;
    const sql: string = hb
      ? 'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w INNER JOIN study_record sr ON w.id = sr.word_id ' +
        'WHERE sr.mastered = 0 AND sr.wrong_count > 0 AND w.book_id = ? ORDER BY LOWER(w.word) ASC'
      : 'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w INNER JOIN study_record sr ON w.id = sr.word_id ' +
        'WHERE sr.mastered = 0 AND sr.wrong_count > 0 ORDER BY LOWER(w.word) ASC';
    return await WordService.queryWords(sql, hb ? [bookId] : []);
  }

  public static async getWordsByStatType(type: string, bookId: number = 0): Promise<Word[]> {
    if (type === 'learnToday') {
      return await WordService.getEventWordsByScene('learn', bookId);
    }
    if (type === 'reviewToday') {
      return await WordService.getEventWordsByScene('review', bookId);
    }
    if (type === 'pendingReview') {
      return await WordService.getPendingReviewWords(bookId);
    }
    if (type === 'mastered') {
      return await WordService.getMasteredWords(bookId);
    }
    if (type === 'unknown') {
      return await WordService.getUnknownWords(bookId);
    }
    if (type === 'recent') {
      return await WordService.getRecentStudiedWords(30, bookId);
    }
    if (type === 'unmastered') {
      return await WordService.getAllUnmasteredWords(bookId);
    }
    if (type === 'unstudied') {
      return bookId > 0 ? await WordService.getUnstudiedWordsByBookId(bookId) : await WordService.getUnstudiedWords();
    }
    return await WordService.getAllWords(200, bookId);
  }

  // 按时段 + 统计类型获取单词
  public static async getWordsByPeriod(type: string, startDate: string, endDate: string, bookId: number = 0): Promise<Word[]> {
    if (type === 'mastered') {
      return await WordService.getPeriodMasteredWords(startDate, endDate, bookId);
    }
    if (type === 'unknown') {
      return await WordService.getPeriodUnknownWords(startDate, endDate, bookId);
    }
    if (type === 'pendingReview') {
      return await WordService.getPeriodPendingReviewWords(startDate, endDate, bookId);
    }
    if (type === 'recent') {
      return await WordService.getPeriodEventWords(startDate, endDate, bookId);
    }
    if (type === 'unmastered') {
      return await WordService.getPeriodUnmasteredWords(startDate, endDate, bookId);
    }
    if (type === 'unstudied') {
      return bookId > 0 ? await WordService.getUnstudiedWordsByBookId(bookId) : await WordService.getUnstudiedWords();
    }
    if (type === 'learnToday' || type === 'reviewToday') {
      return await WordService.getPeriodEventWordsByScene(startDate, endDate, type === 'learnToday' ? 'learn' : 'review', bookId);
    }
    return await WordService.getAllWords(200, bookId);
  }

  private static async getPeriodEventWords(startDate: string, endDate: string, bookId: number = 0): Promise<Word[]> {
    const hb: boolean = bookId > 0;
    const sql: string = hb
      ? 'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w INNER JOIN study_event se ON w.id = se.word_id WHERE se.date >= ? AND se.date <= ? AND w.book_id = ? ' +
        'GROUP BY w.id ORDER BY LOWER(w.word) ASC LIMIT 100'
      : 'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w INNER JOIN study_event se ON w.id = se.word_id WHERE se.date >= ? AND se.date <= ? ' +
        'GROUP BY w.id ORDER BY LOWER(w.word) ASC LIMIT 100';
    return await WordService.queryWords(sql, hb ? [startDate, endDate, bookId] : [startDate, endDate]);
  }

  // 按场景和时间段获取去重单词（用于 learnToday / reviewToday 的时间栏过滤）
  private static async getPeriodEventWordsByScene(startDate: string, endDate: string, scene: string, bookId: number = 0): Promise<Word[]> {
    const hb: boolean = bookId > 0;
    const sql: string = hb
      ? 'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w INNER JOIN study_event se ON w.id = se.word_id ' +
        'WHERE se.date >= ? AND se.date <= ? AND se.scene = ? AND w.book_id = ? ' +
        'GROUP BY w.id ORDER BY LOWER(w.word) ASC LIMIT 100'
      : 'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w INNER JOIN study_event se ON w.id = se.word_id ' +
        'WHERE se.date >= ? AND se.date <= ? AND se.scene = ? ' +
        'GROUP BY w.id ORDER BY LOWER(w.word) ASC LIMIT 100';
    return await WordService.queryWords(sql, hb ? [startDate, endDate, scene, bookId] : [startDate, endDate, scene]);
  }

  // 获取时段内真正达到已掌握状态的单词，对齐统计页 masteredCount
  private static async getPeriodMasteredWords(startDate: string, endDate: string, bookId: number = 0): Promise<Word[]> {
    const hb: boolean = bookId > 0;
    const startTime: number = new Date(startDate + ' 00:00:00').getTime();
    const endTime: number = new Date(endDate + ' 23:59:59').getTime();
    const sql: string = hb
      ? 'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w INNER JOIN study_record sr ON w.id = sr.word_id ' +
        'WHERE sr.last_review_time >= ? AND sr.last_review_time <= ? AND sr.mastered = 1 AND w.book_id = ? ' +
        'ORDER BY LOWER(w.word) ASC LIMIT 100'
      : 'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w INNER JOIN study_record sr ON w.id = sr.word_id ' +
        'WHERE sr.last_review_time >= ? AND sr.last_review_time <= ? AND sr.mastered = 1 ' +
        'ORDER BY LOWER(w.word) ASC LIMIT 100';
    return await WordService.queryWords(sql, hb ? [startTime, endTime, bookId] : [startTime, endTime]);
  }

  // 获取时段内标记为"不认识"(错误) 的单词 — 对应"不认识日"
  private static async getPeriodUnknownWords(startDate: string, endDate: string, bookId: number = 0): Promise<Word[]> {
    const hb: boolean = bookId > 0;
    const sql: string = hb
      ? 'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w INNER JOIN study_event se ON w.id = se.word_id ' +
        'WHERE se.date >= ? AND se.date <= ? AND se.correct = 0 AND w.book_id = ? ' +
        'GROUP BY w.id ORDER BY LOWER(w.word) ASC LIMIT 100'
      : 'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w INNER JOIN study_event se ON w.id = se.word_id ' +
        'WHERE se.date >= ? AND se.date <= ? AND se.correct = 0 ' +
        'GROUP BY w.id ORDER BY LOWER(w.word) ASC LIMIT 100';
    return await WordService.queryWords(sql, hb ? [startDate, endDate, bookId] : [startDate, endDate]);
  }

  // 获取时段内待复习的单词 — 对应"待复习日"
  private static async getPeriodPendingReviewWords(startDate: string, endDate: string, bookId: number = 0): Promise<Word[]> {
    const hb: boolean = bookId > 0;
    const sql: string = hb
      ? 'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w INNER JOIN study_event se ON w.id = se.word_id ' +
        'INNER JOIN study_record sr ON w.id = sr.word_id ' +
        'WHERE se.date >= ? AND se.date <= ? AND sr.mastered = 0 AND sr.next_review_time > 0 AND sr.next_review_time <= ? AND w.book_id = ? ' +
        'GROUP BY w.id ORDER BY LOWER(w.word) ASC LIMIT 100'
      : 'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w INNER JOIN study_event se ON w.id = se.word_id ' +
        'INNER JOIN study_record sr ON w.id = sr.word_id ' +
        'WHERE se.date >= ? AND se.date <= ? AND sr.mastered = 0 AND sr.next_review_time > 0 AND sr.next_review_time <= ? ' +
        'GROUP BY w.id ORDER BY LOWER(w.word) ASC LIMIT 100';
    return await WordService.queryWords(sql, hb ? [startDate, endDate, Date.now(), bookId] : [startDate, endDate, Date.now()]);
  }

  // 获取时段内未掌握的单词 — 对应"不认识"时段过滤
  private static async getPeriodUnmasteredWords(startDate: string, endDate: string, bookId: number = 0): Promise<Word[]> {
    const startTime: number = new Date(startDate + ' 00:00:00').getTime();
    const endTime: number = new Date(endDate + ' 23:59:59').getTime();
    const hb: boolean = bookId > 0;
    const sql: string = hb
      ? 'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w INNER JOIN study_record sr ON w.id = sr.word_id ' +
        'WHERE sr.last_review_time >= ? AND sr.last_review_time <= ? AND sr.mastered = 0 AND w.book_id = ? ' +
        'ORDER BY LOWER(w.word) ASC'
      : 'SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.pronunciation_url, w.translation, w.example, w.book_id, w.difficulty, w.created_at ' +
        'FROM words w INNER JOIN study_record sr ON w.id = sr.word_id ' +
        'WHERE sr.last_review_time >= ? AND sr.last_review_time <= ? AND sr.mastered = 0 ' +
        'ORDER BY LOWER(w.word) ASC';
    return await WordService.queryWords(sql, hb ? [startTime, endTime, bookId] : [startTime, endTime]);
  }


  private static async queryDueReviewWords(sql: string, bindArgs: relationalStore.ValueType[]): Promise<DueReviewWord[]> {
    const words: DueReviewWord[] = [];
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await DatabaseService.querySql(sql, bindArgs);
      while (resultSet.goToNextRow()) {
        words.push({
          id: resultSet.getLong(resultSet.getColumnIndex('id')),
          word: resultSet.getString(resultSet.getColumnIndex('word')),
          phonetic: resultSet.getString(resultSet.getColumnIndex('phonetic')),
          partOfSpeech: resultSet.getString(resultSet.getColumnIndex('part_of_speech')),
          pronunciationUrl: resultSet.getString(resultSet.getColumnIndex('pronunciation_url')),
          translation: resultSet.getString(resultSet.getColumnIndex('translation')),
          example: resultSet.getString(resultSet.getColumnIndex('example')),
          bookId: resultSet.getLong(resultSet.getColumnIndex('book_id')),
          difficulty: resultSet.getLong(resultSet.getColumnIndex('difficulty')),
          createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at')),
          lastReviewTime: resultSet.getLong(resultSet.getColumnIndex('last_review_time')),
          nextReviewTime: resultSet.getLong(resultSet.getColumnIndex('next_review_time')),
          correctCount: resultSet.getLong(resultSet.getColumnIndex('correct_count')),
          wrongCount: resultSet.getLong(resultSet.getColumnIndex('wrong_count')),
          intervalDays: resultSet.getLong(resultSet.getColumnIndex('interval_days')),
          easeFactor: resultSet.getDouble(resultSet.getColumnIndex('ease_factor')),
          mastered: resultSet.getLong(resultSet.getColumnIndex('mastered'))
        });
      }
    } catch (error) {
      console.error('queryDueReviewWords failed: ' + JSON.stringify(error));
    } finally {
      if (resultSet) {
        resultSet.close();
      }
    }
    return words;
  }

  private static async queryWords(sql: string, bindArgs: relationalStore.ValueType[]): Promise<Word[]> {
    const words: Word[] = [];
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await DatabaseService.querySql(sql, bindArgs);
      while (resultSet.goToNextRow()) {
        words.push({
          id: resultSet.getLong(resultSet.getColumnIndex('id')),
          word: resultSet.getString(resultSet.getColumnIndex('word')),
          phonetic: resultSet.getString(resultSet.getColumnIndex('phonetic')),
          partOfSpeech: resultSet.getString(resultSet.getColumnIndex('part_of_speech')),
          pronunciationUrl: resultSet.getString(resultSet.getColumnIndex('pronunciation_url')),
          translation: resultSet.getString(resultSet.getColumnIndex('translation')),
          example: resultSet.getString(resultSet.getColumnIndex('example')),
          bookId: resultSet.getLong(resultSet.getColumnIndex('book_id')),
          difficulty: resultSet.getLong(resultSet.getColumnIndex('difficulty')),
          createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at'))
        });
      }
    } catch (error) {
      console.error('queryWords failed: ' + JSON.stringify(error));
    } finally {
      if (resultSet) {
        resultSet.close();
      }
    }
    return words;
  }

  // 今日学习过的唯一单词数（所有 study_event ）
  public static async getTodayStudiedWords(): Promise<number> {
    return await WordService.queryCount(
      'SELECT COUNT(DISTINCT word_id) AS count FROM study_event WHERE date = ?',
      [DateUtil.todayKey()]
    );
  }

  /** 按词书统计有学习记录的单词数（与复习界面查询完全一致） */
  public static async getAllStudiedCountByBookId(bookId: number): Promise<number> {
    return await WordService.queryCount(
      'SELECT COUNT(*) AS count FROM words w INNER JOIN study_record sr ON w.id = sr.word_id WHERE w.book_id = ?',
      [bookId]
    );
  }

  /** 统计词书中今日已复习的单词数（与复习界面过滤一致） */
  public static async getTodayReviewedCountByBookId(bookId: number, reviewedIds: number[]): Promise<number> {
    if (reviewedIds.length === 0) {
      return 0;
    }
    const placeholders: string = reviewedIds.map(() => '?').join(',');
    const args: relationalStore.ValueType[] = [bookId, ...reviewedIds];
    return await WordService.queryCount(
      'SELECT COUNT(*) AS count FROM words w INNER JOIN study_record sr ON w.id = sr.word_id ' +
      'WHERE w.book_id = ? AND sr.word_id IN (' + placeholders + ')',
      args
    );
  }

  /** 按词书统计已复习且仍到期待复习的单词数（与待复习卡片逻辑一致） */
  public static async getReviewedOverdueCountByBookId(bookId: number, reviewedIds: number[]): Promise<number> {
    if (reviewedIds.length === 0) {
      return 0;
    }
    const placeholders: string = reviewedIds.map(() => '?').join(',');
    const args: relationalStore.ValueType[] = [bookId, ...reviewedIds, Date.now()];
    return await WordService.queryCount(
      'SELECT COUNT(*) AS count FROM study_record sr INNER JOIN words w ON sr.word_id = w.id ' +
      'WHERE w.book_id = ? AND sr.mastered = 0 AND sr.next_review_time > 0 ' +
      'AND sr.word_id IN (' + placeholders + ') AND sr.next_review_time <= ?',
      args
    );
  }

  // 今日"认识"(correct=1) 的唯一单词数
  public static async getTodayRecognizedWords(): Promise<number> {
    return await WordService.queryCount(
      'SELECT COUNT(DISTINCT word_id) AS count FROM study_event WHERE date = ? AND correct = 1',
      [DateUtil.todayKey()]
    );
  }

  // 今日"不认识"(correct=0) 的唯一单词数
  public static async getTodayUnrecognizedWords(): Promise<number> {
    return await WordService.queryCount(
      'SELECT COUNT(DISTINCT word_id) AS count FROM study_event WHERE date = ? AND correct = 0',
      [DateUtil.todayKey()]
    );
  }

  // 指定词书中从未学习过的单词数
  public static async getUnstudiedCountByBookId(bookId: number): Promise<number> {
    return await WordService.queryCount(
      'SELECT COUNT(*) AS count FROM words w LEFT JOIN study_record sr ON w.id = sr.word_id ' +
        'WHERE sr.word_id IS NULL AND w.book_id = ?',
      [bookId]
    );
  }

  private static async queryCount(sql: string, bindArgs: relationalStore.ValueType[] = []): Promise<number> {
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await DatabaseService.querySql(sql, bindArgs);
      if (resultSet.goToFirstRow()) {
        return resultSet.getLong(resultSet.getColumnIndex('count'));
      }
    } catch (error) {
      console.error('queryCount failed: ' + JSON.stringify(error));
    } finally {
      if (resultSet) {
        resultSet.close();
      }
    }
    return 0;
  }
}
