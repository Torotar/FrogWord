/**
 * Fisher-Yates 洗牌算法
 * 时间复杂度 O(n)，空间复杂度 O(1)
 * 每个元素出现在任意位置的概率均为 1/n!
 */
export class ArrayUtil {
  public static shuffle<T>(arr: T[]): T[] {
    const result: T[] = [...arr];
    for (let i: number = result.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const temp: T = result[i];
      result[i] = result[j];
      result[j] = temp;
    }
    return result;
  }
}
