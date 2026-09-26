import { describe, expect, it } from '@ohos/hypium';
import { Driver, ON, Component } from '@ohos.UiTest';

/**
 * 页面跳转自动化示例。
 * 若页面标题文案后续调整，请同步更新 ON.text 中的匹配文本。
 */
export default function navigationTest(): void {
  describe('Navigation', () => {
    it('should navigate to study page', 0, async () => {
      const driver: Driver = Driver.create();
      await driver.delayMs(1000);

      const button: Component = await driver.findComponent(ON.text('开始学习'));
      await button.click();
      await driver.delayMs(800);

      const title: Component = await driver.findComponent(ON.text('开始学习'));
      expect(title !== null).assertTrue();
    });

    it('should navigate to review page', 0, async () => {
      const driver: Driver = Driver.create();
      await driver.delayMs(1000);

      const button: Component = await driver.findComponent(ON.text('复习单词'));
      await button.click();
      await driver.delayMs(800);

      const title: Component = await driver.findComponent(ON.text('复习单词'));
      expect(title !== null).assertTrue();
    });

    it('should navigate to settings page', 0, async () => {
      const driver: Driver = Driver.create();
      await driver.delayMs(1000);

      const button: Component = await driver.findComponent(ON.text('设置'));
      await button.click();
      await driver.delayMs(800);

      const title: Component = await driver.findComponent(ON.text('设置'));
      expect(title !== null).assertTrue();
    });

    it('should open word book management page from settings', 0, async () => {
      const driver: Driver = Driver.create();
      await driver.delayMs(1000);

      const settingsButton: Component = await driver.findComponent(ON.text('设置'));
      await settingsButton.click();
      await driver.delayMs(800);

      const manageButton: Component = await driver.findComponent(ON.text('词书管理'));
      await manageButton.click();
      await driver.delayMs(800);

      const title: Component = await driver.findComponent(ON.text('词书管理'));
      expect(title !== null).assertTrue();
    });
  });
}
