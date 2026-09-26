import { relationalStore } from '@kit.ArkData';
import { SpacedRepetition, ReviewSchedule } from '../algorithm/SpacedRepetition';
import { StudyRecord } from '../model/StudyRecord';
import { Word } from '../model/Word';
import { DateUtil } from '../utils/DateUtil';
import { DatabaseService } from './DatabaseService';
import { PreferencesService } from './PreferencesService';

export type StudyScene = 'learn' | 'review' | 'spell';

export class StudyRecordService {
  public static async recordLearned(word: Word, elapsedSeconds: number = 0, countAccuracy: boolean = true): Promise<void> {
    try {
      const oldRecord: StudyRecord = await StudyRecordService.getOrCreateRecord(word.id);
      const nextIntervalDays: number = Math.max(1, oldRecord.intervalDays);
      await DatabaseService.executeSql(
        'UPDATE study_record SET last_review_time = ?, next_review_time = ?, interval_days = ?, mastered = 0 WHERE word_id = ?',
        [
          Date.now(),
          DateUtil.addDaysTimestamp(nextIntervalDays),
          nextIntervalDays,
          word.id
        ]
      );

      if (countAccuracy) {
        await StudyRecordService.increaseDaily('learn', true, elapsedSeconds);
      } else {
        await StudyRecordService.increaseDailyLearnOnly(elapsedSeconds);
      }
      await StudyRecordService.insertStudyEvent(word.id, 'learn', true);
      console.info('recordLearned success wordId=' + word.id.toString());
    } catch (error) {
      console.error('recordLearned failed: ' + JSON.stringify(error));
    }
  }

  public static async recordAnswer(word: Word, isCorrect: boolean, scene: StudyScene, elapsedSeconds: number = 0): Promise<void> {
    try {
      const oldRecord: StudyRecord = await StudyRecordService.getOrCreateRecord(word.id);
      const correctCount: number = oldRecord.correctCount + (isCorrect ? 1 : 0);
      const wrongCount: number = oldRecord.wrongCount + (isCorrect ? 0 : 1);
      const schedule: ReviewSchedule = SpacedRepetition.calculate(
        isCorrect,
        oldRecord.intervalDays,
        oldRecord.easeFactor,
        correctCount,
        wrongCount,
        await PreferencesService.getForgettingCoefficient()
      );

      await DatabaseService.executeSql(
        'UPDATE study_record SET correct_count = ?, wrong_count = ?, last_review_time = ?, ' +
          'next_review_time = ?, interval_days = ?, ease_factor = ?, mastered = ? WHERE word_id = ?',
        [
          correctCount,
          wrongCount,
          Date.now(),
          schedule.nextReviewTime,
          schedule.nextIntervalDays,
          schedule.nextEaseFactor,
          schedule.mastered ? 1 : 0,
          word.id
        ]
      );

      await StudyRecordService.increaseDaily(scene, isCorrect, elapsedSeconds);
      await StudyRecordService.insertStudyEvent(word.id, scene, isCorrect);
      console.info('recordAnswer success wordId=' + word.id.toString() + ', scene=' + scene);
    } catch (error) {
      console.error('recordAnswer failed: ' + JSON.stringify(error));
    }
  }

  public static async recordSpellingAnswer(word: Word, isCorrect: boolean, elapsedSeconds: number = 0): Promise<void> {
    try {
      const oldRecord: StudyRecord = await StudyRecordService.getOrCreateRecord(word.id);
      const correctCount: number = oldRecord.correctCount + (isCorrect ? 1 : 0);
      const wrongCount: number = oldRecord.wrongCount + (isCorrect ? 0 : 1);
      const schedule: ReviewSchedule = SpacedRepetition.calculate(
        isCorrect,
        oldRecord.intervalDays,
        oldRecord.easeFactor,
        correctCount,
        wrongCount,
        await PreferencesService.getForgettingCoefficient()
      );

      await DatabaseService.executeSql(
        'UPDATE study_record SET correct_count = ?, wrong_count = ?, last_review_time = ?, ' +
          'next_review_time = ?, interval_days = ?, ease_factor = ?, mastered = ? WHERE word_id = ?',
        [
          correctCount,
          wrongCount,
          Date.now(),
          schedule.nextReviewTime,
          schedule.nextIntervalDays,
          schedule.nextEaseFactor,
          schedule.mastered ? 1 : 0,
          word.id
        ]
      );

      await StudyRecordService.increaseDailyAccuracy(isCorrect, elapsedSeconds);
      await StudyRecordService.insertStudyEvent(word.id, 'spell', isCorrect);
      console.info('recordSpellingAnswer success wordId=' + word.id.toString());
    } catch (error) {
      console.error('recordSpellingAnswer failed: ' + JSON.stringify(error));
    }
  }

