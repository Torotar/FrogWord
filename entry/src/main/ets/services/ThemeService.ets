import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { ThemePalette, ThemeColor } from '../utils/ThemeColor';
import { PreferencesService } from './PreferencesService';

export class ThemeService {
  /** Cached system dark mode state. Set by EntryAbility via setSystemDarkModeFlag. */
  private static systemDarkMode: boolean = false;

  /** Called from EntryAbility with a value read from UIAbilityContext.config.colorMode. */
  public static setSystemDarkModeFlag(isDark: boolean): void {
    ThemeService.systemDarkMode = isDark;
    ThemeService.broadcastResolvedDarkMode();
  }

  public static syncSystemDarkModeFlag(isDark: boolean): void {
    PreferencesService.getThemeMode().then((themeMode: number) => {
      if (themeMode === 0) {
        ThemeService.systemDarkMode = isDark;
        ThemeService.publishResolvedDarkMode(isDark);
      }
    }).catch((error: Error) => {
      console.error('ThemeService syncSystemDarkModeFlag failed: ' + JSON.stringify(error));
    });
  }

  public static async init(context: common.Context): Promise<void> {
    await PreferencesService.init(context);
    await ThemeService.refreshResolvedDarkMode();
  }

  /**
   * Resolves effective dark mode: 0=follow system, 1=light, 2=dark.
   */
  public static async isDarkMode(): Promise<boolean> {
    const themeMode: number = await PreferencesService.getThemeMode();
    if (themeMode === 2) {
      return true;
    }
    if (themeMode === 1) {
      return false;
    }
    // mode 0: follow system
    return ThemeService.systemDarkMode;
  }

  public static async getThemeMode(): Promise<number> {
    return await PreferencesService.getThemeMode();
  }

  public static async setThemeMode(value: number): Promise<boolean> {
    await PreferencesService.setThemeMode(value);
    const resolved: boolean = ThemeService.resolveDarkMode(value);
    ThemeService.publishResolvedDarkMode(resolved);
    return resolved;
  }

  public static async applyThemeMode(context: common.Context, value: number): Promise<boolean> {
    await PreferencesService.setThemeMode(value);
    ThemeService.applyApplicationColorMode(context, value);
    const resolved: boolean = value === 0 ? ThemeService.resolveContextDarkMode(context) : ThemeService.resolveDarkMode(value);
    if (value === 0) {
      ThemeService.systemDarkMode = resolved;
    }
    ThemeService.publishResolvedDarkMode(resolved);
    await ThemeService.applySystemBars(context, resolved);
    return resolved;
  }

  public static async refreshResolvedDarkMode(): Promise<boolean> {
    const resolved: boolean = await ThemeService.isDarkMode();
    ThemeService.publishResolvedDarkMode(resolved);
    return resolved;
  }

  public static async getPalette(): Promise<ThemePalette> {
    return ThemeColor.get(await ThemeService.isDarkMode());
  }

  public static async applySystemBars(context: common.Context, darkMode: boolean): Promise<void> {
    try {
      const mainWindow: window.Window = await window.getLastWindow(context);
      const backgroundColor: string = ThemeColor.get(darkMode).background;
      mainWindow.setWindowLayoutFullScreen(true);
      mainWindow.setWindowBackgroundColor(backgroundColor);
      mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: backgroundColor,
        statusBarContentColor: darkMode ? '#FFFFFF' : '#000000',
        navigationBarContentColor: darkMode ? '#FFFFFF' : '#000000'
      });
    } catch (error) {
      console.error('ThemeService applySystemBars failed: ' + JSON.stringify(error));
    }
  }

  private static broadcastResolvedDarkMode(): void {
    PreferencesService.getThemeMode().then((themeMode: number) => {
      const resolved: boolean = ThemeService.resolveDarkMode(themeMode);
      ThemeService.publishResolvedDarkMode(resolved);
    });
  }

  private static publishResolvedDarkMode(resolved: boolean): void {
    if (AppStorage.has('resolvedDarkMode')) {
      AppStorage.set('resolvedDarkMode', resolved);
    } else {
      AppStorage.setOrCreate('resolvedDarkMode', resolved);
    }
  }

  public static applyApplicationColorMode(context: common.Context, themeMode: number): void {
    try {
      let colorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
      if (themeMode === 2) {
        colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      } else if (themeMode === 1) {
        colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
      }
      context.getApplicationContext().setColorMode(colorMode);
    } catch (error) {
      console.error('ThemeService applyApplicationColorMode failed: ' + JSON.stringify(error));
    }
  }

  private static resolveDarkMode(themeMode: number): boolean {
    if (themeMode === 2) {
      return true;
    }
    if (themeMode === 1) {
      return false;
    }
    return ThemeService.systemDarkMode;
  }

  private static resolveContextDarkMode(context: common.Context): boolean {
    try {
      const colorMode: ConfigurationConstant.ColorMode | undefined = (context as common.UIAbilityContext).config.colorMode;
      return colorMode !== undefined && colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    } catch (error) {
      console.error('ThemeService resolveContextDarkMode failed: ' + JSON.stringify(error));
      return ThemeService.systemDarkMode;
    }
  }
}
