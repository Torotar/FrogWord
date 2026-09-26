import { common } from '@kit.AbilityKit';
import router from '@ohos.router';
import {
  HdsNavigationMenuItemOptions,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  TextStyleMode
} from '@kit.UIDesignKit';
import { SUB_PAGE_CONTENT_OVERLAP } from '../components/HdsSubPageLayout';
import { createHdsSubPageTitleBarOptions } from '../components/HdsSubPageTitleBarOptions';
import { ImportResult } from '../model/ImportResult';
import { OnlineWordBook } from '../model/OnlineWordBook';
import { WordBook } from '../model/WordBook';
import { DatabaseService } from '../services/DatabaseService';
import { ImportService } from '../services/ImportService';
import { OnlineWordBookService } from '../services/OnlineWordBookService';
import { PreferencesService } from '../services/PreferencesService';
import { ThemeService } from '../services/ThemeService';
import { WordBookService } from '../services/WordBookService';
import { DateUtil } from '../utils/DateUtil';
import { Constants } from '../utils/Constants';
import { ThemeColor } from '../utils/ThemeColor';
import { HomeModuleTransition, HomeModuleTransitionRoute } from '../utils/HomeModuleTransition';
import { SearchTransitionRect } from '../utils/HomeSearchTransition';

interface WordBookManageParams {
  homeModuleTransition?: HomeModuleTransitionRoute;
}

/** 取消选择词书弹窗 */
@CustomDialog
@Component
struct DeselectBookDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: this });
  bookName: string = '';
  darkMode: boolean = false;
  onConfirm: () => void = () => {};

  build() {
    Column() {
      Text('取消选择词书')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .margin({ top: 8 })

      Text('取消选择后学习记录将保留，确定取消选择')
        .fontSize(14)
        .fontColor(ThemeColor.get(this.darkMode).textSecondary)
        .margin({ top: 10 })

      Text('"' + this.bookName + '"')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .margin({ top: 6 })

      Row() {
        Button('返回')
          .width('44%')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .role(ButtonRole.NORMAL)
          .fontColor(ThemeColor.get(this.darkMode).primary)
          .backgroundColor(ThemeColor.get(this.darkMode).primaryLight)
          .onClick(() => {
            this.controller.close();
          })

        Button('确认取消')
          .width('44%')
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .controlSize(ControlSize.NORMAL)
          .role(ButtonRole.NORMAL)
          .fontColor(this.darkMode ? ThemeColor.get(this.darkMode).background : Color.White)
          .backgroundColor(ThemeColor.get(this.darkMode).primary)
          .onClick(() => {
            this.onConfirm();
            this.controller.close();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 20 })
    }
    .padding({ left: 24, right: 24, top: 16, bottom: 20 })
    .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
    .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
    .borderRadius(24)
  }
}

/** 选择词书弹窗 */
@CustomDialog
@Component
struct SelectBookDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: this });
  bookName: string = '';
  titleText: string = '选择学习词书';
  descriptionText: string = '';
  confirmText: string = '确认选择';
  darkMode: boolean = false;
  @State selectedOrderMode: number = 0;
  onConfirm: (mode: number) => Promise<void> = async () => {};

  build() {
    Column() {
      Text(this.titleText)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .margin({ top: 8 })

      Text(this.descriptionText.length > 0 ? this.descriptionText : '将"' + this.bookName + '"设为当前学习词书')
        .fontSize(14)
        .fontColor(ThemeColor.get(this.darkMode).textSecondary)
        .margin({ top: 10 })

      Text('请选择学习顺序：')
        .fontSize(14)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .margin({ top: 18 })
        .alignSelf(ItemAlign.Start)

      Row() {
        Row() {
          Radio({ value: '0', group: 'orderMode' })
            .checked(this.selectedOrderMode === 0)
            .onChange((isChecked: boolean) => {
              if (isChecked) {
                this.selectedOrderMode = 0;
              }
            })
            .width(22)
            .height(22)
            .radioStyle({ checkedBackgroundColor: ThemeColor.get(this.darkMode).primary })
          Text('字母排序')
            .fontSize(15)
            .fontColor(ThemeColor.get(this.darkMode).textPrimary)
            .margin({ left: 8 })
        }
        .onClick(() => {
          this.selectedOrderMode = 0;
        })
        .padding({ left: 8, right: 8, top: 6, bottom: 6 })

        Row() {
          Radio({ value: '1', group: 'orderMode' })
            .checked(this.selectedOrderMode === 1)
            .onChange((isChecked: boolean) => {
              if (isChecked) {
                this.selectedOrderMode = 1;
              }
            })
            .width(22)
            .height(22)
            .radioStyle({ checkedBackgroundColor: ThemeColor.get(this.darkMode).primary })
          Text('乱序学习')
            .fontSize(15)
            .fontColor(ThemeColor.get(this.darkMode).textPrimary)
            .margin({ left: 8 })
        }
        .onClick(() => {
          this.selectedOrderMode = 1;
        })
        .padding({ left: 8, right: 8, top: 6, bottom: 6 })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceAround)
      .margin({ top: 12 })

      Row() {
        Button('取消')
          .width('44%')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .role(ButtonRole.NORMAL)
          .fontColor(ThemeColor.get(this.darkMode).primary)
          .backgroundColor(ThemeColor.get(this.darkMode).primaryLight)
          .onClick(() => {
            this.controller.close();
          })

        Button(this.confirmText)
          .width('44%')
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .controlSize(ControlSize.NORMAL)
          .role(ButtonRole.NORMAL)
          .fontColor(this.darkMode ? ThemeColor.get(this.darkMode).background : Color.White)
          .backgroundColor(ThemeColor.get(this.darkMode).primary)
          .onClick(async () => {
            await this.onConfirm(this.selectedOrderMode);
            this.controller.close();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 10 })
    }
    .padding({ left: 24, right: 24, top: 16, bottom: 20 })
    .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
    .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
    .borderRadius(24)
  }
}

