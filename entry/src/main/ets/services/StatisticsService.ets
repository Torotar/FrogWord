import { relationalStore } from '@kit.ArkData';
import { StudyDaily, StudyStats } from '../model/StudyStats';
import { DateUtil } from '../utils/DateUtil';
import { DatabaseService } from './DatabaseService';
import { StudySessionService } from './StudySessionService';
import { WordService } from './WordService';

export class StatisticsService {
  private static emptyStats(): StudyStats {
    return {
      todayLearnCount: 0, todayReviewCount: 0, todayCorrectCount: 0, todayWrongCount: 0,
      pendingReviewCount: 0, unknownWordCount: 0, masteredCount: 0, totalWordCount: 0,
      unmasteredCount: 0, inLearningCount: 0, totalCorrectCount: 0, totalWrongCount: 0,
      accuracyRate: 0, studyDuration: 0
    };
  }

  public static async getOverviewStats(bookId: number = 0): Promise<StudyStats> {
    const stats: StudyStats = await WordService.getStats(bookId);
    const todayTotal: number = stats.todayCorrectCount + stats.todayWrongCount;
    stats.accuracyRate = todayTotal === 0 ? 0 : Math.round(stats.todayCorrectCount * 1000 / todayTotal) / 10;
    stats.unmasteredCount = Math.max(stats.totalWordCount - stats.masteredCount, 0);
    return stats;
  }

  public static async getRecentDailyStats(days: number): Promise<StudyDaily[]> {
    const keys: string[] = DateUtil.recentDateKeys(days);
    const queried: StudyDaily[] = await StatisticsService.queryDailyRows(keys[0]);
    const result: StudyDaily[] = [];

    for (let keyIndex: number = 0; keyIndex < keys.length; keyIndex++) {
      const key: string = keys[keyIndex];
      let found: StudyDaily | null = null;
      for (let rowIndex: number = 0; rowIndex < queried.length; rowIndex++) {
        if (queried[rowIndex].date === key) {
          found = queried[rowIndex];
          break;
        }
      }
      result.push(found ? found : {
        date: key,
        learnCount: 0,
        reviewCount: 0,
        correctCount: 0,
        wrongCount: 0,
        duration: 0
      });
    }
    return result;
  }

  public static async getDailyComparisonStats(date: string): Promise<StudyDaily[]> {
    const selectedDate: Date = new Date(date + ' 00:00:00');
    selectedDate.setDate(selectedDate.getDate() - 1);
    const previousDate: string = DateUtil.formatDateKey(selectedDate);
    const queried: StudyDaily[] = await StatisticsService.queryDailyRows(previousDate);
    const keys: string[] = [previousDate, date];
    const result: StudyDaily[] = [];
    for (let keyIndex: number = 0; keyIndex < keys.length; keyIndex++) {
      const key: string = keys[keyIndex];
      let found: StudyDaily | undefined = undefined;
      for (let rowIndex: number = 0; rowIndex < queried.length; rowIndex++) {
        if (queried[rowIndex].date === key) {
          found = queried[rowIndex];
          break;
        }
      }
      result.push(found ? found : {
        date: key,
        learnCount: 0,
        reviewCount: 0,
        correctCount: 0,
        wrongCount: 0,
        duration: 0
      });
    }
    return result;
  }

