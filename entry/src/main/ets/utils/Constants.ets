export class Constants {
  public static readonly DEBUG_MODE: boolean = true;
  public static readonly APP_VERSION: string = '1.5.3';
  public static readonly BUILD_TYPE: string = 'debug';

  public static readonly DATABASE_NAME: string = 'wordflow.db';
  public static readonly DATABASE_VERSION: number = 4;
  public static readonly PREFERENCES_NAME: string = 'wordflow_settings';

  public static readonly DEFAULT_DAILY_GOAL: number = 20;
  public static readonly DEFAULT_REVIEW_GOAL: number = 30;
  public static readonly DEFAULT_NEW_WORD_GROUP_SIZE: number = 10;
  public static readonly DEFAULT_REVIEW_GROUP_SIZE: number = 10;
  public static readonly DEFAULT_RELEARN_GOAL: number = 30;
  public static readonly DEFAULT_RELEARN_GROUP_SIZE: number = 10;
  public static readonly DEFAULT_WEEKLY_DAYS: number = 5;
  public static readonly DEFAULT_WEEKEND_ENABLED: boolean = true;
  public static readonly DEFAULT_TARGET_DATE: string = '';
  public static readonly DEFAULT_REMINDER_ENABLED: boolean = false;
  public static readonly DEFAULT_THEME_MODE: number = 0; // 0=follow system, 1=light, 2=dark
  public static readonly DEFAULT_MATERIAL_EFFECT_MODE: number = 2; // 0=off, 1=low, 2=medium, 3=high
  public static readonly DEFAULT_STUDY_DETAIL_VISIBLE: boolean = false;
  public static readonly DEFAULT_REVIEW_DETAIL_VISIBLE: boolean = false;
  public static readonly DEFAULT_REVIEW_AUTO_PRONOUNCE: boolean = false;
  public static readonly DEFAULT_REVIEW_PRONOUNCE_ON_REVEAL: boolean = false;
  public static readonly DEFAULT_REVIEW_IN_LIST_ORDER: boolean = true;
  public static readonly PRONUNCIATION_ANIMATION_FRAME_INTERVAL_MS: number = 220;
  public static readonly DEFAULT_FORGETTING_COEFFICIENT: number = 0.5;
  public static readonly FORGETTING_COEFFICIENT_MIN: number = 0.3;
  public static readonly FORGETTING_COEFFICIENT_MAX: number = 1.0;
  public static readonly FORGETTING_COEFFICIENT_STEP: number = 0.1;
  public static readonly SEARCH_ENGINE_CAMBRIDGE: string = 'cambridge';
  public static readonly SEARCH_ENGINE_YOUDAO: string = 'youdao';
  public static readonly DEFAULT_SEARCH_ENGINE: string = Constants.SEARCH_ENGINE_CAMBRIDGE;
  public static readonly DEFAULT_SEARCH_HISTORY: string = '[]';
  public static readonly DEFAULT_SEARCH_HISTORY_LIMIT: number = 10;
  public static readonly DEFAULT_AI_PROVIDER: string = 'openai-compatible';
  public static readonly DEFAULT_AI_BASE_URL: string = '';
  public static readonly DEFAULT_AI_MODEL: string = '';
  public static readonly DEFAULT_AI_API_KEY: string = '';
  public static readonly DEFAULT_WEBDAV_SERVER_URL: string = '';
  public static readonly DEFAULT_WEBDAV_REMOTE_PATH: string = '/wordcard';
  public static readonly DEFAULT_WEBDAV_USERNAME: string = '';
  public static readonly DEFAULT_WEBDAV_PASSWORD: string = '';
  public static readonly DEFAULT_WEBDAV_SYNC_MODE: number = 0; // 0=scheduled, 1=on data change
  public static readonly DEFAULT_WEBDAV_SYNC_TIMES: string = '["08:00","12:30","22:00"]';
  public static readonly DEFAULT_WEBDAV_SYNC_HISTORY: string = '[]';
  public static readonly DEFAULT_WEBDAV_HISTORY_LIMIT: number = 10;
}
