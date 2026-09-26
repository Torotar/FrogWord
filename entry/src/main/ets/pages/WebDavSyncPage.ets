import { common } from '@kit.AbilityKit';
import router from '@ohos.router';
import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { SUB_PAGE_CONTENT_OVERLAP } from '../components/HdsSubPageLayout';
import { createHdsSubPageTitleBarOptions } from '../components/HdsSubPageTitleBarOptions';
import { DatabaseService } from '../services/DatabaseService';
import { PreferencesService } from '../services/PreferencesService';
import { WebDavBackupService, WebDavRestoreSummary } from '../services/WebDavBackupService';
import { WebDavConnectionTestResult, WebDavService, WebDavTransferResult } from '../services/WebDavService';
import { Constants } from '../utils/Constants';
import { ThemeColor } from '../utils/ThemeColor';

@CustomDialog
@Component
struct SyncTimeOptionsDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: this });
  darkMode: boolean = false;
  options: string[] = [];
  @State selectedTimes: string[] = [];
  onConfirm: (value: string[]) => void = (value: string[]) => {};

  private isSelected(time: string): boolean {
    return this.selectedTimes.indexOf(time) >= 0;
  }

  private toggleTime(time: string): void {
    if (this.isSelected(time)) {
      if (this.selectedTimes.length <= 1) {
        return;
      }
      this.selectedTimes = this.selectedTimes.filter((item: string) => item !== time);
      return;
    }
    this.selectedTimes = [...this.selectedTimes, time].sort();
  }

  build() {
    Column() {
      Text('同步时间选项')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .margin({ top: 8 })

      Text('选择需要定时同步的时间，至少保留一个。')
        .fontSize(12)
        .fontColor(ThemeColor.get(this.darkMode).textSecondary)
        .lineHeight(18)
        .textAlign(TextAlign.Center)
        .margin({ top: 6, bottom: 8 })

      ForEach(this.options, (time: string) => {
        Row() {
          Text(time)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isSelected(time) ? ThemeColor.get(this.darkMode).primary : ThemeColor.get(this.darkMode).textPrimary)
            .layoutWeight(1)

          Text(this.isSelected(time) ? '已选' : '选择')
            .fontSize(12)
            .fontColor(this.isSelected(time) ? Color.White : ThemeColor.get(this.darkMode).primary)
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .backgroundColor(this.isSelected(time) ? ThemeColor.get(this.darkMode).primary : ThemeColor.get(this.darkMode).primaryLight)
            .borderRadius(10)
        }
        .width('100%')
        .height(46)
        .padding({ left: 14, right: 10 })
        .margin({ top: 8 })
        .backgroundColor(this.isSelected(time) ? ThemeColor.get(this.darkMode).primaryLight : (this.darkMode ? '#1E293B' : '#F8FAFC'))
        .border({ width: 1, color: this.isSelected(time) ? ThemeColor.get(this.darkMode).primary : ThemeColor.get(this.darkMode).border })
        .borderRadius(12)
        .onClick(() => {
          this.toggleTime(time);
        })
      }, (time: string) => time)

      Row() {
        Button('取消')
          .width('44%')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .role(ButtonRole.NORMAL)
          .fontColor(ThemeColor.get(this.darkMode).textPrimary)
          .onClick(() => {
            this.controller.close();
          })

        Button('确定')
          .width('44%')
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .controlSize(ControlSize.NORMAL)
          .role(ButtonRole.NORMAL)
          .onClick(() => {
            this.onConfirm(this.selectedTimes);
            this.controller.close();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 16 })
    }
    .padding({ left: 24, right: 24, top: 16, bottom: 20 })
    .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
    .borderRadius(20)
  }
}

