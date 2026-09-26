import { describe, expect, it } from '@ohos/hypium';
import { Driver, ON, Component } from '@ohos.UiTest';

/**
 * 设置页 UI 自动化示例：覆盖更多设置、AI 配置、深色模式、学习计划入口。
 */
export default function settingsTest(): void {
  describe('Settings', () => {
    it('should show theme mode selector', 0, async () => {
      const driver: Driver = Driver.create();
      await driver.delayMs(1000);

      const settingsButton: Component = await driver.findComponent(ON.text('设置'));
      await settingsButton.click();
      await driver.delayMs(800);

      const darkModeText: Component = await driver.findComponent(ON.text('显示模式'));
      expect(darkModeText !== null).assertTrue();
    });

    it('should open ai config page and show save button', 0, async () => {
      const driver: Driver = Driver.create();
      await driver.delayMs(1000);

      const settingsButton: Component = await driver.findComponent(ON.text('设置'));
      await settingsButton.click();
      await driver.delayMs(800);

      const moreSettingsButton: Component = await driver.findComponent(ON.text('更多设置'));
      await moreSettingsButton.click();
      await driver.delayMs(800);

      const aiConfigButton: Component = await driver.findComponent(ON.text('AI 接口配置'));
      await aiConfigButton.click();
      await driver.delayMs(800);

      expect((await driver.findComponent(ON.text('保存配置'))) !== null).assertTrue();
      expect((await driver.findComponent(ON.text('测试 AI 接口'))) !== null).assertTrue();
    });

    it('should open study plan page', 0, async () => {
      const driver: Driver = Driver.create();
      await driver.delayMs(1000);

      const settingsButton: Component = await driver.findComponent(ON.text('设置'));
      await settingsButton.click();
      await driver.delayMs(800);

      const planButton: Component = await driver.findComponent(ON.text('学习计划'));
      await planButton.click();
      await driver.delayMs(800);

      const title: Component = await driver.findComponent(ON.text('学习计划'));
      expect(title !== null).assertTrue();
    });
  });
}