@Entry
@Component
struct WordBookManagePage {
  @State private isLoading: boolean = true;
  @State private isImporting: boolean = false;
  @State private isLoadingOnline: boolean = false;
  @State private downloadingBookId: string = '';
  @State private onlineKeyword: string = '';
  @State private selectedCategory: string = '全部';
  @State private onlineBooks: OnlineWordBook[] = [];
  @State private visibleOnlineBooks: OnlineWordBook[] = [];
  @State private onlineMessage: string = '从 kajweb/dict 在线选择词书下载使用';
  @State private result: ImportResult = {
    success: false,
    bookName: '',
    successCount: 0,
    skipCount: 0,
    failCount: 0,
    message: ''
  };
  @StorageLink('resolvedDarkMode') darkMode: boolean = false;
  @StorageLink('materialEffectMode') materialEffectMode: number = Constants.DEFAULT_MATERIAL_EFFECT_MODE;
  @State private books: WordBook[] = [];
  @State private message: string = '';
  @State private selectedBookId: number = 0;
  @State private orderMode: number = 0;
  @State private importedBookIds: Set<string> = new Set();
  @State private categoryExpanded: boolean = false;
  @State private isBatchEditing: boolean = false;
  @State private selectedDeleteBookIds: Set<number> = new Set();
  @State private homeModuleContentStage: number = 7;
  private categories: string[] = ['全部', '四级', '六级', '考研', '专四', '专八', '小学', '初中', '高中', '雅思', '托福', 'GRE'];
  private readonly STATUS_BAR_HEIGHT: number = 56;
  private readonly TITLE_BAR_HEIGHT: number = 40;
  private readonly SCROLL_BAR_SAFE_WIDTH: number = 8;
  private readonly VISIBLE_COUNT: number = 3;
  private pendingSelectBook: WordBook | null = null;
  private dialogController: CustomDialogController | null = null;
  private pageScroller: Scroller = new Scroller();
  private readonly HOME_MODULE_FIRST_BOOK_ID: string = 'word-book-manage-first-book-transition';
  private homeModuleTransition: HomeModuleTransitionRoute | undefined = undefined;
  private homeModuleTransitionPrepared: boolean = false;
  private homeModuleFallbackTimer: number = -1;
  private homeModuleContentTimers: number[] = [];
  private readonly HOME_MODULE_CONTENT_ENTRANCE_DELAY: number = 80;
  private readonly HOME_MODULE_CONTENT_ITEM_DELAY: number = 40;
  private readonly HOME_MODULE_MAX_ENTRY_ITEMS: number = 8;

  aboutToAppear(): void {
    this.readHomeModuleTransition();
    this.applyImmersiveBars();
    this.initPage();
  }

  onPageShow(): void {
    this.applyImmersiveBars();
  }

  aboutToDisappear(): void {
    this.clearHomeModuleContentTimers();
    if (this.homeModuleFallbackTimer >= 0) {
      clearTimeout(this.homeModuleFallbackTimer);
      this.homeModuleFallbackTimer = -1;
    }
  }

  private async applyImmersiveBars(): Promise<void> {
    const context = getContext(this) as common.Context;
    await ThemeService.applySystemBars(context, this.darkMode);
  }

  private async initPage(): Promise<void> {
    this.loadBooks();
    this.loadOnlineBooks();
  }

  private readHomeModuleTransition(): void {
    const params: WordBookManageParams = router.getParams() as WordBookManageParams;
    this.homeModuleTransition = params ? params.homeModuleTransition : undefined;
    if (HomeModuleTransition.isValidRoute(this.homeModuleTransition)) {
      this.homeModuleContentStage = 0;
      this.homeModuleFallbackTimer = setTimeout((): void => {
        this.homeModuleFallbackTimer = -1;
        if (!this.homeModuleTransitionPrepared) {
          this.homeModuleTransitionPrepared = true;
          this.finishHomeModuleContentEntrance();
        }
      }, 360);
    }
  }

  private readHomeModuleTargetRect(): SearchTransitionRect | undefined {
    return this.readHomeModuleRect(this.HOME_MODULE_FIRST_BOOK_ID);
  }

  private readHomeModuleRect(componentId: string): SearchTransitionRect | undefined {
    try {
      const componentInfo = this.getUIContext().getComponentUtils().getRectangleById(componentId);
      const rect: SearchTransitionRect = {
        x: componentInfo.windowOffset.x,
        y: componentInfo.windowOffset.y,
        width: componentInfo.size.width,
        height: componentInfo.size.height
      };
      return HomeModuleTransition.isValid(rect) ? rect : undefined;
    } catch (error) {
      console.warn('WordBookManagePage read home module transition rect failed: ' + JSON.stringify(error));
      return undefined;
    }
  }

  private beginHomeModuleEnterTransition(): void {
    if (!HomeModuleTransition.isValidRoute(this.homeModuleTransition) || this.homeModuleTransitionPrepared) {
      return;
    }
    this.homeModuleTransitionPrepared = true;
    if (this.homeModuleFallbackTimer >= 0) {
      clearTimeout(this.homeModuleFallbackTimer);
      this.homeModuleFallbackTimer = -1;
    }
    this.scheduleHomeModuleContentEntrance();
  }

