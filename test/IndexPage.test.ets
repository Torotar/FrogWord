import { describe, expect, it } from '@ohos/hypium';
import { Driver, ON, Component } from '@ohos.UiTest';

/**
 * 基础 UI 自动化示例：验证首页启动和核心统计/入口是否显示。
 * 说明：不同 DevEco Studio / SDK 版本中 UiTest API 名称可能略有差异，
 * 如 ON.text / driver.delayMs 报错，请按当前 SDK 自动补全调整。
 */
export default function indexPageTest(): void {
  describe('IndexPage', () => {
    it('should show home title and stat cards', 0, async () => {
      const driver: Driver = Driver.create();
      await driver.delayMs(1000);

      const title: Component = await driver.findComponent(ON.text('WordFlow'));
      expect(title !== null).assertTrue();

      const todayLearn: Component = await driver.findComponent(ON.text('今日学习'));
      expect(todayLearn !== null).assertTrue();

      const pendingReview: Component = await driver.findComponent(ON.text('待复习'));
      expect(pendingReview !== null).assertTrue();

      const mastered: Component = await driver.findComponent(ON.text('已掌握'));
      expect(mastered !== null).assertTrue();
    });

    it('should show primary actions', 0, async () => {
      const driver: Driver = Driver.create();
      await driver.delayMs(1000);

      expect((await driver.findComponent(ON.text('开始学习'))) !== null).assertTrue();
      expect((await driver.findComponent(ON.text('复习单词'))) !== null).assertTrue();
      expect((await driver.findComponent(ON.text('设置'))) !== null).assertTrue();
      expect((await driver.findComponent(ON.text('搜索单词'))) !== null).assertTrue();
    });
  });
}