@Entry
@Component
struct WebDavSyncPage {
  @State private isLoading: boolean = true;
  @State private serverUrl: string = Constants.DEFAULT_WEBDAV_SERVER_URL;
  @State private remotePath: string = Constants.DEFAULT_WEBDAV_REMOTE_PATH;
  @State private username: string = Constants.DEFAULT_WEBDAV_USERNAME;
  @State private password: string = Constants.DEFAULT_WEBDAV_PASSWORD;
  @State private syncMode: number = Constants.DEFAULT_WEBDAV_SYNC_MODE;
  @State private syncTimes: string[] = [];
  @State private syncHistory: string[] = [];
  @State private historyLimit: number = Constants.DEFAULT_WEBDAV_HISTORY_LIMIT;
  @State private historyLimitText: string = '最近 10 条';
  @State private visibleSyncHistory: string[] = [];
  @State private historyRevision: number = 0;
  @State private formRevision: number = 0;
  @StorageLink('resolvedDarkMode') darkMode: boolean = false;
  @StorageLink('materialEffectMode') materialEffectMode: number = Constants.DEFAULT_MATERIAL_EFFECT_MODE;
  private pageScroller: Scroller = new Scroller();
  private dialogController: CustomDialogController | null = null;
  private readonly syncTimeOptions: string[] = ['06:00', '08:00', '12:30', '18:00', '22:00', '23:30'];
  private readonly historyLimitOptions: number[] = [10, 30, 100];

  aboutToAppear(): void {
    this.loadConfig();
  }

  private async loadConfig(): Promise<void> {
    this.isLoading = true;
    try {
      const context = getContext(this) as common.Context;
      await DatabaseService.init(context);
      await PreferencesService.init(context);
      this.serverUrl = await PreferencesService.getWebDavServerUrl();
      const savedRemotePath: string = this.normalizeRemotePath(await PreferencesService.getWebDavRemotePath());
      this.remotePath = savedRemotePath.length > 0 ? savedRemotePath : Constants.DEFAULT_WEBDAV_REMOTE_PATH;
      this.username = await PreferencesService.getWebDavUsername();
      this.password = await PreferencesService.getWebDavPassword();
      this.syncMode = await PreferencesService.getWebDavSyncMode();
      this.syncTimes = await PreferencesService.getWebDavSyncTimes();
      this.syncHistory = await PreferencesService.getWebDavSyncHistory();
      this.historyLimit = this.normalizeHistoryLimit(await PreferencesService.getWebDavHistoryLimit());
      await PreferencesService.setWebDavHistoryLimit(this.historyLimit);
      this.refreshHistoryView();
      this.formRevision++;
    } catch (error) {
      console.error('WebDavSyncPage loadConfig failed: ' + JSON.stringify(error));
      this.showToast('WebDAV 配置加载失败');
    } finally {
      this.isLoading = false;
    }
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({
      message: message,
      duration: 2000
    });
  }

  private async saveConfig(showSuccess: boolean = true): Promise<void> {
    try {
      this.remotePath = this.getRemotePathForSync();
      await PreferencesService.setWebDavServerUrl(this.serverUrl.trim());
      await PreferencesService.setWebDavRemotePath(this.remotePath);
      await PreferencesService.setWebDavUsername(this.username.trim());
      await PreferencesService.setWebDavPassword(this.password);
      await PreferencesService.setWebDavSyncMode(this.syncMode);
      await PreferencesService.setWebDavSyncTimes(this.syncTimes);
      if (showSuccess) {
        this.showToast('WebDAV 配置已保存');
      }
    } catch (error) {
      console.error('WebDavSyncPage saveConfig failed: ' + JSON.stringify(error));
      this.showToast('WebDAV 配置保存失败');
    }
  }

  private isConfigReady(): boolean {
    return this.serverUrl.trim().length > 0 && this.getRemotePathForSync().length > 0 &&
      this.username.trim().length > 0 && this.password.length > 0;
  }

  private async testConnection(): Promise<void> {
    if (!this.isConfigReady()) {
      this.showToast('请先填写服务器地址、同步路径、用户名和授权密码');
      return;
    }
    await this.saveConfig(false);
    this.showToast('正在测试 WebDAV 连接...');
    const result: WebDavConnectionTestResult =
      await WebDavService.testConnection(this.serverUrl, this.remotePath, this.username, this.password);
    this.showToast(result.message);
  }

