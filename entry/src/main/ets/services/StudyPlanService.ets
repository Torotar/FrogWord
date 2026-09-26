import { StudyPlan, StudyPlanProgress } from '../model/StudyPlan';
import { StudyStats } from '../model/StudyStats';
import { PreferencesService } from './PreferencesService';
import { WordService } from './WordService';

export class StudyPlanService {
  public static async getPlan(): Promise<StudyPlan> {
    return {
      dailyGoal: await PreferencesService.getDailyGoal(),
      reviewGoal: await PreferencesService.getReviewGoal(),
      newWordGroupSize: await PreferencesService.getNewWordGroupSize(),
      reviewGroupSize: await PreferencesService.getReviewGroupSize(),
      relearnGoal: await PreferencesService.getRelearnGoal(),
      relearnGroupSize: await PreferencesService.getRelearnGroupSize(),
      weeklyDays: await PreferencesService.getWeeklyDays(),
      weekendEnabled: await PreferencesService.getWeekendEnabled(),
      targetDate: await PreferencesService.getTargetDate(),
      reminderEnabled: await PreferencesService.getReminderEnabled()
    };
  }

  public static async savePlan(plan: StudyPlan): Promise<void> {
    await PreferencesService.setDailyGoal(plan.dailyGoal);
    await PreferencesService.setReviewGoal(plan.reviewGoal);
    await PreferencesService.setNewWordGroupSize(plan.newWordGroupSize);
    await PreferencesService.setReviewGroupSize(plan.reviewGroupSize);
    await PreferencesService.setRelearnGoal(plan.relearnGoal);
    await PreferencesService.setRelearnGroupSize(plan.relearnGroupSize);
    await PreferencesService.setWeeklyDays(plan.weeklyDays);
    await PreferencesService.setWeekendEnabled(plan.weekendEnabled);
    await PreferencesService.setTargetDate(plan.targetDate);
    await PreferencesService.setReminderEnabled(plan.reminderEnabled);
    AppStorage.setOrCreate('studyDailyGoal', plan.dailyGoal);
    AppStorage.setOrCreate('studyReviewGoal', plan.reviewGoal);
    AppStorage.setOrCreate('studyReviewGroupSize', plan.reviewGroupSize);
  }

  public static async getProgress(bookId: number = 0): Promise<StudyPlanProgress> {
    const plan: StudyPlan = await StudyPlanService.getPlan();
    const stats: StudyStats = await WordService.getStats(bookId);
    const learnProgress: number = StudyPlanService.percent(stats.todayLearnCount, plan.dailyGoal);
    const reviewProgress: number = StudyPlanService.percent(stats.todayReviewCount, plan.reviewGoal);
    const totalProgress: number = Math.round((learnProgress + reviewProgress) / 2);

    return {
      learnProgress: learnProgress,
      reviewProgress: reviewProgress,
      totalProgress: totalProgress,
      suggestion: StudyPlanService.buildSuggestion(stats, plan)
    };
  }

  private static percent(value: number, target: number): number {
    if (target <= 0) {
      return 100;
    }
    return Math.min(100, Math.round(value * 100 / target));
  }

  private static buildSuggestion(stats: StudyStats, plan: StudyPlan): string {
    if (stats.todayLearnCount >= plan.dailyGoal && stats.todayReviewCount >= plan.reviewGoal) {
      return plan.reminderEnabled ? '学习提醒：今日目标已完成，保持这个节奏。' : '今日目标已完成';
    }
    if (stats.todayLearnCount < plan.dailyGoal) {
      const remaining: number = Math.max(0, plan.dailyGoal - stats.todayLearnCount);
      return plan.reminderEnabled
        ? '学习提醒：今天还需新学 ' + remaining.toString() + ' 个单词。'
        : '建议先完成今日新词，再进行复习。';
    }
    if (stats.pendingReviewCount > 0) {
      return plan.reminderEnabled
        ? '学习提醒：新词目标已完成，还有到期单词可以复习。'
        : '新词目标已完成，可以继续复习到期单词。';
    }
    return plan.reminderEnabled ? '学习提醒：今天复习压力不大，明天继续。' : '保持节奏，明天继续。';
  }
}
