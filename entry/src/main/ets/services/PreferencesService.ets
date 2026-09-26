import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { AiConfig } from '../model/AiConfig';
import { Constants } from '../utils/Constants';

export class PreferencesService {
  private static pref?: preferences.Preferences;

  public static async init(context: common.Context): Promise<void> {
    if (PreferencesService.pref) {
      return;
    }

    try {
      PreferencesService.pref = await preferences.getPreferences(context, Constants.PREFERENCES_NAME);
    } catch (error) {
      console.error('PreferencesService init failed: ' + JSON.stringify(error));
    }
  }

  public static async getDailyGoal(): Promise<number> {
    const value: preferences.ValueType = await PreferencesService.getValue('dailyGoal', Constants.DEFAULT_DAILY_GOAL);
    return typeof value === 'number' ? value : Constants.DEFAULT_DAILY_GOAL;
  }

  public static async setDailyGoal(value: number): Promise<void> {
    await PreferencesService.putValue('dailyGoal', value);
  }

  public static async getReviewGoal(): Promise<number> {
    const value: preferences.ValueType = await PreferencesService.getValue('reviewGoal', Constants.DEFAULT_REVIEW_GOAL);
    return typeof value === 'number' ? value : Constants.DEFAULT_REVIEW_GOAL;
  }

  public static async setReviewGoal(value: number): Promise<void> {
    await PreferencesService.putValue('reviewGoal', value);
  }

  public static async getNewWordGroupSize(): Promise<number> {
    const value: preferences.ValueType = await PreferencesService.getValue('newWordGroupSize', Constants.DEFAULT_NEW_WORD_GROUP_SIZE);
    return typeof value === 'number' ? value : Constants.DEFAULT_NEW_WORD_GROUP_SIZE;
  }

  public static async setNewWordGroupSize(value: number): Promise<void> {
    await PreferencesService.putValue('newWordGroupSize', value);
  }

  public static async getReviewGroupSize(): Promise<number> {
    const value: preferences.ValueType = await PreferencesService.getValue('reviewGroupSize', Constants.DEFAULT_REVIEW_GROUP_SIZE);
    return typeof value === 'number' ? value : Constants.DEFAULT_REVIEW_GROUP_SIZE;
  }

  public static async setReviewGroupSize(value: number): Promise<void> {
    await PreferencesService.putValue('reviewGroupSize', value);
  }

  public static async getRelearnGoal(): Promise<number> {
    const value: preferences.ValueType = await PreferencesService.getValue('relearnGoal', Constants.DEFAULT_RELEARN_GOAL);
    return typeof value === 'number' ? value : Constants.DEFAULT_RELEARN_GOAL;
  }

  public static async setRelearnGoal(value: number): Promise<void> {
    await PreferencesService.putValue('relearnGoal', value);
  }

  public static async getRelearnGroupSize(): Promise<number> {
    const value: preferences.ValueType = await PreferencesService.getValue('relearnGroupSize', Constants.DEFAULT_RELEARN_GROUP_SIZE);
    return typeof value === 'number' ? value : Constants.DEFAULT_RELEARN_GROUP_SIZE;
  }

  public static async setRelearnGroupSize(value: number): Promise<void> {
    await PreferencesService.putValue('relearnGroupSize', value);
  }

  public static async getWeeklyDays(): Promise<number> {
    const value: preferences.ValueType = await PreferencesService.getValue('weeklyDays', Constants.DEFAULT_WEEKLY_DAYS);
    return typeof value === 'number' ? value : Constants.DEFAULT_WEEKLY_DAYS;
  }

  public static async setWeeklyDays(value: number): Promise<void> {
    await PreferencesService.putValue('weeklyDays', value);
  }

  public static async getWeekendEnabled(): Promise<boolean> {
    const value: preferences.ValueType = await PreferencesService.getValue('weekendEnabled', Constants.DEFAULT_WEEKEND_ENABLED);
    return typeof value === 'boolean' ? value : Constants.DEFAULT_WEEKEND_ENABLED;
  }