  public static async getAllDailyStats(): Promise<StudyDaily[]> {
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    let startKey: string = '';
    try {
      resultSet = await DatabaseService.querySql(
        'SELECT date FROM (' +
          'SELECT date FROM study_daily WHERE learn_count + review_count > 0 ' +
          'UNION SELECT date FROM study_session WHERE duration > 0' +
          ') ORDER BY date ASC LIMIT 1'
      );
      if (resultSet.goToFirstRow()) {
        startKey = resultSet.getString(resultSet.getColumnIndex('date'));
      }
    } catch (error) {
      console.error('getAllDailyStats start date failed: ' + JSON.stringify(error));
    } finally {
      if (resultSet) {
        resultSet.close();
      }
    }

    if (startKey.length === 0) {
      return [];
    }

    const queried: StudyDaily[] = await StatisticsService.queryDailyRows(startKey);
    const rowMap: Map<string, StudyDaily> = new Map();
    for (let rowIndex: number = 0; rowIndex < queried.length; rowIndex++) {
      rowMap.set(queried[rowIndex].date, queried[rowIndex]);
    }
    const result: StudyDaily[] = [];
    const today: Date = new Date();
    today.setHours(0, 0, 0, 0);
    const cursor: Date = new Date(startKey + ' 00:00:00');
    cursor.setHours(0, 0, 0, 0);

    while (cursor.getTime() <= today.getTime()) {
      const key: string = DateUtil.formatDateKey(cursor);
      const found: StudyDaily | undefined = rowMap.get(key);
      result.push(found ? found : {
        date: key,
        learnCount: 0,
        reviewCount: 0,
        correctCount: 0,
        wrongCount: 0,
        duration: 0
      });
      cursor.setDate(cursor.getDate() + 1);
    }

    return result;
  }

  public static async getCurrentMonthDailyStats(): Promise<StudyDaily[]> {
    const now: Date = new Date();
    return StatisticsService.getMonthDailyStats(now.getFullYear(), now.getMonth() + 1);
  }

  public static async getMonthDailyStats(year: number, month: number): Promise<StudyDaily[]> {
    const firstDay: Date = new Date(year, month - 1, 1);
    const startKey: string = DateUtil.formatDateKey(firstDay);
    const queried: StudyDaily[] = await StatisticsService.queryDailyRows(startKey);
    const result: StudyDaily[] = [];
    const lastDay: number = new Date(year, month, 0).getDate();

    for (let day: number = 1; day <= lastDay; day++) {
      const current: Date = new Date(year, month - 1, day);
      const key: string = DateUtil.formatDateKey(current);
      let found: StudyDaily | null = null;
      for (let rowIndex: number = 0; rowIndex < queried.length; rowIndex++) {
        if (queried[rowIndex].date === key) {
          found = queried[rowIndex];
          break;
        }
      }
      result.push(found ? found : {
        date: key,
        learnCount: 0,
        reviewCount: 0,
        correctCount: 0,
        wrongCount: 0,
        duration: 0
      });
    }
    return result;
  }

  public static async getAccuracyRate(): Promise<number> {
    const stats: StudyStats = await StatisticsService.getOverviewStats();
    return stats.accuracyRate;
  }

  // 按周期获取概览统计
  public static async getPeriodOverviewStats(period: string, bookId: number = 0): Promise<StudyStats> {
    return StatisticsService.getRangeOverviewStats(
      DateUtil.periodStartKey(period), DateUtil.periodEndKey(period), bookId, false);
  }

  public static async getDateOverviewStats(date: string, bookId: number = 0): Promise<StudyStats> {
    return StatisticsService.getRangeOverviewStats(date, date, bookId, true);
  }