  private async uploadData(): Promise<void> {
    if (!this.isConfigReady()) {
      this.showToast('请先完成 WebDAV 配置');
      return;
    }
    try {
      await this.saveConfig(false);
      this.showToast('正在上传数据...');
      const backupJson: string = await WebDavBackupService.exportBackupJson();
      const result: WebDavTransferResult = await WebDavService.uploadTextFile(
        this.serverUrl,
        this.remotePath,
        this.username,
        this.password,
        WebDavBackupService.BACKUP_FILE_NAME,
        backupJson
      );
      if (result.success) {
        await this.appendSyncHistory('上传成功');
        this.showToast('上传成功，已保存到 ' + this.remoteBackupFilePath());
      } else {
        await this.appendSyncHistory('上传失败');
        this.showToast(result.message);
      }
    } catch (error) {
      console.error('WebDavSyncPage uploadData failed: ' + JSON.stringify(error));
      await this.appendSyncHistory('上传失败');
      this.showToast('上传失败，请稍后重试');
    }
  }

  private async downloadData(): Promise<void> {
    if (!this.isConfigReady()) {
      this.showToast('请先完成 WebDAV 配置');
      return;
    }
    try {
      await this.saveConfig(false);
      this.showToast('正在拉取数据...');
      const result: WebDavTransferResult = await WebDavService.downloadTextFile(
        this.serverUrl,
        this.remotePath,
        this.username,
        this.password,
        WebDavBackupService.BACKUP_FILE_NAME
      );
      if (!result.success) {
        await this.appendSyncHistory('拉取失败');
        this.showToast(result.message);
        return;
      }

      const summary: WebDavRestoreSummary = await WebDavBackupService.restoreBackupJson(result.content);
      await this.appendSyncHistory('拉取成功');
      this.showToast('拉取成功，已恢复 ' + summary.wordCount.toString() + ' 个单词');
    } catch (error) {
      console.error('WebDavSyncPage downloadData failed: ' + JSON.stringify(error));
      await this.appendSyncHistory('拉取失败');
      this.showToast('拉取失败：' + this.getErrorMessage(error));
    }
  }

  private async appendSyncHistory(action: string): Promise<void> {
    const item: string = this.formatCurrentTime() + ' · ' + action + ' · 已触发';
    const nextHistory: string[] = [item, ...this.syncHistory].slice(0, 100);
    this.syncHistory = nextHistory;
    this.refreshHistoryView();
    await PreferencesService.setWebDavSyncHistory(nextHistory);
  }

  private formatCurrentTime(): string {
    const now: Date = new Date();
    return now.getFullYear().toString() + '-' + this.pad(now.getMonth() + 1) + '-' + this.pad(now.getDate()) + ' ' +
      this.pad(now.getHours()) + ':' + this.pad(now.getMinutes());
  }

  private pad(value: number): string {
    return value < 10 ? '0' + value.toString() : value.toString();
  }

  private getErrorMessage(error: Error | Object): string {
    const failure: Error = error as Error;
    if (failure.message && failure.message.length > 0) {
      return failure.message;
    }
    return '备份文件解析或恢复失败';
  }

  private normalizeRemotePath(value: string): string {
    const trimmed: string = value.trim();
    if (trimmed.length === 0 || trimmed === '/') {
      return '';
    }
    const path: string = trimmed.startsWith('/') ? trimmed : '/' + trimmed;
    return path.endsWith('/') ? path.substring(0, path.length - 1) : path;
  }

  private getRemotePathForSync(): string {
    const normalized: string = this.normalizeRemotePath(this.remotePath);
    return normalized.length > 0 ? normalized : Constants.DEFAULT_WEBDAV_REMOTE_PATH;
  }

  private remoteBackupFilePath(): string {
    const path: string = this.getRemotePathForSync();
    return path.endsWith('/') ? path + WebDavBackupService.BACKUP_FILE_NAME : path + '/' + WebDavBackupService.BACKUP_FILE_NAME;
  }

  private updateSyncMode(index: number): void {
    this.syncMode = index === 1 ? 1 : 0;
  }

  private syncModeLabel(): string {
    return this.syncMode === 1 ? '数据变化后同步' : '定时同步';
  }

  private syncModeDescription(): string {
    if (this.syncMode === 1) {
      return '单词、词库或学习记录变化后触发同步，时间选项会保留备用。';
    }
    return '按选定时间自动同步，也可以手动上传或拉取。';
  }