  public static async setWeekendEnabled(value: boolean): Promise<void> {
    await PreferencesService.putValue('weekendEnabled', value);
  }

  public static async getTargetDate(): Promise<string> {
    return await PreferencesService.getString('targetDate', Constants.DEFAULT_TARGET_DATE);
  }

  public static async setTargetDate(value: string): Promise<void> {
    await PreferencesService.putValue('targetDate', value);
  }

  public static async getReminderEnabled(): Promise<boolean> {
    const value: preferences.ValueType = await PreferencesService.getValue('reminderEnabled', Constants.DEFAULT_REMINDER_ENABLED);
    return typeof value === 'boolean' ? value : Constants.DEFAULT_REMINDER_ENABLED;
  }

  public static async setReminderEnabled(value: boolean): Promise<void> {
    await PreferencesService.putValue('reminderEnabled', value);
  }

  public static async getThemeMode(): Promise<number> {
    const value: preferences.ValueType = await PreferencesService.getValue('themeMode', Constants.DEFAULT_THEME_MODE);
    return typeof value === 'number' ? value : Constants.DEFAULT_THEME_MODE;
  }

  public static async setThemeMode(value: number): Promise<void> {
    await PreferencesService.putValue('themeMode', value);
  }

  public static async getMaterialEffectMode(): Promise<number> {
    const value: preferences.ValueType = await PreferencesService.getValue('materialEffectMode', Constants.DEFAULT_MATERIAL_EFFECT_MODE);
    return typeof value === 'number' ? PreferencesService.normalizeMaterialEffectMode(value) :
    Constants.DEFAULT_MATERIAL_EFFECT_MODE;
  }

  public static async setMaterialEffectMode(value: number): Promise<void> {
    await PreferencesService.putValue('materialEffectMode', PreferencesService.normalizeMaterialEffectMode(value));
  }

  private static normalizeMaterialEffectMode(value: number): number {
    if (value <= 0) {
      return 0;
    }
    if (value >= 3) {
      return 3;
    }
    return value;
  }

  public static async getSelectedBookId(): Promise<number> {
    const value: preferences.ValueType = await PreferencesService.getValue('selectedBookId', 0);
    return typeof value === 'number' ? value : 0;
  }

  public static async setSelectedBookId(value: number): Promise<void> {
    await PreferencesService.putValue('selectedBookId', value);
  }

  public static async getStudyOrderMode(): Promise<number> {
    const value: preferences.ValueType = await PreferencesService.getValue('studyOrderMode', 0);
    return typeof value === 'number' ? value : 0;
  }

  public static async setStudyOrderMode(value: number): Promise<void> {
    await PreferencesService.putValue('studyOrderMode', value);
  }

  public static async getStudyDetailVisible(): Promise<boolean> {
    const value: preferences.ValueType = await PreferencesService.getValue('studyDetailVisible', Constants.DEFAULT_STUDY_DETAIL_VISIBLE);
    return typeof value === 'boolean' ? value : Constants.DEFAULT_STUDY_DETAIL_VISIBLE;
  }

  public static async setStudyDetailVisible(value: boolean): Promise<void> {
    await PreferencesService.putValue('studyDetailVisible', value);
  }

  public static async getReviewDetailVisible(): Promise<boolean> {
    const value: preferences.ValueType = await PreferencesService.getValue(
      'reviewDetailVisible', Constants.DEFAULT_REVIEW_DETAIL_VISIBLE);
    return typeof value === 'boolean' ? value : Constants.DEFAULT_REVIEW_DETAIL_VISIBLE;
  }

  public static async setReviewDetailVisible(value: boolean): Promise<void> {
    await PreferencesService.putValue('reviewDetailVisible', value);
  }

  public static async getSearchEngine(): Promise<string> {
    const value: string = await PreferencesService.getString('searchEngine', Constants.DEFAULT_SEARCH_ENGINE);
    return PreferencesService.normalizeSearchEngine(value);
  }