  public static async getRecordByWordId(wordId: number): Promise<StudyRecord | null> {
    return await StudyRecordService.getRecord(wordId);
  }

  public static async markMastered(wordId: number): Promise<void> {
    try {
      await StudyRecordService.getOrCreateRecord(wordId);
      await DatabaseService.executeSql(
        'UPDATE study_record SET mastered = 1, next_review_time = 0 WHERE word_id = ?',
        [wordId]
      );
      console.info('markMastered success wordId=' + wordId.toString());
    } catch (error) {
      console.error('markMastered failed: ' + JSON.stringify(error));
    }
  }

  public static async resetRecord(wordId: number): Promise<void> {
    try {
      await DatabaseService.executeSql('DELETE FROM study_record WHERE word_id = ?', [wordId]);
      await DatabaseService.executeSql('DELETE FROM study_event WHERE word_id = ?', [wordId]);
      console.info('resetRecord success wordId=' + wordId.toString());
    } catch (error) {
      console.error('resetRecord failed: ' + JSON.stringify(error));
    }
  }

  public static async resetRecordsByBookId(bookId: number): Promise<void> {
    try {
      await DatabaseService.executeSql(
        'DELETE FROM study_record WHERE word_id IN (SELECT id FROM words WHERE book_id = ?)',
        [bookId]
      );
      await DatabaseService.executeSql(
        'DELETE FROM study_event WHERE word_id IN (SELECT id FROM words WHERE book_id = ?)',
        [bookId]
      );
      console.info('resetRecordsByBookId success bookId=' + bookId.toString());
    } catch (error) {
      console.error('resetRecordsByBookId failed: ' + JSON.stringify(error));
    }
  }

  public static async resetAllRecords(): Promise<void> {
    try {
      await DatabaseService.executeSql('DELETE FROM study_record');
      await DatabaseService.executeSql('DELETE FROM study_daily');
      await DatabaseService.executeSql('DELETE FROM study_event');
      await DatabaseService.executeSql('DELETE FROM study_session');
      console.info('resetAllRecords success');
    } catch (error) {
      console.error('resetAllRecords failed: ' + JSON.stringify(error));
    }
  }

  private static async getOrCreateRecord(wordId: number): Promise<StudyRecord> {
    const existed: StudyRecord | null = await StudyRecordService.getRecord(wordId);
    if (existed) {
      return existed;
    }

    await DatabaseService.executeSql(
      'INSERT INTO study_record(word_id, correct_count, wrong_count, last_review_time, next_review_time, ' +
        'interval_days, ease_factor, mastered) VALUES(?, 0, 0, 0, 0, 1, 2.5, 0)',
      [wordId]
    );

    const created: StudyRecord | null = await StudyRecordService.getRecord(wordId);
    if (created) {
      return created;
    }

    return {
      id: 0,
      wordId: wordId,
      correctCount: 0,
      wrongCount: 0,
      lastReviewTime: 0,
      nextReviewTime: 0,
      intervalDays: 1,
      easeFactor: 2.5,
      mastered: 0
    };
  }