  private getSyncModeOptions(): SelectOption[] {
    return [
      { value: '定时同步' },
      { value: '数据变化后同步' }
    ];
  }

  private getHistoryLimitOptions(): SelectOption[] {
    return [
      { value: '最近 10 条' },
      { value: '最近 30 条' },
      { value: '最近 100 条' }
    ];
  }

  private historyLimitSelectedIndex(): number {
    const index: number = this.historyLimitOptions.indexOf(this.historyLimit);
    return index >= 0 ? index : 0;
  }

  private syncTimeSummary(): string {
    if (this.syncTimes.length === 0) {
      return '未选择';
    }
    if (this.syncTimes.length <= 3) {
      return this.syncTimes.join('、');
    }
    return this.syncTimes[0] + '、' + this.syncTimes[1] + ' 等 ' + this.syncTimes.length.toString() + ' 个';
  }

  private async updateSyncTimes(value: string[]): Promise<void> {
    this.syncTimes = [...value].sort();
    await PreferencesService.setWebDavSyncTimes(this.syncTimes);
  }

  private updateHistoryLimit(value: number): void {
    this.historyLimit = this.normalizeHistoryLimit(value);
    this.refreshHistoryView();
    this.saveHistoryLimit(this.historyLimit);
  }

  private async saveHistoryLimit(value: number): Promise<void> {
    try {
      await PreferencesService.setWebDavHistoryLimit(value);
    } catch (error) {
      console.error('WebDavSyncPage saveHistoryLimit failed: ' + JSON.stringify(error));
      this.showToast('同步记录条数保存失败');
    }
  }

  private normalizeHistoryLimit(value: number): number {
    if (this.historyLimitOptions.indexOf(value) >= 0) {
      return value;
    }
    return Constants.DEFAULT_WEBDAV_HISTORY_LIMIT;
  }

  private historyLimitLabel(): string {
    return '最近 ' + this.historyLimit.toString() + ' 条';
  }

  private refreshHistoryView(): void {
    const count: number = Math.min(this.historyLimit, this.syncHistory.length);
    this.historyLimitText = '最近 ' + this.historyLimit.toString() + ' 条';
    this.visibleSyncHistory = this.syncHistory.slice(0, count);
    this.historyRevision++;
  }

  private openSyncTimeOptions(): void {
    if (this.dialogController) {
      this.dialogController.close();
      this.dialogController = null;
    }
    this.dialogController = new CustomDialogController({
      builder: SyncTimeOptionsDialog({
        darkMode: this.darkMode,
        options: this.syncTimeOptions,
        selectedTimes: this.syncTimes,
        onConfirm: (value: string[]) => {
          this.updateSyncTimes(value);
        }
      }),
      customStyle: false,
      alignment: DialogAlignment.Center,
      autoCancel: true
    });
    this.dialogController.open();
  }

  private visibleHistory(): string[] {
    return this.visibleSyncHistory;
  }

  @Builder
  private optionButton(label: string, onClick: () => void) {
    Text(label)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor(ThemeColor.get(this.darkMode).primary)
      .width(104)
      .height(34)
      .textAlign(TextAlign.Center)
      .backgroundColor(ThemeColor.get(this.darkMode).primaryLight)
      .borderRadius(12)
      .onClick(() => {
        onClick();
      })
  }