  public static async setSearchEngine(value: string): Promise<void> {
    await PreferencesService.putValue('searchEngine', PreferencesService.normalizeSearchEngine(value));
  }

  public static async getSearchHistory(): Promise<string[]> {
    const raw: string = await PreferencesService.getString('searchHistory', Constants.DEFAULT_SEARCH_HISTORY);
    try {
      const value: string[] = JSON.parse(raw) as string[];
      return PreferencesService.normalizeSearchHistory(value);
    } catch {
      return [];
    }
  }

  public static async setSearchHistory(value: string[]): Promise<void> {
    await PreferencesService.putValue('searchHistory', JSON.stringify(
      PreferencesService.normalizeSearchHistory(value)));
  }

  private static normalizeSearchEngine(value: string): string {
    return value === Constants.SEARCH_ENGINE_YOUDAO ? Constants.SEARCH_ENGINE_YOUDAO :
      Constants.SEARCH_ENGINE_CAMBRIDGE;
  }

  private static normalizeSearchHistory(value: string[]): string[] {
    const normalized: string[] = [];
    for (let index: number = 0; index < value.length; index++) {
      const item: string = value[index].trim();
      if (item.length > 0 && normalized.indexOf(item) < 0) {
        normalized.push(item);
      }
      if (normalized.length >= Constants.DEFAULT_SEARCH_HISTORY_LIMIT) {
        break;
      }
    }
    return normalized;
  }

  public static async getReviewAutoPronounce(): Promise<boolean> {
    const value: preferences.ValueType = await PreferencesService.getValue(
      'reviewAutoPronounce', Constants.DEFAULT_REVIEW_AUTO_PRONOUNCE);
    return typeof value === 'boolean' ? value : Constants.DEFAULT_REVIEW_AUTO_PRONOUNCE;
  }

  public static async setReviewAutoPronounce(value: boolean): Promise<void> {
    await PreferencesService.putValue('reviewAutoPronounce', value);
  }

  public static async getReviewPronounceOnReveal(): Promise<boolean> {
    const value: preferences.ValueType = await PreferencesService.getValue(
      'reviewPronounceOnReveal', Constants.DEFAULT_REVIEW_PRONOUNCE_ON_REVEAL);
    return typeof value === 'boolean' ? value : Constants.DEFAULT_REVIEW_PRONOUNCE_ON_REVEAL;
  }

  public static async setReviewPronounceOnReveal(value: boolean): Promise<void> {
    await PreferencesService.putValue('reviewPronounceOnReveal', value);
  }

  public static async getReviewInListOrder(): Promise<boolean> {
    const value: preferences.ValueType = await PreferencesService.getValue(
      'reviewInListOrder', Constants.DEFAULT_REVIEW_IN_LIST_ORDER);
    return typeof value === 'boolean' ? value : Constants.DEFAULT_REVIEW_IN_LIST_ORDER;
  }

  public static async setReviewInListOrder(value: boolean): Promise<void> {
    await PreferencesService.putValue('reviewInListOrder', value);
  }

  public static async getForgettingCoefficient(): Promise<number> {
    const value: preferences.ValueType = await PreferencesService.getValue('forgettingCoefficient', Constants.DEFAULT_FORGETTING_COEFFICIENT);
    return typeof value === 'number' ? value : Constants.DEFAULT_FORGETTING_COEFFICIENT;
  }

  public static async setForgettingCoefficient(value: number): Promise<void> {
    await PreferencesService.putValue('forgettingCoefficient', value);
  }

  /** 获取今日已复习的单词 ID 列表 */
  public static async getReviewedWordIds(todayKey: string): Promise<number[]> {
    const raw: string = await PreferencesService.getString('reviewed_' + todayKey, '');
    if (raw.length === 0) return [];
    try {
      return JSON.parse(raw) as number[];
    } catch {
      return [];
    }
  }