  private static async getRecord(wordId: number): Promise<StudyRecord | null> {
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await DatabaseService.querySql(
        'SELECT id, word_id, correct_count, wrong_count, last_review_time, next_review_time, ' +
          'interval_days, ease_factor, mastered FROM study_record WHERE word_id = ? LIMIT 1',
        [wordId]
      );
      if (resultSet.goToFirstRow()) {
        return {
          id: resultSet.getLong(resultSet.getColumnIndex('id')),
          wordId: resultSet.getLong(resultSet.getColumnIndex('word_id')),
          correctCount: resultSet.getLong(resultSet.getColumnIndex('correct_count')),
          wrongCount: resultSet.getLong(resultSet.getColumnIndex('wrong_count')),
          lastReviewTime: resultSet.getLong(resultSet.getColumnIndex('last_review_time')),
          nextReviewTime: resultSet.getLong(resultSet.getColumnIndex('next_review_time')),
          intervalDays: resultSet.getLong(resultSet.getColumnIndex('interval_days')),
          easeFactor: resultSet.getDouble(resultSet.getColumnIndex('ease_factor')),
          mastered: resultSet.getLong(resultSet.getColumnIndex('mastered'))
        };
      }
    } catch (error) {
      console.error('getRecord failed: ' + JSON.stringify(error));
    } finally {
      if (resultSet) {
        resultSet.close();
      }
    }
    return null;
  }

  private static async increaseDaily(scene: StudyScene, isCorrect: boolean, elapsedSeconds: number = 0): Promise<void> {
    const today: string = DateUtil.todayKey();
    const hasRow: boolean = await StudyRecordService.hasDailyRow(today);
    if (!hasRow) {
      await DatabaseService.executeSql(
        'INSERT INTO study_daily(date, learn_count, review_count, correct_count, wrong_count) VALUES(?, 0, 0, 0, 0)',
        [today]
      );
    }

    const learnIncrement: number = scene === 'learn' ? 1 : 0;
    const reviewIncrement: number = scene === 'review' ? 1 : 0;
    const correctIncrement: number = isCorrect ? 1 : 0;
    const wrongIncrement: number = isCorrect ? 0 : 1;
    await DatabaseService.executeSql(
      'UPDATE study_daily SET learn_count = learn_count + ?, review_count = review_count + ?, ' +
        'correct_count = correct_count + ?, wrong_count = wrong_count + ?, duration = duration + ? WHERE date = ?',
      [learnIncrement, reviewIncrement, correctIncrement, wrongIncrement, elapsedSeconds, today]
    );
  }

  private static async increaseDailyAccuracy(isCorrect: boolean, elapsedSeconds: number = 0): Promise<void> {
    const today: string = DateUtil.todayKey();
    const hasRow: boolean = await StudyRecordService.hasDailyRow(today);
    if (!hasRow) {
      await DatabaseService.executeSql(
        'INSERT INTO study_daily(date, learn_count, review_count, correct_count, wrong_count) VALUES(?, 0, 0, 0, 0)',
        [today]
      );
    }

    const correctIncrement: number = isCorrect ? 1 : 0;
    const wrongIncrement: number = isCorrect ? 0 : 1;
    await DatabaseService.executeSql(
      'UPDATE study_daily SET correct_count = correct_count + ?, wrong_count = wrong_count + ?, ' +
        'duration = duration + ? WHERE date = ?',
      [correctIncrement, wrongIncrement, elapsedSeconds, today]
    );
  }

  private static async increaseDailyLearnOnly(elapsedSeconds: number = 0): Promise<void> {
    const today: string = DateUtil.todayKey();
    const hasRow: boolean = await StudyRecordService.hasDailyRow(today);
    if (!hasRow) {
      await DatabaseService.executeSql(
        'INSERT INTO study_daily(date, learn_count, review_count, correct_count, wrong_count) VALUES(?, 0, 0, 0, 0)',
        [today]
      );
    }

    await DatabaseService.executeSql(
      'UPDATE study_daily SET learn_count = learn_count + 1, duration = duration + ? WHERE date = ?',
      [elapsedSeconds, today]
    );
  }

  private static async insertStudyEvent(wordId: number, scene: StudyScene, isCorrect: boolean): Promise<void> {
    try {
      await DatabaseService.executeSql(
        'INSERT INTO study_event(date, word_id, scene, correct, created_at) VALUES(?, ?, ?, ?, ?)',
        [DateUtil.todayKey(), wordId, scene, isCorrect ? 1 : 0, Date.now()]
      );
    } catch (error) {
      console.error('insertStudyEvent failed: ' + JSON.stringify(error));
    }
  }

  public static async updateDailyDuration(elapsedSeconds: number): Promise<void> {
    if (elapsedSeconds <= 0) {
      return;
    }
    try {
      const today: string = DateUtil.todayKey();
      await DatabaseService.executeSql(
        'UPDATE study_daily SET duration = duration + ? WHERE date = ?',
        [elapsedSeconds, today]
      );
    } catch (error) {
      console.error('updateDailyDuration failed: ' + JSON.stringify(error));
    }
  }

  private static async hasDailyRow(date: string): Promise<boolean> {
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await DatabaseService.querySql('SELECT id FROM study_daily WHERE date = ? LIMIT 1', [date]);
      return resultSet.goToFirstRow();
    } catch (error) {
      console.error('hasDailyRow failed: ' + JSON.stringify(error));
    } finally {
      if (resultSet) {
        resultSet.close();
      }
    }
    return false;
  }
}