  private static async getRangeOverviewStats(
    startKey: string, endKey: string, bookId: number = 0, strictRange: boolean = false
  ): Promise<StudyStats> {
    // 未选择词书时返回全零
    if (bookId <= 0) {
      return StatisticsService.emptyStats();
    }
    const base: StudyStats = await WordService.getStats(bookId);
    const hb: boolean = true;

    let periodLearn: number = 0;
    let periodCorrect: number = 0;
    let periodWrong: number = 0;
    let periodDuration: number = 0;
    let periodReviewWords: number = 0;  // 周期内去重学习过的单词数（匹配 SearchPage）
    let periodCorrectWords: number = 0; // 周期内至少答对一次的去重单词数（词级掌握率）
    let periodTotalWords: number = 0;   // 周期内学习过的去重单词总数（词级掌握率分母）
    let periodMastered: number = 0;
    let periodUnknown: number = 0;
    let periodUnmastered: number = 0;
    let periodInLearning: number = 0;
    let periodPending: number = 0;
    let periodUniqueWords: number = 0;
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await DatabaseService.querySql(
        'SELECT IFNULL(SUM(learn_count),0) AS l, IFNULL(SUM(review_count),0) AS r, ' +
          'IFNULL(SUM(correct_count),0) AS c, IFNULL(SUM(wrong_count),0) AS w ' +
          'FROM study_daily WHERE date >= ? AND date <= ?',
        [startKey, endKey]
      );
      if (resultSet.goToFirstRow()) {
        periodLearn = resultSet.getLong(resultSet.getColumnIndex('l'));
        periodCorrect = resultSet.getLong(resultSet.getColumnIndex('c'));
        periodWrong = resultSet.getLong(resultSet.getColumnIndex('w'));
      }

      // 学习时长从 study_session 表读取
      periodDuration = await StudySessionService.getDurationSum(startKey, endKey);

      // 计算周期起止时刻（毫秒时间戳）
      const startTime: number = new Date(startKey + ' 00:00:00').getTime();
      const endTime: number = new Date(endKey + ' 23:59:59').getTime();

      // 周期内分类词数：通过 study_record.last_review_time 判定是否在该周期学习过
      if (resultSet) {
        resultSet.close();
      }
      resultSet = await DatabaseService.querySql(
        hb
          ? 'SELECT COUNT(*) AS count FROM study_record sr INNER JOIN words w ON sr.word_id = w.id WHERE w.book_id = ? AND sr.last_review_time >= ? AND sr.last_review_time <= ? AND sr.mastered = 1'
          : 'SELECT COUNT(*) AS count FROM study_record WHERE last_review_time >= ? AND last_review_time <= ? AND mastered = 1',
        hb ? [bookId, startTime, endTime] : [startTime, endTime]
      );
      if (resultSet.goToFirstRow()) {
        periodMastered = resultSet.getLong(resultSet.getColumnIndex('count'));
      }

      if (resultSet) {
        resultSet.close();
      }
      resultSet = await DatabaseService.querySql(
        hb
          ? 'SELECT COUNT(DISTINCT se.word_id) AS count FROM study_event se INNER JOIN words w ON se.word_id = w.id WHERE w.book_id = ? AND se.date >= ? AND se.date <= ? AND se.correct = 0'
          : 'SELECT COUNT(DISTINCT word_id) AS count FROM study_event WHERE date >= ? AND date <= ? AND correct = 0',
        hb ? [bookId, startKey, endKey] : [startKey, endKey]
      );
      if (resultSet.goToFirstRow()) {
        periodUnknown = resultSet.getLong(resultSet.getColumnIndex('count'));
      }

      if (resultSet) {
        resultSet.close();
      }
      resultSet = await DatabaseService.querySql(
        hb
          ? 'SELECT COUNT(*) AS count FROM study_record sr INNER JOIN words w ON sr.word_id = w.id WHERE w.book_id = ? AND sr.last_review_time >= ? AND sr.last_review_time <= ? AND sr.mastered = 0 AND sr.next_review_time > 0 AND sr.next_review_time <= ?'
          : 'SELECT COUNT(*) AS count FROM study_record WHERE last_review_time >= ? AND last_review_time <= ? AND mastered = 0 AND next_review_time > 0 AND next_review_time <= ?',
        hb ? [bookId, startTime, endTime, Date.now()] : [startTime, endTime, Date.now()]
      );
      if (resultSet.goToFirstRow()) {
        periodPending = resultSet.getLong(resultSet.getColumnIndex('count'));
      }

      if (resultSet) {
        resultSet.close();
      }
      resultSet = await DatabaseService.querySql(
        hb
          ? 'SELECT COUNT(*) AS count FROM study_record sr INNER JOIN words w ON sr.word_id = w.id WHERE w.book_id = ? AND sr.last_review_time >= ? AND sr.last_review_time <= ? AND sr.mastered = 0'
          : 'SELECT COUNT(*) AS count FROM study_record WHERE last_review_time >= ? AND last_review_time <= ? AND mastered = 0',
        hb ? [bookId, startTime, endTime] : [startTime, endTime]
      );
      if (resultSet.goToFirstRow()) {
        periodUnmastered = resultSet.getLong(resultSet.getColumnIndex('count'));
      }

      if (resultSet) {
        resultSet.close();
      }
      resultSet = await DatabaseService.querySql(
        hb
          ? 'SELECT COUNT(*) AS count FROM study_record sr INNER JOIN words w ON sr.word_id = w.id WHERE w.book_id = ? AND sr.last_review_time >= ? AND sr.last_review_time <= ? AND sr.mastered = 0 AND sr.wrong_count = 0'
          : 'SELECT COUNT(*) AS count FROM study_record WHERE last_review_time >= ? AND last_review_time <= ? AND mastered = 0 AND wrong_count = 0',
        hb ? [bookId, startTime, endTime] : [startTime, endTime]
      );
      if (resultSet.goToFirstRow()) {
        periodInLearning = resultSet.getLong(resultSet.getColumnIndex('count'));
      }

      if (resultSet) {
        resultSet.close();
      }
      resultSet = await DatabaseService.querySql(
        hb
          ? 'SELECT COUNT(*) AS count FROM study_record sr INNER JOIN words w ON sr.word_id = w.id WHERE w.book_id = ? AND sr.last_review_time >= ? AND sr.last_review_time <= ?'
          : 'SELECT COUNT(*) AS count FROM study_record WHERE last_review_time >= ? AND last_review_time <= ?',
        hb ? [bookId, startTime, endTime] : [startTime, endTime]
      );
      if (resultSet.goToFirstRow()) {
        periodUniqueWords = resultSet.getLong(resultSet.getColumnIndex('count'));
      }

      if (resultSet) {
        resultSet.close();
      }
      // 周期内去重学习过的单词数（匹配 SearchPage 的 getPeriodEventWords 逻辑）
      resultSet = await DatabaseService.querySql(
        hb
          ? 'SELECT COUNT(DISTINCT se.word_id) AS count FROM study_event se INNER JOIN words w ON se.word_id = w.id WHERE w.book_id = ? AND se.date >= ? AND se.date <= ?'
          : 'SELECT COUNT(DISTINCT word_id) AS count FROM study_event WHERE date >= ? AND date <= ?',
        hb ? [bookId, startKey, endKey] : [startKey, endKey]
      );
      if (resultSet.goToFirstRow()) {
        periodReviewWords = resultSet.getLong(resultSet.getColumnIndex('count'));
      }

      if (resultSet) {
        resultSet.close();
      }
      // 周期内至少答对一次的去重单词数（用于词级掌握率分子）
      resultSet = await DatabaseService.querySql(
        hb
          ? 'SELECT COUNT(DISTINCT se.word_id) AS count FROM study_event se INNER JOIN words w ON se.word_id = w.id WHERE w.book_id = ? AND se.date >= ? AND se.date <= ? AND se.correct = 1'
          : 'SELECT COUNT(DISTINCT word_id) AS count FROM study_event WHERE date >= ? AND date <= ? AND correct = 1',
        hb ? [bookId, startKey, endKey] : [startKey, endKey]
      );
      if (resultSet.goToFirstRow()) {
        periodCorrectWords = resultSet.getLong(resultSet.getColumnIndex('count'));
      }

      if (resultSet) {
        resultSet.close();
      }
      // 周期内学习过的去重单词总数（用于词级掌握率分母）
      resultSet = await DatabaseService.querySql(
        hb
          ? 'SELECT COUNT(DISTINCT se.word_id) AS count FROM study_event se INNER JOIN words w ON se.word_id = w.id WHERE w.book_id = ? AND se.date >= ? AND se.date <= ?'
          : 'SELECT COUNT(DISTINCT word_id) AS count FROM study_event WHERE date >= ? AND date <= ?',
        hb ? [bookId, startKey, endKey] : [startKey, endKey]
      );
      if (resultSet.goToFirstRow()) {
        periodTotalWords = resultSet.getLong(resultSet.getColumnIndex('count'));
      }
    } catch (error) {
      console.error('getRangeOverviewStats failed: ' + JSON.stringify(error));
    } finally {
      if (resultSet) {
        resultSet.close();
      }
    }

