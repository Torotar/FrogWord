import {
  BlurStrategy,
  DividerShowType,
  HdsNavigationTitleBarOptions,
  ScrollEffectType,
  hdsMaterial
} from '@kit.UIDesignKit';

function getTitleMaterialType(materialEffectMode: number): hdsMaterial.MaterialType {
  if (materialEffectMode === 0) {
    return hdsMaterial.MaterialType.NONE;
  }
  if (materialEffectMode <= 2) {
    return hdsMaterial.MaterialType.ADAPTIVE;
  }
  try {
    const materialTypes: hdsMaterial.MaterialType[] = hdsMaterial.getSystemMaterialTypes();
    if (materialTypes.indexOf(hdsMaterial.MaterialType.IMMERSIVE) >= 0) {
      return hdsMaterial.MaterialType.IMMERSIVE;
    }
  } catch (error) {
  }
  return hdsMaterial.MaterialType.ADAPTIVE;
}

function getTitleMaterialLevel(materialEffectMode: number): hdsMaterial.MaterialLevel {
  if (materialEffectMode === 4) {
    return hdsMaterial.MaterialLevel.EXQUISITE;
  }
  if (materialEffectMode === 3) {
    return hdsMaterial.MaterialLevel.GENTLE;
  }
  if (materialEffectMode === 2) {
    return hdsMaterial.MaterialLevel.SMOOTH;
  }
  return hdsMaterial.MaterialLevel.ADAPTIVE;
}

export function createHdsTabTitleBarOptions(title: string, subtitle: string, darkMode: boolean,
  materialEffectMode: number): HdsNavigationTitleBarOptions {
  return {
    content: {
      title: {
        mainTitle: title,
        subTitle: subtitle
      },
      divider: {
        showType: DividerShowType.AUTO
      }
    },
    style: {
      scrollEffectOpts: {
        enableScrollEffect: true,
        scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
      },
      blurStrategy: BlurStrategy.ENABLE,
      originalStyle: {
        backgroundStyle: {
          backgroundColor: '#00000000',
          maskExtraHeight: 0,
          blurRadius: 18
        },
        contentStyle: {
          titleStyle: {
            mainTitleColor: darkMode ? '#F8FAFC' : '#1A1A2E',
            subTitleColor: darkMode ? '#CBD5E1' : '#8C8CA8'
          }
        }
      },
      scrollEffectStyle: {
        backgroundStyle: {
          backgroundColor: darkMode ? 'rgba(18, 20, 26, 0.72)' : 'rgba(245, 249, 255, 0.82)',
          maskExtraHeight: 0,
          blurRadius: 18
        },
        contentStyle: {
          titleStyle: {
            mainTitleColor: darkMode ? '#F8FAFC' : '#1A1A2E',
            subTitleColor: darkMode ? '#CBD5E1' : '#8C8CA8'
          },
          dividerStyle: {
            dividerColor: darkMode ? 'rgba(148, 163, 184, 0.18)' : 'rgba(148, 163, 184, 0.22)'
          }
        }
      },
      systemMaterialEffect: {
        materialType: getTitleMaterialType(materialEffectMode),
        materialLevel: getTitleMaterialLevel(materialEffectMode)
      }
    }
  };
}