  private clearHomeModuleContentTimers(): void {
    for (let index: number = 0; index < this.homeModuleContentTimers.length; index++) {
      clearTimeout(this.homeModuleContentTimers[index]);
    }
    this.homeModuleContentTimers = [];
  }

  private scheduleHomeModuleContentEntrance(): void {
    this.clearHomeModuleContentTimers();
    for (let stage: number = 1; stage <= this.HOME_MODULE_MAX_ENTRY_ITEMS + 2; stage++) {
      const delay: number = this.HOME_MODULE_CONTENT_ENTRANCE_DELAY +
        (stage - 1) * this.HOME_MODULE_CONTENT_ITEM_DELAY;
      const timer: number = setTimeout((): void => {
        animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
          this.homeModuleContentStage = stage;
        });
      }, delay);
      this.homeModuleContentTimers.push(timer);
    }
  }

  private finishHomeModuleContentEntrance(): void {
    this.clearHomeModuleContentTimers();
    this.homeModuleContentStage = this.HOME_MODULE_MAX_ENTRY_ITEMS + 2;
  }

  private getHomeModuleContentOpacity(stage: number): number {
    if (!HomeModuleTransition.isValidRoute(this.homeModuleTransition) || stage > this.HOME_MODULE_MAX_ENTRY_ITEMS + 2) {
      return 1;
    }
    return this.homeModuleContentStage >= stage ? 1 : 0;
  }

  private getHomeModuleContentOffset(stage: number): number {
    return this.getHomeModuleContentOpacity(stage) > 0 ? 0 : 16;
  }

  private getBookEntranceStage(bookId: number): number {
    for (let index: number = 0; index < this.books.length; index++) {
      if (this.books[index].id === bookId) {
        return index + 1;
      }
    }
    return this.HOME_MODULE_MAX_ENTRY_ITEMS + 2;
  }

  private getBookSupportEntranceStage(): number {
    return Math.min(this.HOME_MODULE_MAX_ENTRY_ITEMS + 1, this.books.length + 1);
  }

  private returnToPreviousPage(): void {
    if (this.homeModuleTransition !== undefined) {
      const source: SearchTransitionRect | undefined = this.readHomeModuleTargetRect();
      if (source !== undefined) {
        HomeModuleTransition.setReturnSource(this.homeModuleTransition.id, source);
      }
    }
    router.back();
  }

  private async loadBooks(): Promise<void> {
    this.isLoading = true;
    try {
      const context = getContext(this) as common.Context;
      await DatabaseService.init(context);
      await PreferencesService.init(context);

      this.books = await WordBookService.getAllWordBooks();
      this.selectedBookId = await PreferencesService.getSelectedBookId();
      this.orderMode = await PreferencesService.getStudyOrderMode();
      this.updateImportedBookIds();
      this.message = '';
    } catch (error) {
      console.error('WordBookManagePage loadBooks failed: ' + JSON.stringify(error));
      this.message = '词书加载失败';
    } finally {
      this.isLoading = false;
    }
  }

  private updateImportedBookIds(): void {
    const imported: Set<string> = new Set();
    for (let i: number = 0; i < this.books.length; i++) {
      if (this.books[i].id > 1) {
        imported.add(this.books[i].name);
      }
    }
    this.importedBookIds = imported;
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({
      message: message,
      duration: 3000
    });
  }

  private async importFile(): Promise<void> {
    if (this.isImporting) {
      return;
    }
    this.isImporting = true;
    try {
      const context = getContext(this) as common.Context;
      await DatabaseService.init(context);
      const importResult: ImportResult = await ImportService.importFromPicker(context);
      this.result = importResult;
      if (importResult.success) {
        AlertDialog.show({
          title: '导入成功',
          message: '词书「' + importResult.bookName + '」\n成功导入 ' + importResult.successCount + ' 个单词' +
            (importResult.skipCount > 0 ? '\n跳过 ' + importResult.skipCount + ' 个重复单词' : ''),
          confirm: { value: '确定', action: () => {} }
        });
        await this.loadBooks();
      } else {
        AlertDialog.show({
          title: '导入失败',
          message: importResult.message,
          confirm: { value: '确定', action: () => {} }
        });
      }
    } catch (error) {
      console.error('importFile failed: ' + JSON.stringify(error));
      AlertDialog.show({
        title: '导入失败',
        message: '导入失败：' + JSON.stringify(error),
        confirm: { value: '确定', action: () => {} }
      });
    } finally {
      this.isImporting = false;
    }
  }

  private async loadOnlineBooks(forceRefresh: boolean = false): Promise<void> {
    this.isLoadingOnline = true;
    try {
      this.onlineBooks = await OnlineWordBookService.fetchOnlineBooks(forceRefresh);
      this.applyOnlineFilter();
      this.onlineMessage = this.onlineBooks.length > 0
        ? '已加载 ' + this.onlineBooks.length.toString() + ' 本在线词书'
        : '在线词书加载失败，请检查网络';
    } catch (error) {
      console.error('loadOnlineBooks failed: ' + JSON.stringify(error));
      this.onlineMessage = '在线词书加载失败：' + JSON.stringify(error);
    } finally {
      this.isLoadingOnline = false;
    }
  }

  private applyOnlineFilter(): void {
    const keyword: string = this.onlineKeyword.trim().toLowerCase();
    const books: OnlineWordBook[] = [];
    for (let index: number = 0; index < this.onlineBooks.length; index++) {
      const book: OnlineWordBook = this.onlineBooks[index];
      const text: string = book.title + ' ' + book.description + ' ' + book.tags + ' ' + book.id;
      const lowerText: string = text.toLowerCase();
      const matchedKeyword: boolean = keyword.length === 0 || lowerText.indexOf(keyword) >= 0;
      const matchedCategory: boolean = this.selectedCategory === '全部' || text.indexOf(this.selectedCategory) >= 0;
      if (matchedKeyword && matchedCategory) {
        books.push(book);
      }
    }
    this.visibleOnlineBooks = books;
  }

  private getButtonLabel(book: OnlineWordBook): string {
    if (this.downloadingBookId === book.id) {
      return '下载中...';
    }
    if (this.importedBookIds.has(book.title)) {
      return '已导入';
    }
    return '下载使用';
  }

  private async importOnlineBook(book: OnlineWordBook): Promise<void> {
    if (this.downloadingBookId.length > 0) {
      return;
    }
    if (this.importedBookIds.has(book.title)) {
      this.showToast('"' + book.title + '" 已导入，无需重复下载');
      return;
    }
    this.downloadingBookId = book.id;
    this.result = {
      success: false,
      bookName: book.title,
      successCount: 0,
      skipCount: 0,
      failCount: 0,
      message: ''
    };
    try {
      const context = getContext(this) as common.Context;
      await DatabaseService.init(context);
      const importResult: ImportResult = await OnlineWordBookService.importOnlineBook(context, book);
      this.result = importResult;
      if (importResult.success) {
        const imported: Set<string> = new Set(this.importedBookIds);
        imported.add(book.title);
        this.importedBookIds = imported;
        this.showToast('"' + book.title + '" 导入成功');
        await this.loadBooks();
      } else {
        this.showToast('"' + book.title + '" 导入失败：' + importResult.message);
      }
    } catch (error) {
      console.error('importOnlineBook failed: ' + JSON.stringify(error));
      this.showToast('"' + book.title + '" 导入失败');
      this.result = {
        success: false,
        bookName: book.title,
        successCount: 0,
        skipCount: 0,
        failCount: 0,
        message: '在线词书导入失败：' + JSON.stringify(error)
      };
    } finally {
      this.downloadingBookId = '';
    }
  }

  private openBook(bookId: number): void {
    router.pushUrl({
      url: 'pages/WordBookDetailPage',
      params: {
        bookId: bookId
      }
    });
  }

  private getOrderModeText(): string {
    return this.orderMode === 1 ? '乱序学习' : '字母排序';
  }

  private showSelectDialog(book: WordBook): void {
    if (this.selectedBookId === book.id) {
      // Show deselect confirmation dialog (same style)
      if (this.dialogController) {
        this.dialogController.close();
        this.dialogController = null;
      }
      this.dialogController = new CustomDialogController({
        builder: DeselectBookDialog({
          bookName: book.name,
          darkMode: this.darkMode,
          onConfirm: () => {
            this.deselectBook();
          }
        }),
        alignment: DialogAlignment.Center,
        customStyle: false,
        autoCancel: true
      });
      this.dialogController.open();
      return;
    }
    this.pendingSelectBook = book;
    if (this.dialogController) {
      this.dialogController.close();
      this.dialogController = null;
    }
    this.dialogController = new CustomDialogController({
      builder: SelectBookDialog({
        bookName: book.name,
        darkMode: this.darkMode,
        selectedOrderMode: this.orderMode,
        onConfirm: async (mode: number) => {
          await this.confirmSelectBook(mode);
        }
      }),
      alignment: DialogAlignment.Center,
      customStyle: false,
      autoCancel: true
    });
    this.dialogController.open();
  }

  private showOrderModeDialog(book: WordBook): void {
    if (this.dialogController) {
      this.dialogController.close();
      this.dialogController = null;
    }
    this.dialogController = new CustomDialogController({
      builder: SelectBookDialog({
        bookName: book.name,
        titleText: '修改学习顺序',
        descriptionText: '当前词书："' + book.name + '"',
        confirmText: '保存修改',
        darkMode: this.darkMode,
        selectedOrderMode: this.orderMode,
        onConfirm: async (mode: number) => {
          await this.updateOrderMode(mode);
        }
      }),
      alignment: DialogAlignment.Center,
      customStyle: false,
      autoCancel: true
    });
    this.dialogController.open();
  }

  private async deselectBook(): Promise<void> {
    this.selectedBookId = 0;
    await PreferencesService.setSelectedBookId(0);
  }

  private async updateOrderMode(mode: number): Promise<void> {
    this.orderMode = mode;
    await PreferencesService.setStudyOrderMode(mode);
  }

  private async confirmSelectBook(mode: number): Promise<void> {
    if (!this.pendingSelectBook) {
      return;
    }
    this.selectedBookId = this.pendingSelectBook.id;
    await this.updateOrderMode(mode);
    await PreferencesService.setSelectedBookId(this.pendingSelectBook.id);
    console.info('confirmSelectBook: saved selectedBookId=' + this.pendingSelectBook.id.toString());
    this.pendingSelectBook = null;
  }

  private confirmDeleteBook(book: WordBook): void {
    AlertDialog.show({
      title: '删除词书',
      message: '确定删除"' + book.name + '"吗？该词书下的单词和学习记录也会一起删除。',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '确认删除',
        fontColor: ThemeColor.get(this.darkMode).danger,
        action: () => {
          this.deleteBook(book.id);
        }
      }
    });
  }

  private async deleteBook(bookId: number): Promise<void> {
    try {
      await WordBookService.deleteWordBook(bookId);
      if (this.selectedBookId === bookId) {
        this.selectedBookId = 0;
        await PreferencesService.setSelectedBookId(0);
      }
      this.message = '词书已删除';
      this.showToast('词书已删除');
      await this.loadBooks();
    } catch (error) {
      console.error('deleteBook failed: ' + JSON.stringify(error));
      this.message = '删除失败';
      this.showToast('删除失败');
    }
  }

  private toggleBatchEditing(): void {
    this.isBatchEditing = !this.isBatchEditing;
    if (!this.isBatchEditing) {
      this.selectedDeleteBookIds = new Set();
    }
  }

  private isBookSelectedForDelete(bookId: number): boolean {
    return this.selectedDeleteBookIds.has(bookId);
  }

  private toggleBookDeleteSelection(bookId: number): void {
    const selectedIds: Set<number> = new Set(this.selectedDeleteBookIds);
    if (selectedIds.has(bookId)) {
      selectedIds.delete(bookId);
    } else {
      selectedIds.add(bookId);
    }
    this.selectedDeleteBookIds = selectedIds;
  }

  private confirmBatchDeleteBooks(): void {
    const selectedCount: number = this.selectedDeleteBookIds.size;
    if (selectedCount === 0) {
      this.showToast('请先选择要删除的词书');
      return;
    }
    AlertDialog.show({
      title: '批量删除词书',
      message: '确定删除选中的 ' + selectedCount.toString() + ' 本词书吗？这些词书下的单词和学习记录也会一起删除。',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '确认删除',
        fontColor: ThemeColor.get(this.darkMode).danger,
        action: () => {
          this.deleteSelectedBooks();
        }
      }
    });
  }

  private async deleteSelectedBooks(): Promise<void> {
    const selectedIds: number[] = Array.from(this.selectedDeleteBookIds);
    if (selectedIds.length === 0) {
      return;
    }
    try {
      for (let i: number = 0; i < selectedIds.length; i++) {
        await WordBookService.deleteWordBook(selectedIds[i]);
      }
      if (this.selectedDeleteBookIds.has(this.selectedBookId)) {
        this.selectedBookId = 0;
        await PreferencesService.setSelectedBookId(0);
      }
      const deletedCount: number = selectedIds.length;
      this.selectedDeleteBookIds = new Set();
      this.isBatchEditing = false;
      this.message = '已删除 ' + deletedCount.toString() + ' 本词书';
      this.showToast('已删除 ' + deletedCount.toString() + ' 本词书');
      await this.loadBooks();
    } catch (error) {
      console.error('deleteSelectedBooks failed: ' + JSON.stringify(error));
      this.message = '批量删除失败';
      this.showToast('批量删除失败');
    }
  }

  private getTitleMenuItems(): Array<HdsNavigationMenuItemOptions> {
    if (this.isBatchEditing) {
      const deleteLabel: string = '删除' +
        (this.selectedDeleteBookIds.size > 0 ? '(' + this.selectedDeleteBookIds.size.toString() + ')' : '');
      return [
        {
          content: {
            label: deleteLabel,
            isEnabled: this.selectedDeleteBookIds.size > 0,
            type: TextStyleMode.NORMAL,
            action: () => {
              this.confirmBatchDeleteBooks();
            }
          }
        },
        {
          content: {
            label: '完成',
            type: TextStyleMode.NORMAL,
            action: () => {
              this.toggleBatchEditing();
            }
          }
        }
      ];
    }
    return [
      {
        content: {
          label: '编辑',
          type: TextStyleMode.NORMAL,
          action: () => {
            this.toggleBatchEditing();
          }
        }
      }
    ];
  }

  @Builder
  private deleteSwipeAction(book: WordBook) {
    if (!this.isBatchEditing) {
      Column() {
        Button() {
          Text('删除')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
        }
        .width(80)
        .height('100%')
        .buttonStyle(ButtonStyleMode.EMPHASIZED)
        .controlSize(ControlSize.NORMAL)
        .role(ButtonRole.ERROR)
        .onClick(() => {
          this.confirmDeleteBook(book);
        })
      }
      .width(80)
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
  }

  pageTransition() {
    if (HomeModuleTransition.isValidRoute(this.homeModuleTransition)) {
      PageTransitionEnter({ duration: 0, type: RouteType.Push });
      PageTransitionExit({ duration: 240, curve: Curve.EaseIn, type: RouteType.Pop }).opacity(0);
    } else {
      PageTransitionEnter({ duration: 180, curve: Curve.EaseOut }).opacity(0)
      PageTransitionExit({ duration: 140, curve: Curve.EaseIn }).opacity(0)
    }
  }

  @Builder
  private buildLocalBookCard(book: WordBook) {
    Row() {
      if (this.isBatchEditing) {
        Stack() {
          if (this.isBookSelectedForDelete(book.id)) {
            Text('✓')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
        }
        .width(24)
        .height(24)
        .backgroundColor(this.isBookSelectedForDelete(book.id) ? ThemeColor.get(this.darkMode).danger :
          ThemeColor.get(this.darkMode).cardBackground)
        .border({
          width: 1.5,
          color: this.isBookSelectedForDelete(book.id) ? ThemeColor.get(this.darkMode).danger :
            ThemeColor.get(this.darkMode).border
        })
        .borderRadius(12)
        .margin({ right: 14 })
      }

      Column() {
        Row() {
          Text(book.name)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeColor.get(this.darkMode).textPrimary)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(book.totalCount.toString() + ' 词')
            .fontSize(13)
            .fontColor(ThemeColor.get(this.darkMode).primary)
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .backgroundColor(ThemeColor.get(this.darkMode).primaryLight)
            .borderRadius(12)
            .margin({ right: 6 })
        }
        .width('100%')

        Text(book.description.length > 0 ? book.description : '暂无描述')
          .fontSize(14)
          .fontColor(ThemeColor.get(this.darkMode).textSecondary)
          .width('100%')
          .lineHeight(20)
          .margin({ top: 8 })

        Row() {
          Text('创建时间：' + DateUtil.formatTimestamp(book.createdAt))
            .fontSize(12)
            .fontColor(ThemeColor.get(this.darkMode).textSecondary)
            .layoutWeight(1)

          if (this.selectedBookId === book.id) {
            Text('学习中')
              .fontSize(11)
              .fontColor(this.darkMode ? '#DBEAFE' : ThemeColor.get(this.darkMode).primary)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor(this.darkMode ? '#1E3A8A' : '#DBEAFE')
              .borderRadius(8)
          }
        }
        .width('100%')
        .height(24)
        .alignItems(VerticalAlign.Center)
        .margin({ top: 8 })

        if (this.selectedBookId === book.id) {
          Row() {
            Text('学习顺序：' + this.getOrderModeText())
              .fontSize(12)
              .fontColor(this.darkMode ? '#BFDBFE' : ThemeColor.get(this.darkMode).primary)
              .layoutWeight(1)

            Text('修改')
              .fontSize(12)
              .fontColor(Color.White)
              .fontWeight(FontWeight.Medium)
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .backgroundColor(ThemeColor.get(this.darkMode).primary)
              .borderRadius(10)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .padding({ left: 12, right: 10, top: 8, bottom: 8 })
          .backgroundColor(this.darkMode ? 'rgba(30, 58, 138, 0.46)' : '#DBEAFE')
          .borderRadius(14)
          .margin({ top: 8 })
          .onClick(() => {
            this.showOrderModeDialog(book);
          })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding(18)
    .backgroundColor(this.isBookSelectedForDelete(book.id) ? (this.darkMode ? '#3F1D22' : '#FEF2F2') :
      (this.selectedBookId === book.id ? (this.darkMode ? '#13294B' : '#EEF5FF') :
      ThemeColor.get(this.darkMode).cardBackground))
    .border({
      width: this.isBookSelectedForDelete(book.id) || this.selectedBookId === book.id ? 1.5 : 1,
      color: this.isBookSelectedForDelete(book.id) ? ThemeColor.get(this.darkMode).danger :
        (this.selectedBookId === book.id ? ThemeColor.get(this.darkMode).primary : ThemeColor.get(this.darkMode).border)
    })
    .borderRadius(18)
    .shadow(this.selectedBookId === book.id ? {
      radius: 10,
      color: 'rgba(15, 23, 42, 0.05)',
      offsetY: 4
    } : {
      radius: 10,
      color: 'rgba(15, 23, 42, 0.05)',
      offsetY: 4
    })
    .onClick(() => {
      if (this.isBatchEditing) {
        this.toggleBookDeleteSelection(book.id);
        return;
      }
      this.showSelectDialog(book);
    })
    .gesture(
      LongPressGesture()
        .onAction(() => {
          if (this.isBatchEditing) {
            return;
          }
          this.openBook(book.id);
        })
    )
  }

  @Builder
  private buildBookListFooter() {
    Text('点击词书可选择为当前学习词书，左滑可删除')
      .fontSize(12)
      .fontColor(ThemeColor.get(this.darkMode).textSecondary)
      .width('100%')
      .textAlign(TextAlign.Center)
      .margin({ top: 0, bottom: 16 })

    if (this.message.length > 0) {
      Text(this.message)
        .fontSize(13)
        .fontColor(ThemeColor.get(this.darkMode).success)
        .backgroundColor(ThemeColor.get(this.darkMode).primaryLight)
        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
        .borderRadius(12)
        .margin({ top: 10 })
        .textAlign(TextAlign.Center)
    }
  }

  @Builder
  private buildBookListState() {
    if (this.isLoading) {
      Column() {
        Row() {
          Column() {
            Row()
              .width(116)
              .height(20)
              .backgroundColor(ThemeColor.get(this.darkMode).primaryLight)
              .borderRadius(10)

            Row()
              .width('68%')
              .height(18)
              .backgroundColor(ThemeColor.get(this.darkMode).border)
              .borderRadius(9)
              .margin({ top: 16 })

            Row()
              .width('52%')
              .height(14)
              .backgroundColor(ThemeColor.get(this.darkMode).border)
              .borderRadius(7)
              .margin({ top: 12 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
      }
      .width('100%')
      .padding(18)
      .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
      .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
      .borderRadius(20)
      .shadow({
        radius: 10,
        color: 'rgba(15, 23, 42, 0.05)',
        offsetY: 4
      })
      .margin({ top: 16 })
    } else if (this.books.length === 0) {
      Column() {
        Text('暂无词书')
          .fontSize(16)
          .fontColor(ThemeColor.get(this.darkMode).textSecondary)
      }
      .width('100%')
      .height(88)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .margin({ top: 16 })
    }

    this.buildBookListFooter()
  }

  @Builder
  private buildImportArea() {
    Column() {
      Column() {
        Row() {
          Column() {
            Text('添加本地词书')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(ThemeColor.get(this.darkMode).textPrimary)
            Text(this.isImporting ? '正在打开文件选择器...' : '支持 CSV / JSON，适合导入自己整理的词书')
              .fontSize(12)
              .fontColor(ThemeColor.get(this.darkMode).textSecondary)
              .margin({ top: 5 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ right: 18 })

          Text(this.isImporting ? '导入中' : '导入')
            .fontSize(13)
            .fontColor(this.isImporting ? ThemeColor.get(this.darkMode).textSecondary : Color.White)
            .fontWeight(FontWeight.Medium)
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .backgroundColor(this.isImporting ? ThemeColor.get(this.darkMode).border : ThemeColor.get(this.darkMode).primary)
            .borderRadius(14)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding(16)
      .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
      .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
      .borderRadius(16)
      .shadow({
        radius: 10,
        color: 'rgba(15, 23, 42, 0.05)',
        offsetY: 4
      })
      .onClick(() => {
        this.importFile();
      })

      Column() {
        Row() {
          Column() {
            Text('在线词库')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(ThemeColor.get(this.darkMode).textPrimary)
            Text(this.onlineMessage)
              .fontSize(13)
              .fontColor(ThemeColor.get(this.darkMode).textSecondary)
              .margin({ top: 6 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text(this.isLoadingOnline ? '加载中' : '刷新')
            .fontSize(14)
            .fontColor(ThemeColor.get(this.darkMode).primary)
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .backgroundColor(ThemeColor.get(this.darkMode).primaryLight)
            .borderRadius(14)
            .onClick(() => {
              if (!this.isLoadingOnline) {
                this.loadOnlineBooks(true);
              }
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Search({ value: this.onlineKeyword, placeholder: '搜索在线词书，例如 四级 / 考研 / 小学' })
          .width('100%')
          .height(48)
          .fontColor(ThemeColor.get(this.darkMode).textPrimary)
          .placeholderColor(ThemeColor.get(this.darkMode).textSecondary)
          .backgroundColor(ThemeColor.get(this.darkMode).background)
          .borderRadius(14)
          .padding({ left: 14, right: 14 })
          .margin({ top: 14 })
          .onChange((value: string) => {
            this.onlineKeyword = value;
            this.applyOnlineFilter();
          })

        Column() {
          Row() {
            ForEach(['全部', '四级', '六级', '考研'], (category: string) => {
              Text(category)
                .fontSize(13)
                .fontColor(this.selectedCategory === category ? Color.White : ThemeColor.get(this.darkMode).primary)
                .padding({ left: 10, right: 10, top: 7, bottom: 7 })
                .margin({ right: 10 })
                .backgroundColor(this.selectedCategory === category ? ThemeColor.get(this.darkMode).primary : ThemeColor.get(this.darkMode).primaryLight)
                .borderRadius(16)
                .onClick(() => {
                  this.selectedCategory = category;
                  this.categoryExpanded = false;
                  this.applyOnlineFilter();
                })
            }, (category: string) => category)

            Blank()
              .layoutWeight(1)

            Text(this.categoryExpanded ? '收起 ▲' : '更多 ▼')
              .fontSize(13)
              .fontColor(ThemeColor.get(this.darkMode).primary)
              .padding({ left: 10, right: 10, top: 7, bottom: 7 })
              .backgroundColor(ThemeColor.get(this.darkMode).primaryLight)
              .borderRadius(16)
              .onClick(() => {
                this.categoryExpanded = !this.categoryExpanded;
              })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          if (this.categoryExpanded) {
            Flex({ wrap: FlexWrap.NoWrap, justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
              ForEach(['专四', '专八', '小学', '初中', '高中'], (category: string) => {
                Row() {
                  Text(category)
                    .fontSize(13)
                    .fontColor(this.selectedCategory === category ? Color.White : ThemeColor.get(this.darkMode).primary)
                    .padding({ left: 10, right: 10, top: 7, bottom: 7 })
                    .backgroundColor(this.selectedCategory === category ? ThemeColor.get(this.darkMode).primary : ThemeColor.get(this.darkMode).primaryLight)
                    .borderRadius(16)
                    .onClick(() => {
                      this.selectedCategory = category;
                      this.applyOnlineFilter();
                    })
                }
                .width(54)
                .alignItems(VerticalAlign.Center)
              }, (category: string) => category)
            }
            .width('100%')
            .margin({ top: 10 })

            Flex({ wrap: FlexWrap.NoWrap, justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
              ForEach(['雅思', '托福', 'GRE'], (category: string) => {
                Row() {
                  Text(category)
                    .fontSize(13)
                    .fontColor(this.selectedCategory === category ? Color.White : ThemeColor.get(this.darkMode).primary)
                    .padding({ left: 10, right: 10, top: 7, bottom: 7 })
                    .backgroundColor(this.selectedCategory === category ? ThemeColor.get(this.darkMode).primary : ThemeColor.get(this.darkMode).primaryLight)
                    .borderRadius(16)
                    .onClick(() => {
                      this.selectedCategory = category;
                      this.applyOnlineFilter();
                    })
                }
                .width(54)
                .alignItems(VerticalAlign.Center)
              }, (category: string) => category)

              Blank()
                .width(54)
              Blank()
                .width(54)
            }
            .width('100%')
            .margin({ top: 10 })
          }
        }
        .width('100%')
        .margin({ top: 12 })

        if (this.isLoadingOnline) {
          Column() {
            Row()
              .width('74%')
              .height(18)
              .backgroundColor(ThemeColor.get(this.darkMode).background)
              .borderRadius(9)

            Row()
              .width('56%')
              .height(14)
              .backgroundColor(ThemeColor.get(this.darkMode).background)
              .borderRadius(7)
              .margin({ top: 10 })
          }
          .width('100%')
          .height(86)
          .padding(14)
          .margin({ top: 12 })
          .backgroundColor(ThemeColor.get(this.darkMode).background)
          .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
          .borderRadius(16)
          .alignItems(HorizontalAlign.Start)
        } else if (this.visibleOnlineBooks.length === 0) {
          Text(this.onlineBooks.length === 0 ? '暂无在线词库，请点击刷新重试' : '没有匹配的在线词书')
            .fontSize(14)
            .fontColor(ThemeColor.get(this.darkMode).textSecondary)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 22, bottom: 14 })
        }

        ForEach(this.visibleOnlineBooks, (book: OnlineWordBook) => {
          Column() {
            Row() {
              Column() {
                Text(book.title)
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(ThemeColor.get(this.darkMode).textPrimary)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Text(book.tags.length > 0 ? book.tags : book.id)
                  .fontSize(12)
                  .fontColor(ThemeColor.get(this.darkMode).textSecondary)
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Text(book.wordNum.toString() + ' 词')
                .fontSize(12)
                .fontColor(ThemeColor.get(this.darkMode).primary)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor(ThemeColor.get(this.darkMode).primaryLight)
                .borderRadius(10)
            }
            .width('100%')

            Text(book.description)
              .fontSize(12)
              .fontColor(ThemeColor.get(this.darkMode).textSecondary)
              .lineHeight(18)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .margin({ top: 8 })

            Button(this.getButtonLabel(book))
              .width('100%')
              .buttonStyle(this.importedBookIds.has(book.title) || this.downloadingBookId === book.id ?
                ButtonStyleMode.NORMAL : ButtonStyleMode.EMPHASIZED)
              .controlSize(ControlSize.NORMAL)
              .role(ButtonRole.NORMAL)
              .enabled(this.downloadingBookId.length === 0 || this.downloadingBookId !== book.id)
              .margin({ top: 12 })
              .onClick(() => {
                this.importOnlineBook(book);
              })
          }
          .width('100%')
          .padding(14)
          .margin({ top: 12 })
          .backgroundColor(ThemeColor.get(this.darkMode).background)
          .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
          .borderRadius(16)
        }, (book: OnlineWordBook) => book.id)
      }
      .width('100%')
      .padding(16)
      .margin({ top: 16 })
      .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
      .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
      .borderRadius(16)
      .shadow({
        radius: 10,
        color: 'rgba(15, 23, 42, 0.05)',
        offsetY: 4
      })
    }
    .width('100%')
    .margin({ top: 0 })
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      HdsNavDestination() {
        Stack() {
          List({ scroller: this.pageScroller, space: 14 }) {
            if (this.isLoading || this.books.length === 0) {
              ListItem() {
                this.buildBookListState()
              }
              .width('100%')
              .reuseId('word-book-manage-books-state')
            } else {
              ForEach(this.books, (book: WordBook) => {
                if (book.id === this.books[0].id) {
                  ListItem() {
                    this.buildLocalBookCard(book)
                  }
                  .id(this.HOME_MODULE_FIRST_BOOK_ID)
                  .opacity(this.getHomeModuleContentOpacity(1))
                  .translate({ y: this.getHomeModuleContentOffset(1) })
                  .onAreaChange((): void => {
                    this.beginHomeModuleEnterTransition();
                  })
                  .width('100%')
                  .margin({ top: 12 })
                  .swipeAction(this.isBatchEditing ? undefined : {
                    end: () => {
                      this.deleteSwipeAction(book);
                    }
                  })
                } else {
                  ListItem() {
                    this.buildLocalBookCard(book)
                  }
                  .opacity(this.getHomeModuleContentOpacity(this.getBookEntranceStage(book.id)))
                  .translate({ y: this.getHomeModuleContentOffset(this.getBookEntranceStage(book.id)) })
                  .width('100%')
                  .swipeAction(this.isBatchEditing ? undefined : {
                    end: () => {
                      this.deleteSwipeAction(book);
                    }
                  })
                }
              }, (book: WordBook) => book.id.toString())

              ListItem() {
                this.buildBookListFooter()
              }
              .opacity(this.getHomeModuleContentOpacity(this.getBookSupportEntranceStage()))
              .translate({ y: this.getHomeModuleContentOffset(this.getBookSupportEntranceStage()) })
              .width('100%')
              .reuseId('word-book-manage-books-footer')
            }

            ListItem() {
              this.buildImportArea()
            }
            .opacity(this.getHomeModuleContentOpacity(this.getBookSupportEntranceStage() + 1))
            .translate({ y: this.getHomeModuleContentOffset(this.getBookSupportEntranceStage() + 1) })
            .width('100%')
            .reuseId('word-book-manage-import')

            ListItem() {
              Column().width('100%').height(32)
            }
            .width('100%')
            .reuseId('word-book-manage-bottom-spacer')
          }
          .width('100%')
          .height('100%')
          .padding({ left: 20, right: 20, top: 0 })
          .contentStartOffset(-SUB_PAGE_CONTENT_OVERLAP)
          .contentEndOffset(SUB_PAGE_CONTENT_OVERLAP)
          .cachedCount(2)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .enableScrollInteraction(true)
          .friction(0.75)
          .scrollBar(BarState.Auto)
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .titleBar(createHdsSubPageTitleBarOptions('词书管理', this.darkMode, this.materialEffectMode, undefined,
        this.getTitleMenuItems()))
      .titleMode(HdsNavDestinationTitleMode.MINI)
      .hideBackButton(false)
      .onBackPressed(() => {
        this.returnToPreviousPage();
        return true;
      })
      .bindToScrollable([this.pageScroller])
      .backgroundColor(ThemeColor.get(this.darkMode).background)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeColor.get(this.darkMode).background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}