    // 词级掌握率：周期内至少答对一次的去重单词数 / 周期内学习过的去重单词总数
    const accuracyRate: number = periodTotalWords === 0 ? 0 : Math.round(periodCorrectWords * 1000 / periodTotalWords) / 10;

    return {
      todayLearnCount: periodLearn,
      todayReviewCount: periodReviewWords,
      todayCorrectCount: periodCorrect,
      todayWrongCount: periodWrong,
      pendingReviewCount: periodPending,
      unknownWordCount: periodUnknown,
      masteredCount: strictRange ? periodCorrectWords : periodMastered,
      totalWordCount: strictRange ? periodTotalWords :
        (periodUniqueWords > 0 ? periodUniqueWords : base.totalWordCount),
      unmasteredCount: strictRange ? Math.max(0, periodTotalWords - periodCorrectWords) : periodUnmastered,
      inLearningCount: strictRange ? Math.max(0, periodTotalWords - periodUnknown) : periodInLearning,
      totalCorrectCount: periodCorrect,
      totalWrongCount: periodWrong,
      accuracyRate: accuracyRate,
      studyDuration: periodDuration
    };
  }

  // 获取全部时间总概览统计（无日期范围限制）
  public static async getTotalOverviewStats(bookId: number = 0): Promise<StudyStats> {
    // 未选择词书时返回全零
    if (bookId <= 0) {
      return StatisticsService.emptyStats();
    }
    const base: StudyStats = await WordService.getStats(bookId);
    const hb: boolean = true;
    const b: relationalStore.ValueType[] = [bookId];

    let totalLearn: number = 0;
    let totalCorrect: number = 0;
    let totalWrong: number = 0;
    let totalDuration: number = 0;
    let totalReviewWords: number = 0;
    let totalMastered: number = 0;
    let totalUnknown: number = 0;
    let totalUnmastered: number = 0;
    let totalInLearning: number = 0;
    let totalPending: number = 0;
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await DatabaseService.querySql(
        'SELECT IFNULL(SUM(learn_count),0) AS l, IFNULL(SUM(review_count),0) AS r, ' +
          'IFNULL(SUM(correct_count),0) AS c, IFNULL(SUM(wrong_count),0) AS w FROM study_daily'
      );
      if (resultSet.goToFirstRow()) {
        totalLearn = resultSet.getLong(resultSet.getColumnIndex('l'));
        totalCorrect = resultSet.getLong(resultSet.getColumnIndex('c'));
        totalWrong = resultSet.getLong(resultSet.getColumnIndex('w'));
      }

      // 全部时长从 study_session 表读取
      totalDuration = await StudySessionService.getTotalDuration();

      if (resultSet) {
        resultSet.close();
      }
      resultSet = await DatabaseService.querySql(
        hb
          ? 'SELECT COUNT(*) AS count FROM study_record sr INNER JOIN words w ON sr.word_id = w.id WHERE w.book_id = ? AND sr.mastered = 1'
          : 'SELECT COUNT(*) AS count FROM study_record WHERE mastered = 1',
        hb ? b : []
      );
      if (resultSet.goToFirstRow()) {
        totalMastered = resultSet.getLong(resultSet.getColumnIndex('count'));
      }

      if (resultSet) {
        resultSet.close();
      }
      resultSet = await DatabaseService.querySql(
        hb
          ? 'SELECT COUNT(*) AS count FROM study_record sr INNER JOIN words w ON sr.word_id = w.id WHERE w.book_id = ? AND sr.mastered = 0 AND sr.wrong_count > 0'
          : 'SELECT COUNT(*) AS count FROM study_record WHERE mastered = 0 AND wrong_count > 0',
        hb ? b : []
      );
      if (resultSet.goToFirstRow()) {
        totalUnknown = resultSet.getLong(resultSet.getColumnIndex('count'));
      }

      if (resultSet) {
        resultSet.close();
      }
      resultSet = await DatabaseService.querySql(
        hb
          ? 'SELECT COUNT(*) AS count FROM study_record sr INNER JOIN words w ON sr.word_id = w.id WHERE w.book_id = ? AND sr.mastered = 0 AND sr.next_review_time > 0 AND sr.next_review_time <= ?'
          : 'SELECT COUNT(*) AS count FROM study_record WHERE mastered = 0 AND next_review_time > 0 AND next_review_time <= ?',
        hb ? [bookId, Date.now()] : [Date.now()]
      );
      if (resultSet.goToFirstRow()) {
        totalPending = resultSet.getLong(resultSet.getColumnIndex('count'));
      }

      if (resultSet) {
        resultSet.close();
      }
      resultSet = await DatabaseService.querySql(
        hb
          ? 'SELECT COUNT(*) AS count FROM words w LEFT JOIN study_record sr ON w.id = sr.word_id WHERE w.book_id = ? AND IFNULL(sr.mastered, 0) = 0'
          : 'SELECT COUNT(*) AS count FROM words w LEFT JOIN study_record sr ON w.id = sr.word_id WHERE IFNULL(sr.mastered, 0) = 0',
        hb ? b : []
      );
      if (resultSet.goToFirstRow()) {
        totalUnmastered = resultSet.getLong(resultSet.getColumnIndex('count'));
      }

      if (resultSet) {
        resultSet.close();
      }
      resultSet = await DatabaseService.querySql(
        hb
          ? 'SELECT COUNT(*) AS count FROM study_record sr INNER JOIN words w ON sr.word_id = w.id WHERE w.book_id = ? AND sr.mastered = 0 AND sr.wrong_count = 0'
          : 'SELECT COUNT(*) AS count FROM study_record WHERE mastered = 0 AND wrong_count = 0',
        hb ? b : []
      );
      if (resultSet.goToFirstRow()) {
        totalInLearning = resultSet.getLong(resultSet.getColumnIndex('count'));
      }

      if (resultSet) {
        resultSet.close();
      }
      // 全部学习过的去重单词数
      resultSet = await DatabaseService.querySql(
        hb
          ? 'SELECT COUNT(DISTINCT se.word_id) AS count FROM study_event se INNER JOIN words w ON se.word_id = w.id WHERE w.book_id = ?'
          : 'SELECT COUNT(DISTINCT word_id) AS count FROM study_event',
        hb ? b : []
      );
      if (resultSet.goToFirstRow()) {
        totalReviewWords = resultSet.getLong(resultSet.getColumnIndex('count'));
      }

      if (resultSet) {
        resultSet.close();
      }
      // 至少答对一次的去重单词数
      resultSet = await DatabaseService.querySql(
        hb
          ? 'SELECT COUNT(DISTINCT se.word_id) AS count FROM study_event se INNER JOIN words w ON se.word_id = w.id WHERE w.book_id = ? AND se.correct = 1'
          : 'SELECT COUNT(DISTINCT word_id) AS count FROM study_event WHERE correct = 1',
        hb ? b : []
      );
      let totalCorrectWords: number = 0;
      if (resultSet.goToFirstRow()) {
        totalCorrectWords = resultSet.getLong(resultSet.getColumnIndex('count'));
      }

      if (resultSet) {
        resultSet.close();
      }
      // 全部学习过的去重单词总数
      resultSet = await DatabaseService.querySql(
        hb
          ? 'SELECT COUNT(DISTINCT se.word_id) AS count FROM study_event se INNER JOIN words w ON se.word_id = w.id WHERE w.book_id = ?'
          : 'SELECT COUNT(DISTINCT word_id) AS count FROM study_event',
        hb ? b : []
      );
      let totalEventWords: number = 0;
      if (resultSet.goToFirstRow()) {
        totalEventWords = resultSet.getLong(resultSet.getColumnIndex('count'));
      }

      // 词级掌握率
      const accuracyRate: number = totalEventWords === 0 ? 0 : Math.round(totalCorrectWords * 1000 / totalEventWords) / 10;

      return {
        todayLearnCount: totalLearn,
        todayReviewCount: totalReviewWords,
        todayCorrectCount: totalCorrect,
        todayWrongCount: totalWrong,
        pendingReviewCount: totalPending,
        unknownWordCount: totalUnknown,
        masteredCount: totalMastered,
        totalWordCount: totalReviewWords > 0 ? totalReviewWords : base.totalWordCount,
        unmasteredCount: totalUnmastered,
        inLearningCount: totalInLearning,
        totalCorrectCount: totalCorrect,
        totalWrongCount: totalWrong,
        accuracyRate: accuracyRate,
        studyDuration: totalDuration
      };
    } catch (error) {
      console.error('getTotalOverviewStats failed: ' + JSON.stringify(error));
      return base;
    } finally {
      if (resultSet) {
        resultSet.close();
      }
    }
  }

  // 按周期获取分段学习数据（用于图表）
  public static async getPeriodDailyStats(period: string, count: number): Promise<StudyDaily[]> {
    const ranges: string[][] = DateUtil.recentPeriodRanges(period, count);
    // 查询所有相关数据（从最早周期起点）
    const allRows: StudyDaily[] = await StatisticsService.queryDailyRows(ranges[0][0]);
    const result: StudyDaily[] = [];

    for (let r: number = 0; r < ranges.length; r++) {
      const startKey: string = ranges[r][0];
      const endKey: string = ranges[r][1];
      // 聚合该周期内的数据
      let sumLearn: number = 0;
      let sumReview: number = 0;
      let sumCorrect: number = 0;
      let sumWrong: number = 0;
      let sumDuration: number = 0;
      const lastDate: string = endKey;

      for (let i: number = 0; i < allRows.length; i++) {
        if (allRows[i].date >= startKey && allRows[i].date <= endKey) {
          sumLearn += allRows[i].learnCount;
          sumReview += allRows[i].reviewCount;
          sumCorrect += allRows[i].correctCount;
          sumWrong += allRows[i].wrongCount;
          sumDuration += allRows[i].duration;
        }
      }

      // 使用周期标签作为日期显示
      let label: string;
      if (period === '日') {
        label = lastDate;
      } else if (period === '周') {
        // 显示周结束日
        label = lastDate;
      } else if (period === '月') {
        label = lastDate.substring(0, 7);
      } else {
        label = lastDate.substring(0, 4);
      }

      result.push({
        date: label,
        learnCount: sumLearn,
        reviewCount: sumReview,
        correctCount: sumCorrect,
        wrongCount: sumWrong,
        duration: sumDuration
      });
    }

    return result;
  }

  private static async queryDailyRows(startDate: string): Promise<StudyDaily[]> {
    const rows: StudyDaily[] = [];
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      // 从 study_daily 获取学习和正确/错误次数数据
      resultSet = await DatabaseService.querySql(
        'SELECT date, learn_count, review_count, correct_count, wrong_count FROM study_daily WHERE date >= ? ORDER BY date ASC',
        [startDate]
      );
      while (resultSet.goToNextRow()) {
        rows.push({
          date: resultSet.getString(resultSet.getColumnIndex('date')),
          learnCount: resultSet.getLong(resultSet.getColumnIndex('learn_count')),
          reviewCount: resultSet.getLong(resultSet.getColumnIndex('review_count')),
          correctCount: resultSet.getLong(resultSet.getColumnIndex('correct_count')),
          wrongCount: resultSet.getLong(resultSet.getColumnIndex('wrong_count')),
          duration: 0
        });
      }

      // 从 study_session 获取每日时长
      if (resultSet) {
        resultSet.close();
      }
      resultSet = await DatabaseService.querySql(
        'SELECT date, SUM(duration) AS d FROM study_session WHERE date >= ? GROUP BY date ORDER BY date ASC',
        [startDate]
      );
      // 构建 date→duration 映射，同时记录已存在的日期
      const existingDates: Set<string> = new Set();
      for (let i: number = 0; i < rows.length; i++) {
        existingDates.add(rows[i].date);
      }
      const durMap: Map<string, number> = new Map();
      while (resultSet.goToNextRow()) {
        const date: string = resultSet.getString(resultSet.getColumnIndex('date'));
        const dur: number = resultSet.getLong(resultSet.getColumnIndex('d'));
        durMap.set(date, dur);
      }
      // 合并到 rows：已有日期的补充时长，新日期追加
      for (let i: number = 0; i < rows.length; i++) {
        const d: number | undefined = durMap.get(rows[i].date);
        if (d !== undefined) {
          rows[i].duration = d;
        }
      }
      // 补充 study_session 中有但 study_daily 中没有的日期
      durMap.forEach((dur: number, date: string) => {
        if (!existingDates.has(date)) {
          rows.push({
            date: date,
            learnCount: 0,
            reviewCount: 0,
            correctCount: 0,
            wrongCount: 0,
            duration: dur
          });
        }
      });
      // 按日期排序
      rows.sort((a: StudyDaily, b: StudyDaily) => {
        if (a.date < b.date) return -1;
        if (a.date > b.date) return 1;
        return 0;
      });
    } catch (error) {
      console.error('queryDailyRows failed: ' + JSON.stringify(error));
    } finally {
      if (resultSet) {
        resultSet.close();
      }
    }
    return rows;
  }

  /**
   * 获取指定日期的逐小时学习时长统计
   * @param date 日期 YYYY-MM-DD
   * @returns 24 个 StudyDaily 条目，date="HH:00"，duration 为该小时的学习秒数
   */
  public static async getHourlyStats(date: string): Promise<StudyDaily[]> {
    // 初始化 24 小时数据（秒）
    const hourlyDuration: number[] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await DatabaseService.querySql(
        'SELECT start_time, duration FROM study_session WHERE date = ? ORDER BY start_time',
        [date]
      );
      while (resultSet.goToNextRow()) {
        const startTime: number = resultSet.getLong(resultSet.getColumnIndex('start_time'));
        const duration: number = resultSet.getLong(resultSet.getColumnIndex('duration'));
        const hour: number = new Date(startTime).getHours();
        hourlyDuration[hour] += duration;
      }
    } catch (error) {
      console.error('getHourlyStats failed: ' + JSON.stringify(error));
    } finally {
      if (resultSet) {
        resultSet.close();
      }
    }

    // 生成 24 个 StudyDaily 条目
    const result: StudyDaily[] = [];
    for (let h: number = 0; h < 24; h++) {
      const hourStr: string = (h < 10 ? '0' : '') + h.toString() + ':00';
      result.push({
        date: hourStr,
        learnCount: 0,
        reviewCount: 0,
        correctCount: 0,
        wrongCount: 0,
        duration: hourlyDuration[h]
      });
    }
    return result;
  }
}