  @Builder
  private sectionTitle(title: string, subtitle: string = '') {
    Column() {
      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .width('100%')

      if (subtitle.length > 0) {
        Text(subtitle)
          .fontSize(12)
          .fontColor(ThemeColor.get(this.darkMode).textSecondary)
          .lineHeight(18)
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildTextInput(fieldKey: string, label: string, placeholder: string, value: string, isPassword: boolean) {
    Column() {
      Text(label)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeColor.get(this.darkMode).textSecondary)
        .width('100%')
        .margin({ bottom: 8 })

      TextInput({ text: value, placeholder: placeholder })
        .id(fieldKey + '-' + this.formRevision.toString())
        .height(48)
        .type(isPassword ? InputType.Password : InputType.Normal)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .placeholderColor(this.darkMode ? '#64748B' : '#94A3B8')
        .backgroundColor(ThemeColor.get(this.darkMode).background)
        .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
        .padding({ left: 16, right: 16 })
        .borderRadius(12)
        .onChange((text: string) => {
          if (fieldKey === 'server-url') {
            this.serverUrl = text;
          } else if (fieldKey === 'remote-path') {
            this.remotePath = text;
          } else if (fieldKey === 'username') {
            this.username = text;
          } else {
            this.password = text;
          }
        })
    }
    .width('100%')
    .margin({ bottom: 18 })
  }

  @Builder
  private buildConfigCard() {
    Column() {
      this.sectionTitle('WebDAV 配置', '用于连接坚果云或其它支持 WebDAV 的服务。')
      Column()
        .width('100%')
        .height(18)

      this.buildTextInput('server-url', 'WebDAV 服务器地址', 'https://dav.jianguoyun.com/dav/', this.serverUrl, false)
      this.buildTextInput('username', '用户名 / 邮箱', 'example@email.com', this.username, false)
      this.buildTextInput('password', '应用授权密码', '请输入应用授权密码', this.password, true)
      this.buildTextInput('remote-path', '云端同步路径', '/wordcard', this.remotePath, false)

      Row() {
        Button('测试连接')
          .layoutWeight(1)
          .height(48)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .role(ButtonRole.NORMAL)
          .fontColor(ThemeColor.get(this.darkMode).textPrimary)
          .onClick(() => {
            this.testConnection();
          })

        Button('保存配置')
          .layoutWeight(1)
          .height(48)
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .controlSize(ControlSize.NORMAL)
          .role(ButtonRole.NORMAL)
          .margin({ left: 14 })
          .onClick(() => {
            this.saveConfig();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(20)
    .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
    .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
    .borderRadius(18)
    .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
    .margin({ top: 12 })
  }

  @Builder
  private buildDataActionsCard() {
    Column() {
      this.sectionTitle('数据交互', '手动上传本机数据，或从云端拉取备份数据。')
      Row() {
        Button('拉取数据')
          .layoutWeight(1)
          .height(54)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .role(ButtonRole.NORMAL)
          .fontColor(ThemeColor.get(this.darkMode).textPrimary)
          .onClick(() => {
            this.downloadData();
          })

        Button('上传数据')
          .layoutWeight(1)
          .height(54)
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .controlSize(ControlSize.NORMAL)
          .role(ButtonRole.NORMAL)
          .margin({ left: 14 })
          .onClick(() => {
            this.uploadData();
          })
      }
      .width('100%')
      .margin({ top: 16 })
    }
    .width('100%')
    .padding(20)
    .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
    .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
    .borderRadius(18)
    .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
    .margin({ top: 16 })
  }

  @Builder
  private buildSyncModeCard() {
    Column() {
      this.sectionTitle('同步管理', this.syncModeDescription())

      Row() {
        Column() {
          Text('同步方式')
            .fontSize(14)
            .fontColor(ThemeColor.get(this.darkMode).textPrimary)
          Text(this.syncModeLabel())
            .fontSize(12)
            .fontColor(ThemeColor.get(this.darkMode).textSecondary)
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Select(this.getSyncModeOptions())
          .selected(this.syncMode)
          .value(this.syncModeLabel())
          .height(36)
          .padding({ left: 12, right: 8 })
          .backgroundColor(ThemeColor.get(this.darkMode).primaryLight)
          .borderRadius(12)
          .font({
            size: 13,
            weight: FontWeight.Medium
          })
          .fontColor(ThemeColor.get(this.darkMode).primary)
          .selectedOptionFont({
            size: 16,
            weight: FontWeight.Medium
          })
          .optionFont({
            size: 16,
            weight: FontWeight.Normal
          })
          .onSelect((index: number) => {
            this.updateSyncMode(index);
          })
      }
      .width('100%')
      .margin({ top: 18 })

      Divider()
        .color(ThemeColor.get(this.darkMode).border)
        .margin({ top: 16, bottom: 16 })

      Row() {
        Column() {
          Text('同步时间')
            .fontSize(14)
            .fontColor(ThemeColor.get(this.darkMode).textPrimary)
            .width('100%')

          Text('已选择：' + this.syncTimeSummary())
            .fontSize(12)
            .fontColor(ThemeColor.get(this.darkMode).textSecondary)
            .lineHeight(18)
            .width('100%')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ right: 12 })

        this.optionButton('选项', () => {
          this.openSyncTimeOptions();
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .padding(20)
    .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
    .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
    .borderRadius(18)
    .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
    .margin({ top: 16 })
  }

  @Builder
  private buildHistoryCard() {
    Column() {
      Row() {
        Text(this.historyRevision.toString())
          .width(0)
          .height(0)
          .opacity(0)

        Column() {
          Text('同步记录')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeColor.get(this.darkMode).textPrimary)
            .width('100%')

          Text('查看最近进行过同步的时间。')
            .fontSize(12)
            .fontColor(ThemeColor.get(this.darkMode).textSecondary)
            .lineHeight(18)
            .width('100%')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ right: 12 })

        Select(this.getHistoryLimitOptions())
          .selected(this.historyLimitSelectedIndex())
          .value(this.historyLimitText)
          .height(36)
          .padding({ left: 12, right: 8 })
          .backgroundColor(ThemeColor.get(this.darkMode).primaryLight)
          .borderRadius(12)
          .font({
            size: 13,
            weight: FontWeight.Medium
          })
          .fontColor(ThemeColor.get(this.darkMode).primary)
          .selectedOptionFont({
            size: 16,
            weight: FontWeight.Medium
          })
          .optionFont({
            size: 16,
            weight: FontWeight.Normal
          })
          .onSelect((index: number) => {
            this.updateHistoryLimit(this.historyLimitOptions[index]);
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      if (this.syncHistory.length === 0) {
        Text('暂无同步记录')
          .fontSize(13)
          .fontColor(ThemeColor.get(this.darkMode).textSecondary)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 18, bottom: 4 })
      } else {
        ForEach(this.visibleSyncHistory, (item: string) => {
          Text(item)
            .fontSize(13)
            .fontColor(ThemeColor.get(this.darkMode).textPrimary)
            .lineHeight(20)
            .width('100%')
            .padding({ left: 14, right: 14, top: 12, bottom: 12 })
            .margin({ top: 10 })
            .backgroundColor(this.darkMode ? '#1E293B' : '#F8FAFC')
            .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
            .borderRadius(12)
        }, (item: string) => item)
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
    .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
    .borderRadius(18)
    .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
    .margin({ top: 16 })
    .id('webdav-history-card-' + this.historyRevision.toString())
  }

  build() {
    HdsNavDestination() {
      if (this.isLoading) {
        Text('正在加载同步配置...')
          .fontSize(16)
          .fontColor(ThemeColor.get(this.darkMode).textSecondary)
          .margin({ top: 16 })
      } else {
        List({ scroller: this.pageScroller }) {
          ListItem() {
            this.buildConfigCard()
          }
          .width('100%')
          .reuseId('webdav-config')

          ListItem() {
            this.buildDataActionsCard()
          }
          .width('100%')
          .reuseId('webdav-actions')

          ListItem() {
            this.buildSyncModeCard()
          }
          .width('100%')
          .reuseId('webdav-sync-mode')

          ListItem() {
            this.buildHistoryCard()
          }
          .width('100%')

          ListItem() {
            Column().width('100%').height(32)
          }
          .width('100%')
          .reuseId('webdav-bottom-spacer')
        }
        .width('100%')
        .height('100%')
        .padding({ left: 20, right: 20, top: 0 })
        .contentStartOffset(-SUB_PAGE_CONTENT_OVERLAP)
        .contentEndOffset(SUB_PAGE_CONTENT_OVERLAP)
        .cachedCount(5)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .enableScrollInteraction(true)
        .friction(0.75)
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .titleBar(createHdsSubPageTitleBarOptions('同步管理', this.darkMode, this.materialEffectMode))
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .onBackPressed(() => {
      router.back();
      return true;
    })
    .bindToScrollable([this.pageScroller])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    .backgroundColor(ThemeColor.get(this.darkMode).background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}
