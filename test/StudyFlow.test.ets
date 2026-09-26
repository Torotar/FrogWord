import { describe, expect, it } from '@ohos/hypium';
import { Driver, ON, Component } from '@ohos.UiTest';

/**
 * 学习/搜索流程自动化示例。
 * 运行前建议保持默认词库已初始化，否则搜索结果可能为空。
 */
export default function studyFlowTest(): void {
  describe('StudyFlow', () => {
    it('should enter study page and show explanation action or complete state', 0, async () => {
      const driver: Driver = Driver.create();
      await driver.delayMs(1000);

      const startButton: Component = await driver.findComponent(ON.text('开始学习'));
      await startButton.click();
      await driver.delayMs(1000);

      const explanationButton: Component = await driver.findComponent(ON.text('查看释义'));
      const completedText: Component = await driver.findComponent(ON.text('今日学习目标已完成'));
      expect(explanationButton !== null || completedText !== null).assertTrue();
    });

    it('should open search page', 0, async () => {
      const driver: Driver = Driver.create();
      await driver.delayMs(1000);

      const searchButton: Component = await driver.findComponent(ON.text('搜索单词'));
      await searchButton.click();
      await driver.delayMs(800);

      const title: Component = await driver.findComponent(ON.text('搜索单词'));
      expect(title !== null).assertTrue();
    });
  });
}
