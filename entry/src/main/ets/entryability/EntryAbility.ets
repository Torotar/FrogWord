import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { DatabaseService } from '../services/DatabaseService';
import { PreferencesService } from '../services/PreferencesService';
import { StudySessionService } from '../services/StudySessionService';
import { ThemeService } from '../services/ThemeService';
import { Constants } from '../utils/Constants';
import { ThemeColor } from '../utils/ThemeColor';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    AppStorage.setOrCreate('mainTabTransitionDirection', 0);
    AppStorage.setOrCreate('materialEffectMode', 1);
    AppStorage.setOrCreate('studyDailyGoal', Constants.DEFAULT_DAILY_GOAL);
    AppStorage.setOrCreate('studyReviewGoal', Constants.DEFAULT_REVIEW_GOAL);
    AppStorage.setOrCreate('studyReviewGroupSize', Constants.DEFAULT_REVIEW_GROUP_SIZE);
    this.syncThemeSystemDarkMode();
    DatabaseService.init(this.context).catch((error: Error) => {
      hilog.error(DOMAIN, 'testTag', 'Database init failed. Cause: %{public}s', JSON.stringify(error));
    });
    PreferencesService.init(this.context).catch((error: Error) => {
      hilog.error(DOMAIN, 'testTag', 'Preferences init failed. Cause: %{public}s', JSON.stringify(error));
    });
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    StudySessionService.flushActiveSessionDuration().catch((error: Error) => {
      hilog.error(DOMAIN, 'testTag', 'Flush study session onDestroy failed. Cause: %{public}s', JSON.stringify(error));
    });
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    this.prepareThemeAndLoadContent(windowStage);
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground — re-sync system dark mode in case it changed while backgrounded
    this.syncThemeSystemDarkMode(false);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    try {
      const colorMode: ConfigurationConstant.ColorMode | undefined = newConfig.colorMode;
      const isDark: boolean = colorMode !== undefined && colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      ThemeService.syncSystemDarkModeFlag(isDark);
    } catch (e) {
      // ignore
    }
  }

  onBackground(): void {
    // Ability has back to background
    StudySessionService.flushActiveSessionDuration().catch((error: Error) => {
      hilog.error(DOMAIN, 'testTag', 'Flush study session onBackground failed. Cause: %{public}s', JSON.stringify(error));
    });
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }

  private syncThemeSystemDarkMode(force: boolean = true): void {
    try {
      const colorMode: ConfigurationConstant.ColorMode | undefined = this.context.config.colorMode;
      const isDark: boolean = colorMode !== undefined && colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      if (force) {
        ThemeService.setSystemDarkModeFlag(isDark);
      } else {
        ThemeService.syncSystemDarkModeFlag(isDark);
      }
    } catch (e) {
      if (force) {
        ThemeService.setSystemDarkModeFlag(false);
      } else {
        ThemeService.syncSystemDarkModeFlag(false);
      }
    }
  }

  private configureImmersiveWindow(windowStage: window.WindowStage): void {
    try {
      const mainWindow: window.Window = windowStage.getMainWindowSync();
      mainWindow.setWindowLayoutFullScreen(true);
      PreferencesService.init(this.context).then(async () => {
        const darkMode: boolean = await ThemeService.isDarkMode();
        const backgroundColor: string = ThemeColor.get(darkMode).background;
        mainWindow.setWindowBackgroundColor(backgroundColor);
        mainWindow.setWindowSystemBarProperties({
          statusBarColor: '#00000000',
          navigationBarColor: backgroundColor,
          statusBarContentColor: darkMode ? '#FFFFFF' : '#000000',
          navigationBarContentColor: darkMode ? '#FFFFFF' : '#000000'
        });
      }).catch((error: Error) => {
        hilog.error(DOMAIN, 'testTag', 'Immersive preferences failed. Cause: %{public}s', JSON.stringify(error));
      });
    } catch (error) {
      hilog.error(DOMAIN, 'testTag', 'Immersive window failed. Cause: %{public}s', JSON.stringify(error));
    }
  }

  private async prepareThemeAndLoadContent(windowStage: window.WindowStage): Promise<void> {
    try {
      await PreferencesService.init(this.context);
      AppStorage.setOrCreate('materialEffectMode', await PreferencesService.getMaterialEffectMode());
      AppStorage.setOrCreate('studyDailyGoal', await PreferencesService.getDailyGoal());
      AppStorage.setOrCreate('studyReviewGoal', await PreferencesService.getReviewGoal());
      AppStorage.setOrCreate('studyReviewGroupSize', await PreferencesService.getReviewGroupSize());
      const themeMode: number = await ThemeService.getThemeMode();
      ThemeService.applyApplicationColorMode(this.context, themeMode);
      await ThemeService.refreshResolvedDarkMode();
      this.configureImmersiveWindow(windowStage);
    } catch (error) {
      hilog.error(DOMAIN, 'testTag', 'Prepare theme failed. Cause: %{public}s', JSON.stringify(error));
      this.configureImmersiveWindow(windowStage);
    }

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }
}
