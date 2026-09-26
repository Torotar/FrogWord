import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { DEFAULT_WORDS } from '../data/DefaultWords';
import { Constants } from '../utils/Constants';
import { Word } from '../model/Word';

export class DatabaseService {
  private static store?: relationalStore.RdbStore;
  private static initialized: boolean = false;

  private static readonly STORE_CONFIG: relationalStore.StoreConfig = {
    name: Constants.DATABASE_NAME,
    securityLevel: relationalStore.SecurityLevel.S1
  };

  public static async init(context: common.Context): Promise<void> {
    if (DatabaseService.initialized && DatabaseService.store) {
      return;
    }

    try {
      DatabaseService.store = await relationalStore.getRdbStore(context, DatabaseService.STORE_CONFIG);
      if (DatabaseService.store.version < Constants.DATABASE_VERSION) {
        await DatabaseService.migrate(DatabaseService.store.version, Constants.DATABASE_VERSION);
        DatabaseService.store.version = Constants.DATABASE_VERSION;
      }
      await DatabaseService.createTables();
      await DatabaseService.initDefaultWords();
      DatabaseService.initialized = true;
      console.info('DatabaseService init success: ' + Constants.DATABASE_NAME);
    } catch (error) {
      console.error('DatabaseService init failed: ' + JSON.stringify(error));
    }
  }

  public static getStore(): relationalStore.RdbStore {
    if (!DatabaseService.store) {
      throw new Error('DatabaseService is not initialized');
    }
    return DatabaseService.store;
  }

  public static async querySql(sql: string, bindArgs: relationalStore.ValueType[] = []): Promise<relationalStore.ResultSet> {
    try {
      return await DatabaseService.getStore().querySql(sql, bindArgs);
    } catch (error) {
      console.error('querySql failed: ' + sql + ', error: ' + JSON.stringify(error));
      throw new Error('querySql failed: ' + JSON.stringify(error));
    }
  }

  public static async executeSql(sql: string, bindArgs: relationalStore.ValueType[] = []): Promise<void> {
    try {
      await DatabaseService.getStore().executeSql(sql, bindArgs);
    } catch (error) {
      console.error('executeSql failed: ' + sql + ', error: ' + JSON.stringify(error));
    }
  }

  /**
   * 执行 SQL，失败时抛出异常（不静默吞掉），用于关键写入操作
   */
  public static async executeSqlThrow(sql: string, bindArgs: relationalStore.ValueType[] = []): Promise<void> {
    await DatabaseService.getStore().executeSql(sql, bindArgs);
  }

  /**
   * 插入一行并返回自增 ID
   */
  public static async insert(table: string, values: relationalStore.ValuesBucket): Promise<number> {
    return await DatabaseService.getStore().insert(table, values);
  }

  static async migrate(oldVersion: number, newVersion: number): Promise<void> {
    if (oldVersion === 0) {
      // 新安装的数据库，createTables() 已包含最新结构，无需迁移
      return;
    }
    // v1 → v2: 为 study_daily 表添加 duration 列
    if (oldVersion < 2 && newVersion >= 2) {
      try {
        await DatabaseService.executeSql(
          'ALTER TABLE study_daily ADD COLUMN duration INTEGER DEFAULT 0'
        );
        console.info('Database migration v1->v2: added duration column to study_daily');
      } catch (error) {
        // 列可能已存在，忽略错误
        console.warn('Database migration v1->v2 (non-fatal): ' + JSON.stringify(error));
      }
    }
    // v2 → v3: 创建 study_session 表（学习时长分表）
    if (oldVersion < 3 && newVersion >= 3) {
      try {
        await DatabaseService.executeSql(
          'CREATE TABLE IF NOT EXISTS study_session (' +
            'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
            'date TEXT NOT NULL, ' +
            'start_time INTEGER NOT NULL, ' +
            'end_time INTEGER NOT NULL, ' +
            'duration INTEGER DEFAULT 0, ' +
            'scene TEXT NOT NULL, ' +
            'word_count INTEGER DEFAULT 0)'
        );
        console.info('Database migration v2->v3: created study_session table');
      } catch (error) {
        console.warn('Database migration v2->v3 (non-fatal): ' + JSON.stringify(error));
      }
    }
    if (oldVersion < 4 && newVersion >= 4) {
      try {
        await DatabaseService.executeSql(
          'ALTER TABLE words ADD COLUMN part_of_speech TEXT DEFAULT ""'
        );
        await DatabaseService.executeSql(
          'ALTER TABLE words ADD COLUMN pronunciation_url TEXT DEFAULT ""'
        );
        console.info('Database migration v3->v4: added word pronunciation metadata');
      } catch (error) {
        console.warn('Database migration v3->v4 (non-fatal): ' + JSON.stringify(error));
      }
    }
  }