  /** 保存今日已复习的单词 ID 列表 */
  public static async saveReviewedWordIds(todayKey: string, ids: number[]): Promise<void> {
    await PreferencesService.putValue('reviewed_' + todayKey, JSON.stringify(ids));
  }

  public static async getAiConfig(): Promise<AiConfig> {
    const provider: string = await PreferencesService.getString('aiProvider', Constants.DEFAULT_AI_PROVIDER);
    const providerKey: string = await PreferencesService.getAiApiKey(provider);
    const providerModel: string = await PreferencesService.getAiModel(provider);
    const legacyKey: string = await PreferencesService.getString('aiApiKey', Constants.DEFAULT_AI_API_KEY);
    return {
      aiProvider: provider,
      aiBaseUrl: await PreferencesService.getString('aiBaseUrl', Constants.DEFAULT_AI_BASE_URL),
      aiModel: providerModel.length > 0 ? providerModel : await PreferencesService.getString('aiModel', Constants.DEFAULT_AI_MODEL),
      aiApiKey: providerKey.length > 0 ? providerKey : legacyKey
    };
  }

  public static async saveAiConfig(config: AiConfig): Promise<void> {
    await PreferencesService.putValue('aiProvider', config.aiProvider);
    await PreferencesService.putValue('aiBaseUrl', config.aiBaseUrl);
    await PreferencesService.putValue('aiModel', config.aiModel);
    await PreferencesService.putValue('aiApiKey', config.aiApiKey);
    await PreferencesService.saveAiApiKey(config.aiProvider, config.aiApiKey);
    await PreferencesService.saveAiModel(config.aiProvider, config.aiModel);
  }

  public static async getAiApiKey(provider: string): Promise<string> {
    return await PreferencesService.getString(PreferencesService.getAiApiKeyPreferenceName(provider), Constants.DEFAULT_AI_API_KEY);
  }

  public static async saveAiApiKey(provider: string, apiKey: string): Promise<void> {
    await PreferencesService.putValue(PreferencesService.getAiApiKeyPreferenceName(provider), apiKey);
  }

  public static async getAiModel(provider: string): Promise<string> {
    return await PreferencesService.getString(PreferencesService.getAiModelPreferenceName(provider), Constants.DEFAULT_AI_MODEL);
  }

  public static async saveAiModel(provider: string, model: string): Promise<void> {
    await PreferencesService.putValue(PreferencesService.getAiModelPreferenceName(provider), model);
  }

  public static async getWebDavServerUrl(): Promise<string> {
    return await PreferencesService.getString('webDavServerUrl', Constants.DEFAULT_WEBDAV_SERVER_URL);
  }

  public static async setWebDavServerUrl(value: string): Promise<void> {
    await PreferencesService.putValue('webDavServerUrl', value);
  }

  public static async getWebDavRemotePath(): Promise<string> {
    return await PreferencesService.getString('webDavRemotePath', Constants.DEFAULT_WEBDAV_REMOTE_PATH);
  }

  public static async setWebDavRemotePath(value: string): Promise<void> {
    await PreferencesService.putValue('webDavRemotePath', value);
  }

  public static async getWebDavUsername(): Promise<string> {
    return await PreferencesService.getString('webDavUsername', Constants.DEFAULT_WEBDAV_USERNAME);
  }

  public static async setWebDavUsername(value: string): Promise<void> {
    await PreferencesService.putValue('webDavUsername', value);
  }

  public static async getWebDavPassword(): Promise<string> {
    return await PreferencesService.getString('webDavPassword', Constants.DEFAULT_WEBDAV_PASSWORD);
  }

  public static async setWebDavPassword(value: string): Promise<void> {
    await PreferencesService.putValue('webDavPassword', value);
  }

  public static async getWebDavSyncMode(): Promise<number> {
    const value: preferences.ValueType = await PreferencesService.getValue('webDavSyncMode', Constants.DEFAULT_WEBDAV_SYNC_MODE);
    return typeof value === 'number' ? PreferencesService.normalizeWebDavSyncMode(value) : Constants.DEFAULT_WEBDAV_SYNC_MODE;
  }

