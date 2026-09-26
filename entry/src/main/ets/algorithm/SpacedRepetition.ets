import { DateUtil } from '../utils/DateUtil';

export interface ReviewSchedule {
  nextIntervalDays: number;
  nextEaseFactor: number;
  nextReviewTime: number;
  mastered: boolean;
}

export class SpacedRepetition {
  private static readonly MIN_COEFFICIENT: number = 0.3;
  private static readonly MAX_COEFFICIENT: number = 1.0;
  private static readonly BASE_INTERVALS: number[] = [1, 2, 4, 7, 15, 30, 60, 90];

  private static clamp(value: number, min: number, max: number): number {
    return Math.max(min, Math.min(max, value));
  }

  private static normalizedCoefficient(value: number): number {
    return SpacedRepetition.clamp(value, SpacedRepetition.MIN_COEFFICIENT, SpacedRepetition.MAX_COEFFICIENT);
  }

  private static getStageInterval(correctCount: number): number {
    const index: number = Math.round(SpacedRepetition.clamp(correctCount - 1, 0, SpacedRepetition.BASE_INTERVALS.length - 1));
    return SpacedRepetition.BASE_INTERVALS[index];
  }

  private static retentionThreshold(coefficient: number): number {
    return 0.62 + coefficient * 0.16;
  }

  private static forgettingPressure(coefficient: number, wrongCount: number): number {
    return 0.75 + coefficient + Math.min(wrongCount, 4) * 0.12;
  }

  public static estimateRetention(
    lastReviewTime: number,
    intervalDays: number,
    easeFactor: number,
    forgettingCoefficient: number = 0.5
  ): number {
    if (lastReviewTime <= 0) {
      return 0;
    }
    const coefficient: number = SpacedRepetition.normalizedCoefficient(forgettingCoefficient);
    const elapsedDays: number = Math.max(0, (Date.now() - lastReviewTime) / DateUtil.ONE_DAY_MILLISECONDS);
    const stabilityDays: number = Math.max(0.5, Math.max(intervalDays, 1) * Math.max(easeFactor, 1.3) / SpacedRepetition.forgettingPressure(coefficient, 0));
    return SpacedRepetition.clamp(Math.exp(-elapsedDays / stabilityDays), 0, 1);
  }

  public static estimateUrgency(
    lastReviewTime: number,
    nextReviewTime: number,
    intervalDays: number,
    easeFactor: number,
    correctCount: number,
    wrongCount: number,
    forgettingCoefficient: number = 0.5
  ): number {
    const retention: number = SpacedRepetition.estimateRetention(lastReviewTime, intervalDays, easeFactor, forgettingCoefficient);
    const overdueDays: number = nextReviewTime > 0 ? Math.max(0, (Date.now() - nextReviewTime) / DateUtil.ONE_DAY_MILLISECONDS) : 0;
    const errorPressure: number = Math.min(wrongCount, 5) * 0.08;
    const masteryRelief: number = Math.min(correctCount, 6) * 0.025;
    return SpacedRepetition.clamp((1 - retention) + overdueDays * 0.06 + errorPressure - masteryRelief, 0, 2);
  }

  /**
   * @param forgettingCoefficient 遗忘系数 (0.3-1.0)，默认 0.5。
   * 值越高表示忘得越快，复习间隔越短；值越低表示记得越牢，间隔越长。
   */
  public static calculate(
    isCorrect: boolean,
    currentIntervalDays: number,
    currentEaseFactor: number,
    correctCount: number,
    wrongCount: number,
    forgettingCoefficient: number = 0.5
  ): ReviewSchedule {
    const coefficient: number = SpacedRepetition.normalizedCoefficient(forgettingCoefficient);
    let nextEaseFactor: number;
    let nextIntervalDays: number;
    let mastered: boolean = false;

    if (isCorrect) {
      const wrongPenalty: number = Math.min(wrongCount, 4) * 0.04;
      nextEaseFactor = SpacedRepetition.clamp(currentEaseFactor + 0.12 - wrongPenalty, 1.3, 3.2);
      const stageInterval: number = Math.max(SpacedRepetition.getStageInterval(correctCount), currentIntervalDays);
      const stabilityDays: number = stageInterval * nextEaseFactor / SpacedRepetition.forgettingPressure(coefficient, wrongCount);
      const targetRetention: number = SpacedRepetition.retentionThreshold(coefficient);
      nextIntervalDays = Math.max(1, Math.round(-stabilityDays * Math.log(targetRetention)));
      mastered = correctCount >= 6 && wrongCount <= 2 && nextIntervalDays >= 30;
    } else {
      nextEaseFactor = SpacedRepetition.clamp(currentEaseFactor - 0.28, 1.3, 3.2);
      nextIntervalDays = 1;
      mastered = false;
    }

    return {
      nextIntervalDays: nextIntervalDays,
      nextEaseFactor: nextEaseFactor,
      nextReviewTime: DateUtil.addDaysTimestamp(nextIntervalDays),
      mastered: mastered
    };
  }
}