  private static async createTables(): Promise<void> {
    await DatabaseService.executeSql(
      'CREATE TABLE IF NOT EXISTS word_book (' +
        'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
        'name TEXT NOT NULL, ' +
        'description TEXT, ' +
        'total_count INTEGER DEFAULT 0, ' +
        'created_at INTEGER)'
    );

    await DatabaseService.executeSql(
      'CREATE TABLE IF NOT EXISTS words (' +
        'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
        'word TEXT NOT NULL, ' +
        'phonetic TEXT, ' +
        'part_of_speech TEXT, ' +
        'pronunciation_url TEXT, ' +
        'translation TEXT NOT NULL, ' +
        'example TEXT, ' +
        'book_id INTEGER, ' +
        'difficulty INTEGER DEFAULT 1, ' +
        'created_at INTEGER)'
    );

    await DatabaseService.executeSql(
      'CREATE TABLE IF NOT EXISTS study_record (' +
        'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
        'word_id INTEGER NOT NULL, ' +
        'correct_count INTEGER DEFAULT 0, ' +
        'wrong_count INTEGER DEFAULT 0, ' +
        'last_review_time INTEGER DEFAULT 0, ' +
        'next_review_time INTEGER DEFAULT 0, ' +
        'interval_days INTEGER DEFAULT 1, ' +
        'ease_factor REAL DEFAULT 2.5, ' +
        'mastered INTEGER DEFAULT 0)'
    );

    await DatabaseService.executeSql(
      'CREATE TABLE IF NOT EXISTS study_daily (' +
        'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
        'date TEXT NOT NULL, ' +
        'learn_count INTEGER DEFAULT 0, ' +
        'review_count INTEGER DEFAULT 0, ' +
        'correct_count INTEGER DEFAULT 0, ' +
        'wrong_count INTEGER DEFAULT 0, ' +
        'duration INTEGER DEFAULT 0)'
    );

    await DatabaseService.executeSql(
      'CREATE TABLE IF NOT EXISTS study_event (' +
        'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
        'date TEXT NOT NULL, ' +
        'word_id INTEGER NOT NULL, ' +
        'scene TEXT NOT NULL, ' +
        'correct INTEGER DEFAULT 0, ' +
        'created_at INTEGER)'
    );

    await DatabaseService.executeSql(
      'CREATE TABLE IF NOT EXISTS study_session (' +
        'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
        'date TEXT NOT NULL, ' +
        'start_time INTEGER NOT NULL, ' +
        'end_time INTEGER NOT NULL, ' +
        'duration INTEGER DEFAULT 0, ' +
        'scene TEXT NOT NULL, ' +
        'word_count INTEGER DEFAULT 0)'
    );
  }

  private static async initDefaultWords(): Promise<void> {
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await DatabaseService.querySql('SELECT COUNT(*) AS count FROM words');
      let count: number = 0;
      if (resultSet.goToFirstRow()) {
        count = resultSet.getLong(resultSet.getColumnIndex('count'));
      }

      if (count > 0) {
        console.info('Default words already initialized, count=' + count.toString());
        return;
      }

      const now: number = Date.now();
      await DatabaseService.executeSql(
        'INSERT INTO word_book(id, name, description, total_count, created_at) VALUES(?, ?, ?, ?, ?)',
        [1, '默认词库', 'WordFlow 内置常用英语词库', DEFAULT_WORDS.length, now]
      );

      for (let index: number = 0; index < DEFAULT_WORDS.length; index++) {
        const word: Word = DEFAULT_WORDS[index];
        await DatabaseService.executeSql(
          'INSERT INTO words(id, word, phonetic, part_of_speech, pronunciation_url, translation, example, book_id, difficulty, created_at) ' +
            'VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
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
            now
          ]
        );
      }
      console.info('Default words initialized, count=' + DEFAULT_WORDS.length.toString());
    } catch (error) {
      console.error('initDefaultWords failed: ' + JSON.stringify(error));
    } finally {
      if (resultSet) {
        resultSet.close();
      }
    }
  }
}
