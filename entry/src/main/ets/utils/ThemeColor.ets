export interface ThemePalette {
  background: string;
  cardBackground: string;
  primary: string;
  primaryLight: string;
  textPrimary: string;
  textSecondary: string;
  border: string;
  danger: string;
  success: string;
}

export class ThemeColor {
  public static light(): ThemePalette {
    return {
      background: '#F6FAFF',
      cardBackground: '#FFFFFF',
      primary: '#2563EB',
      primaryLight: '#EAF2FF',
      textPrimary: '#0F172A',
      textSecondary: '#64748B',
      border: '#E2E8F0',
      danger: '#DC2626',
      success: '#16A34A'
    };
  }

  public static dark(): ThemePalette {
    return {
      background: '#0B1220',
      cardBackground: '#111827',
      primary: '#60A5FA',
      primaryLight: '#1E3A8A',
      textPrimary: '#F8FAFC',
      textSecondary: '#CBD5E1',
      border: '#334155',
      danger: '#F87171',
      success: '#4ADE80'
    };
  }

  public static get(darkMode: boolean): ThemePalette {
    return darkMode ? ThemeColor.dark() : ThemeColor.light();
  }
}