  public static async setWebDavSyncMode(value: number): Promise<void> {
    await PreferencesService.putValue('webDavSyncMode', PreferencesService.normalizeWebDavSyncMode(value));
  }

  public static async getWebDavSyncTimes(): Promise<string[]> {
    const raw: string = await PreferencesService.getString('webDavSyncTimes', Constants.DEFAULT_WEBDAV_SYNC_TIMES);
    try {
      const value: string[] = JSON.parse(raw) as string[];
      return value.length > 0 ? value : JSON.parse(Constants.DEFAULT_WEBDAV_SYNC_TIMES) as string[];
    } catch {
      return JSON.parse(Constants.DEFAULT_WEBDAV_SYNC_TIMES) as string[];
    }
  }

  public static async setWebDavSyncTimes(value: string[]): Promise<void> {
    await PreferencesService.putValue('webDavSyncTimes', JSON.stringify(value));
  }

  public static async getWebDavSyncHistory(): Promise<string[]> {
    const raw: string = await PreferencesService.getString('webDavSyncHistory', Constants.DEFAULT_WEBDAV_SYNC_HISTORY);
    try {
      return JSON.parse(raw) as string[];
    } catch {
      return [];
    }
  }

  public static async setWebDavSyncHistory(value: string[]): Promise<void> {
    await PreferencesService.putValue('webDavSyncHistory', JSON.stringify(value));
  }

  public static async getWebDavHistoryLimit(): Promise<number> {
    const value: preferences.ValueType = await PreferencesService.getValue('webDavHistoryLimit', Constants.DEFAULT_WEBDAV_HISTORY_LIMIT);
    return typeof value === 'number' ? PreferencesService.normalizeWebDavHistoryLimit(value) :
    Constants.DEFAULT_WEBDAV_HISTORY_LIMIT;
  }

  public static async setWebDavHistoryLimit(value: number): Promise<void> {
    await PreferencesService.putValue('webDavHistoryLimit', PreferencesService.normalizeWebDavHistoryLimit(value));
  }

  private static normalizeWebDavSyncMode(value: number): number {
    return value === 1 ? 1 : 0;
  }

  private static normalizeWebDavHistoryLimit(value: number): number {
    if (value === 30) {
      return 30;
    }
    if (value === 100) {
      return 100;
    }
    return 10;
  }

  private static getAiApiKeyPreferenceName(provider: string): string {
    if (provider === 'deepseek') {
      return 'aiApiKey_deepseek';
    }
    if (provider === 'xiaomi-mimo-token-plan') {
      return 'aiApiKey_xiaomi_mimo_token_plan';
    }
    return 'aiApiKey_custom';
  }

  private static getAiModelPreferenceName(provider: string): string {
    if (provider === 'deepseek') {
      return 'aiModel_deepseek';
    }
    if (provider === 'xiaomi-mimo-token-plan') {
      return 'aiModel_xiaomi_mimo_token_plan';
    }
    return 'aiModel_custom';
  }

  private static async getString(key: string, defaultValue: string): Promise<string> {
    const value: preferences.ValueType = await PreferencesService.getValue(key, defaultValue);
    return typeof value === 'string' ? value : defaultValue;
  }

  private static async getValue(key: string, defaultValue: preferences.ValueType): Promise<preferences.ValueType> {
    if (!PreferencesService.pref) {
      return defaultValue;
    }

    try {
      return await PreferencesService.pref.get(key, defaultValue);
    } catch (error) {
      console.error('Preferences get failed: ' + key + ', error: ' + JSON.stringify(error));
      return defaultValue;
    }
  }

  private static async putValue(key: string, value: preferences.ValueType): Promise<void> {
    if (!PreferencesService.pref) {
      return;
    }

    try {
      await PreferencesService.pref.put(key, value);
      await PreferencesService.pref.flush();
    } catch (error) {
      console.error('Preferences put failed: ' + key + ', error: ' + JSON.stringify(error));
    }
  }
}
