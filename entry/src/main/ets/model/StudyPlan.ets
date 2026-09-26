export interface StudyPlan {
  dailyGoal: number;
  reviewGoal: number;
  newWordGroupSize: number;
  reviewGroupSize: number;
  relearnGoal: number;
  relearnGroupSize: number;
  weeklyDays: number;
  weekendEnabled: boolean;
  targetDate: string;
  reminderEnabled: boolean;
}

export interface StudyPlanProgress {
  learnProgress: number;
  reviewProgress: number;
  totalProgress: number;
  suggestion: string;
}
