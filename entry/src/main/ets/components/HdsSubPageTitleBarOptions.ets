import {
  BlurStrategy,
  DividerShowType,
  HdsNavigationMenuItemOptions,
  HdsNavigationTitleBarOptions,
  ScrollEffectType,
  hdsMaterial
} from '@kit.UIDesignKit';
import router from '@ohos.router';

const SUB_TITLE_MASK_EXTRA_HEIGHT: number = 0;
const SUB_TITLE_BLUR_RADIUS: number = 28;

function getTitleMaterialType(materialEffectMode: number): hdsMaterial.MaterialType {
  if (materialEffectMode === 0) {
    return hdsMaterial.MaterialType.NONE;
  }
  return hdsMaterial.MaterialType.IMMERSIVE;
}

function getTitleMaterialLevel(materialEffectMode: number): hdsMaterial.MaterialLevel {
  if (materialEffectMode >= 3) {
    return hdsMaterial.MaterialLevel.EXQUISITE;
  }
  if (materialEffectMode === 2) {
    return hdsMaterial.MaterialLevel.GENTLE;
  }
  if (materialEffectMode === 1) {
    return hdsMaterial.MaterialLevel.SMOOTH;
  }
  return hdsMaterial.MaterialLevel.SMOOTH;
}

export function createHdsSubPageTitleBarOptions(title: string, darkMode: boolean,
  materialEffectMode: number, onBack?: () => void,
  menuItems?: Array<HdsNavigationMenuItemOptions>): HdsNavigationTitleBarOptions {
  const titleColor: string = darkMode ? '#F8FAFC' : '#1A1A2E';
  return {
    content: {
      title: {
        mainTitle: title
      },
      menu: menuItems !== undefined ? {
        value: menuItems,
        maxCount: menuItems.length
      } : undefined,
      backIcon: {
        isEnabled: true,
        action: () => {
          if (onBack) {
            onBack();
            return;
          }
          router.back();
        }
      },
      divider: {
        showType: DividerShowType.AUTO
      }
    },
    avoidLayoutSafeArea: true,
    enableComponentSafeArea: true,
    style: {
      scrollEffectOpts: {
        enableScrollEffect: false,
        scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
      },
      blurStrategy: BlurStrategy.DISABLE,
      thermoCtrl: true,
      originalStyle: {
        backgroundStyle: {
          backgroundColor: '#00000000',
          maskExtraHeight: SUB_TITLE_MASK_EXTRA_HEIGHT,
          blurRadius: SUB_TITLE_BLUR_RADIUS
        },
        contentStyle: {
          titleStyle: {
            mainTitleColor: titleColor
          },
          backIconStyle: {
            backgroundColor: '#00000000',
            iconColor: titleColor,
            textColor: titleColor
          },
          menuStyle: {
            backgroundColor: '#00000000',
            iconColor: titleColor,
            textColor: titleColor
          }
        }
      },
      scrollEffectStyle: {
        backgroundStyle: {
          backgroundColor: darkMode ? 'rgba(18, 20, 26, 0.52)' : 'rgba(245, 249, 255, 0.58)',
          maskExtraHeight: SUB_TITLE_MASK_EXTRA_HEIGHT,
          blurRadius: SUB_TITLE_BLUR_RADIUS
        },
        contentStyle: {
          titleStyle: {
            mainTitleColor: titleColor
          },
          backIconStyle: {
            backgroundColor: '#00000000',
            iconColor: titleColor,
            textColor: titleColor
          },
          menuStyle: {
            backgroundColor: '#00000000',
            iconColor: titleColor,
            textColor: titleColor
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
