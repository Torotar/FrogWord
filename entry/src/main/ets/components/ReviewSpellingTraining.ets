import { Word } from '../model/Word';
import { ArrayUtil } from '../utils/ArrayUtil';
import { Constants } from '../utils/Constants';
import { ThemeColor } from '../utils/ThemeColor';

type SpellingQuestionMode = 'complete' | 'spell' | 'choice';
type ChoiceQuestionMode = 'translationToWord' | 'wordToTranslation';

@Component
export struct ReviewSpellingTraining {
  @Prop words: Word[] = [];
  @Prop distractorPool: Word[] = [];
  @Prop darkMode: boolean = false;
  @Prop autoPronounce: boolean = false;
  @Link audioMessage: string;

  @State private currentIndex: number = 0;
  @State private spellingPronounceFrame: number = 2;
  @State private spellingInput: string = '';
  @State private spellingFeedback: string = '';
  @State private spellingHintText: string = '';
  @State private spellingChecked: boolean = false;
  @State private spellingCorrect: boolean = false;
  @State private spellingQuestionMode: SpellingQuestionMode = 'spell';
  @State private choiceQuestionMode: ChoiceQuestionMode = 'translationToWord';
  @State private spellingLetters: string[] = [];
  @State private spellingEditableSlots: boolean[] = [];
  @State private spellingOptions: string[] = [];
  @State private selectedSpellingOption: string = '';
  @State private spellingHintLevel: number = 0;
  @State private activeSpellingSlot: number = -1;
  @State private isSubmitting: boolean = false;
  @State private correctCount: number = 0;
  @State private wrongCount: number = 0;

  private spellingPronounceAnimationTimer: number = -1;
  private spellingPronounceAnimationId: number = 0;
  private answerStartedAt: number = 0;
  private readonly SPELLING_INPUT_ID: string = 'review-spelling-input';
  onPronounce: (word: Word) => Promise<void> = async (_word: Word): Promise<void> => {};
  onAnswer: (word: Word, isCorrect: boolean, elapsedSeconds: number) => Promise<void> =
    async (_word: Word, _isCorrect: boolean, _elapsedSeconds: number): Promise<void> => {};
  onFinished: (correctCount: number, wrongCount: number) => void =
    (_correctCount: number, _wrongCount: number): void => {};

  aboutToAppear(): void {
    this.currentIndex = 0;
    this.correctCount = 0;
    this.wrongCount = 0;
    this.answerStartedAt = Date.now();
    this.resetSpellingState();
    this.scheduleAutoPronounce();
  }

  aboutToDisappear(): void {
    this.stopSpellingPronounceAnimation();
  }

  private currentWord(): Word {
    return this.words[this.currentIndex];
  }

  private scheduleAutoPronounce(): void {
    if (!this.autoPronounce || this.words.length === 0) {
      return;
    }
    setTimeout((): void => {
      if (this.autoPronounce && this.words.length > 0) {
        this.runSpellingPronounceAnimation(this.onPronounce(this.currentWord()));
      }
    }, 120);
  }

  private spellingPronounceIcon(): Resource {
    if (this.spellingPronounceFrame === 0) {
      return this.darkMode ? $r('app.media.pronounce_dark_frame1') : $r('app.media.pronounce_light_frame1');
    }
    if (this.spellingPronounceFrame === 1) {
      return this.darkMode ? $r('app.media.pronounce_dark_frame2') : $r('app.media.pronounce_light_frame2');
    }
    return this.darkMode ? $r('app.media.pronounce_dark') : $r('app.media.pronounce_light');
  }

  private startSpellingPronounceAnimation(): number {
    this.stopSpellingPronounceAnimation(false);
    const animationId: number = this.spellingPronounceAnimationId + 1;
    this.spellingPronounceAnimationId = animationId;
    this.spellingPronounceFrame = 0;
    this.spellingPronounceAnimationTimer = setInterval((): void => {
      this.spellingPronounceFrame = (this.spellingPronounceFrame + 1) % 3;
    }, Constants.PRONUNCIATION_ANIMATION_FRAME_INTERVAL_MS);
    return animationId;
  }

  private stopSpellingPronounceAnimation(resetFrame: boolean = true): void {
    if (this.spellingPronounceAnimationTimer >= 0) {
      clearInterval(this.spellingPronounceAnimationTimer);
      this.spellingPronounceAnimationTimer = -1;
    }
    if (resetFrame) {
      this.spellingPronounceFrame = 2;
    }
  }

  private async runSpellingPronounceAnimation(playTask: Promise<void>): Promise<void> {
    const animationId: number = this.startSpellingPronounceAnimation();
    try {
      await playTask;
    } finally {
      if (this.spellingPronounceAnimationId === animationId) {
        this.stopSpellingPronounceAnimation();
      }
    }
  }

  private resetSpellingState(): void {
    this.spellingInput = '';
    this.spellingFeedback = '';
    this.spellingHintText = '';
    this.spellingChecked = false;
    this.spellingCorrect = false;
    this.selectedSpellingOption = '';
    this.spellingHintLevel = 0;
    this.activeSpellingSlot = -1;
    this.prepareSpellingQuestion();
  }

  private normalizeSpelling(value: string): string {
    return value.trim().toLowerCase().replace(/\s+/g, ' ');
  }

  private prepareSpellingQuestion(): void {
    if (this.words.length === 0) {
      this.spellingLetters = [];
      this.spellingEditableSlots = [];
      this.spellingOptions = [];
      return;
    }
    this.spellingQuestionMode = this.spellingQuestionModeForIndex();
    this.choiceQuestionMode = this.choiceQuestionModeForIndex();
    this.spellingEditableSlots = this.buildSpellingEditableSlots();
    this.spellingLetters = this.buildInitialSpellingLetters();
    this.spellingOptions = this.spellingQuestionMode === 'choice' ? this.buildSpellingOptions() : [];
    this.activeSpellingSlot = this.firstEditableSpellingSlot();
  }

  private spellingQuestionModeForIndex(): SpellingQuestionMode {
    const modeIndex: number = this.currentIndex % 3;
    if (modeIndex === 0) {
      return 'complete';
    }
    if (modeIndex === 1) {
      return 'spell';
    }
    return 'choice';
  }

  private choiceQuestionModeForIndex(): ChoiceQuestionMode {
    return Math.floor(this.currentIndex / 3) % 2 === 0 ? 'translationToWord' : 'wordToTranslation';
  }

  private currentWordCharacters(): string[] {
    return this.currentWord().word.split('');
  }

  private isEditableCharacter(character: string): boolean {
    if (character.length === 0) {
      return false;
    }
    const lower: string = character.toLowerCase();
    return lower >= 'a' && lower <= 'z';
  }

  private buildSpellingEditableSlots(): boolean[] {
    const characters: string[] = this.currentWordCharacters();
    const slots: boolean[] = [];
    if (this.spellingQuestionMode === 'choice') {
      for (let i: number = 0; i < characters.length; i++) {
        slots.push(false);
      }
      return slots;
    }
    let hasEditableSlot: boolean = false;
    for (let i: number = 0; i < characters.length; i++) {
      let editable: boolean = false;
      if (this.isEditableCharacter(characters[i])) {
        editable = this.spellingQuestionMode === 'spell' ||
          (i > 0 && i < characters.length - 1 && (i + this.currentIndex) % 2 === 0);
      }
      hasEditableSlot = hasEditableSlot || editable;
      slots.push(editable);
    }
    if (!hasEditableSlot && this.spellingQuestionMode === 'complete') {
      for (let i: number = 0; i < characters.length; i++) {
        if (this.isEditableCharacter(characters[i])) {
          slots[i] = true;
          break;
        }
      }
    }
    return slots;
  }

  private buildInitialSpellingLetters(): string[] {
    const characters: string[] = this.currentWordCharacters();
    const letters: string[] = [];
    for (let i: number = 0; i < characters.length; i++) {
      letters.push(this.spellingEditableSlots[i] ? '' : this.formatLetterForSlot(characters[i], i));
    }
    return letters;
  }

  private updateSpellingInput(value: string): void {
    if (this.spellingChecked) {
      return;
    }
    const nextInput: string = this.lastSpellingInputCharacter(value);
    if (nextInput.length === 0) {
      this.clearSpellingInputText();
      return;
    }
    this.applySpellingCharacter(nextInput);
    this.clearSpellingInputText();
  }

  private applySpellingCharacter(character: string): void {
    const nextLetters: string[] = [...this.spellingLetters];
    let slotIndex: number = this.activeSpellingSlot >= 0 ? this.activeSpellingSlot : this.firstEmptySpellingSlot();
    if (slotIndex < 0) {
      return;
    }
    nextLetters[slotIndex] = this.formatLetterForSlot(character, slotIndex);
    slotIndex = this.nextEmptySpellingSlot(nextLetters, slotIndex);
    this.spellingLetters = nextLetters;
    this.activeSpellingSlot = slotIndex;
    this.spellingFeedback = '';
  }

  private handleSpellingDelete(): void {
    if (this.spellingChecked) {
      return;
    }
    const nextLetters: string[] = [...this.spellingLetters];
    let slotIndex: number = this.activeSpellingSlot >= 0 ? this.activeSpellingSlot : this.firstEmptySpellingSlot();
    if (slotIndex >= 0 && this.spellingEditableSlots[slotIndex] && nextLetters[slotIndex].length > 0) {
      nextLetters[slotIndex] = '';
    } else {
      slotIndex = this.previousFilledSpellingSlot(slotIndex);
      if (slotIndex < 0) {
        return;
      }
      nextLetters[slotIndex] = '';
    }
    this.spellingLetters = nextLetters;
    this.activeSpellingSlot = slotIndex;
    this.spellingFeedback = '';
    this.clearSpellingInputText();
  }

  private clearSpellingInputText(): void {
    this.spellingInput = '';
  }

  private lastSpellingInputCharacter(value: string): string {
    const nextInput: string = this.sanitizeSpellingInput(value);
    return nextInput.length > 0 ? nextInput.charAt(nextInput.length - 1) : '';
  }

  private sanitizeSpellingInput(value: string): string {
    const characters: string[] = value.split('');
    let result: string = '';
    for (let i: number = 0; i < characters.length; i++) {
      if (this.isEditableCharacter(characters[i])) {
        result += characters[i];
      }
    }
    return result;
  }

  private formatLetterForSlot(character: string, index: number): string {
    return index > 0 ? character.toLowerCase() : character;
  }

  private firstEditableSpellingSlot(): number {
    return this.nextEditableSpellingSlot(-1);
  }

  private firstEmptySpellingSlot(): number {
    return this.nextEmptySpellingSlot(this.spellingLetters, -1);
  }

  private nextEditableSpellingSlot(index: number): number {
    for (let i: number = index + 1; i < this.spellingEditableSlots.length; i++) {
      if (this.spellingEditableSlots[i]) {
        return i;
      }
    }
    return -1;
  }

  private nextEmptySpellingSlot(letters: string[], index: number): number {
    for (let i: number = index + 1; i < this.spellingEditableSlots.length; i++) {
      if (this.spellingEditableSlots[i] && letters[i].length === 0) {
        return i;
      }
    }
    return -1;
  }

  private previousFilledSpellingSlot(index: number): number {
    const start: number = index >= 0 ? index - 1 : this.spellingEditableSlots.length - 1;
    for (let i: number = start; i >= 0; i--) {
      if (this.spellingEditableSlots[i] && this.spellingLetters[i].length > 0) {
        return i;
      }
    }
    return -1;
  }

  private activateSpellingSlot(index: number): void {
    if (!this.spellingChecked && this.spellingEditableSlots[index]) {
      this.activeSpellingSlot = index;
      this.focusSpellingInput();
    }
  }

  private focusSpellingInput(): void {
    if (this.spellingQuestionMode === 'choice' || this.spellingChecked || this.isSubmitting) {
      return;
    }
    focusControl.requestFocus(this.SPELLING_INPUT_ID);
  }

  private isSpellingAnswerReady(): boolean {
    if (this.spellingQuestionMode === 'choice') {
      return this.selectedSpellingOption.length > 0;
    }
    for (let i: number = 0; i < this.spellingEditableSlots.length; i++) {
      if (this.spellingEditableSlots[i] && this.spellingLetters[i].length === 0) {
        return false;
      }
    }
    return true;
  }

  private currentSpellingAnswer(): string {
    return this.spellingQuestionMode === 'choice' ? this.selectedSpellingOption : this.spellingLetters.join('');
  }

  private selectSpellingOption(option: string): void {
    if (this.spellingChecked || this.isSubmitting) {
      return;
    }
    this.selectedSpellingOption = option;
    this.spellingInput = option;
    this.spellingFeedback = '';
  }

  private buildSpellingOptions(): string[] {
    const options: string[] = [this.currentWord().word];
    const candidates: Word[] = this.sortedDistractorWords();
    for (let i: number = 0; i < candidates.length && options.length < 4; i++) {
      if (this.hasSimilarMeaning(candidates[i].translation, this.currentWord().translation) &&
        !this.containsSpellingOption(options, candidates[i].word)) {
        options.push(candidates[i].word);
      }
    }
    const variants: string[] = this.buildSpellingVariants(this.currentWord().word);
    for (let i: number = 0; i < variants.length && options.length < 4; i++) {
      if (!this.containsSpellingOption(options, variants[i])) {
        options.push(variants[i]);
      }
    }
    for (let i: number = 0; i < candidates.length && options.length < 4; i++) {
      if (!this.containsSpellingOption(options, candidates[i].word)) {
        options.push(candidates[i].word);
      }
    }
    let variantIndex: number = variants.length + 1;
    while (options.length < 4 && variantIndex < variants.length + 20) {
      const variant: string = this.buildFallbackSpellingVariant(this.currentWord().word, variantIndex);
      if (!this.containsSpellingOption(options, variant)) {
        options.push(variant);
      }
      variantIndex++;
    }
    return ArrayUtil.shuffle(options);
  }

  private sortedDistractorWords(): Word[] {
    const current: Word = this.currentWord();
    const candidates: Word[] = [];
    const pool: Word[] = this.distractorPool.length > 0 ? this.distractorPool : this.words;
    for (let i: number = 0; i < pool.length; i++) {
      if (this.normalizeSpelling(pool[i].word) !== this.normalizeSpelling(current.word)) {
        candidates.push(pool[i]);
      }
    }
    return candidates.sort((a: Word, b: Word): number => this.distractorScore(b) - this.distractorScore(a));
  }

  private distractorScore(candidate: Word): number {
    let score: number = this.spellingSimilarityScore(candidate.word, this.currentWord().word);
    if (this.hasSimilarMeaning(candidate.translation, this.currentWord().translation)) {
      score += 1000;
    }
    return score;
  }

  private spellingSimilarityScore(candidate: string, target: string): number {
    const a: string = candidate.toLowerCase();
    const b: string = target.toLowerCase();
    const minLength: number = Math.min(a.length, b.length);
    let samePosition: number = 0;
    let commonPrefix: number = 0;
    for (let i: number = 0; i < minLength; i++) {
      if (a.charAt(i) === b.charAt(i)) {
        samePosition++;
        if (commonPrefix === i) {
          commonPrefix++;
        }
      }
    }
    return samePosition * 4 + commonPrefix * 3 - Math.abs(a.length - b.length) * 2;
  }

  private hasSimilarMeaning(a: string, b: string): boolean {
    const aParts: string[] = this.translationPartsForMatch(a);
    const bParts: string[] = this.translationPartsForMatch(b);
    for (let i: number = 0; i < aParts.length; i++) {
      for (let j: number = 0; j < bParts.length; j++) {
        if (aParts[i].length > 0 && bParts[j].length > 0 &&
          (aParts[i] === bParts[j] || aParts[i].indexOf(bParts[j]) >= 0 || bParts[j].indexOf(aParts[i]) >= 0)) {
          return true;
        }
      }
    }
    return false;
  }

  private translationPartsForMatch(value: string): string[] {
    return value.replace(/[；;，,、。.!！?？]/g, '|').split('|')
      .map((item: string): string => item.trim().toLowerCase())
      .filter((item: string): boolean => item.length > 0);
  }

  private containsSpellingOption(options: string[], value: string): boolean {
    const normalizedValue: string = this.normalizeSpelling(value);
    for (let i: number = 0; i < options.length; i++) {
      if (this.normalizeSpelling(options[i]) === normalizedValue) {
        return true;
      }
    }
    return false;
  }

  private buildSpellingVariants(word: string): string[] {
    const variants: string[] = [];
    const characters: string[] = word.split('');
    for (let i: number = 0; i < characters.length - 1; i++) {
      if (this.isEditableCharacter(characters[i]) && this.isEditableCharacter(characters[i + 1])) {
        const swapped: string[] = [...characters];
        const temp: string = swapped[i];
        swapped[i] = swapped[i + 1];
        swapped[i + 1] = temp;
        this.pushUniqueSpellingVariant(variants, swapped.join(''));
      }
    }
    for (let i: number = 0; i < characters.length; i++) {
      if (this.isEditableCharacter(characters[i])) {
        const replaced: string[] = [...characters];
        replaced[i] = this.nextSimilarLetter(characters[i], i + 1);
        this.pushUniqueSpellingVariant(variants, replaced.join(''));
      }
    }
    if (characters.length > 3) {
      for (let i: number = 1; i < characters.length - 1; i++) {
        if (this.isEditableCharacter(characters[i])) {
          const removed: string[] = [...characters];
          removed.splice(i, 1);
          this.pushUniqueSpellingVariant(variants, removed.join(''));
        }
      }
    }
    return variants;
  }

  private pushUniqueSpellingVariant(variants: string[], value: string): void {
    if (this.normalizeSpelling(value) !== this.normalizeSpelling(this.currentWord().word) &&
      !this.containsSpellingOption(variants, value)) {
      variants.push(value);
    }
  }

  private nextSimilarLetter(character: string, offset: number): string {
    const lower: string = character.toLowerCase();
    if (!this.isEditableCharacter(lower)) {
      return character;
    }
    const code: number = lower.charCodeAt(0) - 97;
    return String.fromCharCode(97 + (code + offset + 1) % 26);
  }

  private buildFallbackSpellingVariant(word: string, variantIndex: number): string {
    const characters: string[] = word.split('');
    if (characters.length === 0) {
      return word + variantIndex.toString();
    }
    let targetIndex: number = variantIndex % characters.length;
    for (let i: number = 0; i < characters.length; i++) {
      const probeIndex: number = (targetIndex + i) % characters.length;
      if (this.isEditableCharacter(characters[probeIndex])) {
        targetIndex = probeIndex;
        break;
      }
    }
    const current: string = characters[targetIndex].toLowerCase();
    if (!this.isEditableCharacter(current)) {
      return word + variantIndex.toString();
    }
    characters[targetIndex] = this.nextSimilarLetter(current, variantIndex + 3);
    return characters.join('');
  }

  private spellingModeTitle(): string {
    if (this.spellingQuestionMode === 'complete') {
      return '补全单词';
    }
    if (this.spellingQuestionMode === 'choice') {
      return this.choiceQuestionMode === 'wordToTranslation' ? '选择正确释义' : '选择正确拼写';
    }
    return '逐字母拼写';
  }

  private spellingPromptText(): string {
    if (this.spellingQuestionMode === 'choice' && this.choiceQuestionMode === 'wordToTranslation') {
      return this.currentWord().word;
    }
    return this.currentWord().translation;
  }

  private optionWord(option: string): Word {
    const normalizedOption: string = this.normalizeSpelling(option);
    if (normalizedOption === this.normalizeSpelling(this.currentWord().word)) {
      return this.currentWord();
    }
    const pool: Word[] = this.distractorPool.length > 0 ? this.distractorPool : this.words;
    for (let i: number = 0; i < pool.length; i++) {
      if (this.normalizeSpelling(pool[i].word) === normalizedOption) {
        return pool[i];
      }
    }
    return this.currentWord();
  }

  private optionPrimaryText(option: string): string {
    return this.choiceQuestionMode === 'wordToTranslation' ? this.optionWord(option).translation : option;
  }

  private optionRevealText(option: string): string {
    if (!this.spellingChecked) {
      return '';
    }
    return this.choiceQuestionMode === 'wordToTranslation' ? option : this.optionWord(option).translation;
  }

  private spellingLetterAt(index: number): string {
    return index >= 0 && index < this.spellingLetters.length ? this.spellingLetters[index] : '';
  }

  private isSpellingSlotIncorrect(index: number): boolean {
    if (!this.spellingChecked || !this.spellingEditableSlots[index]) {
      return false;
    }
    const characters: string[] = this.currentWordCharacters();
    if (index < 0 || index >= characters.length) {
      return false;
    }
    return this.spellingLetterAt(index).toLowerCase() !== characters[index].toLowerCase();
  }

  private spellingSlotLineColor(index: number): string {
    if (this.isSpellingSlotIncorrect(index)) {
      return ThemeColor.get(this.darkMode).danger;
    }
    return this.spellingEditableSlots[index] ? ThemeColor.get(this.darkMode).primary :
      ThemeColor.get(this.darkMode).border;
  }

  private spellingSlotAccessibilityText(character: string, index: number): string {
    const position: string = (index + 1).toString();
    const letter: string = this.spellingLetterAt(index).length > 0 ? this.spellingLetterAt(index) : character;
    if (this.isSpellingSlotIncorrect(index)) {
      return '第' + position + '个字母，' + letter + '，输入错误';
    }
    if (this.spellingEditableSlots[index] && this.spellingLetterAt(index).length === 0) {
      return '第' + position + '个字母，待输入';
    }
    return '第' + position + '个字母，' + letter;
  }

  private spellingSlotAreaHeight(): number {
    const rowCount: number = Math.max(1, Math.ceil(this.currentWordCharacters().length / 7));
    return Math.min(146, rowCount * 42 + 6);
  }

  private spellingSlotFromTouch(x: number, y: number): number {
    const index: number = Math.floor(Math.max(0, y) / 42) * 7 + Math.floor(Math.max(0, x) / 40);
    if (index >= 0 && index < this.spellingEditableSlots.length && this.spellingEditableSlots[index]) {
      return index;
    }
    return this.activeSpellingSlot >= 0 ? this.activeSpellingSlot : this.firstEmptySpellingSlot();
  }

  private optionSelected(option: string): boolean {
    return this.normalizeSpelling(option) === this.normalizeSpelling(this.selectedSpellingOption);
  }

  private handleSpellingHint(): void {
    if (this.spellingQuestionMode === 'choice' || this.spellingChecked || this.spellingHintLevel >= 2) {
      return;
    }
    if (this.spellingHintLevel === 0) {
      this.spellingHintText = this.buildPartialSpellingHint();
      this.spellingHintLevel = 1;
      return;
    }
    this.spellingHintText = this.currentWord().word;
    this.spellingHintLevel = 2;
  }

  private buildPartialSpellingHint(): string {
    const characters: string[] = this.currentWordCharacters();
    const segment: number = this.currentIndex % 3;
    const start: number = Math.floor(characters.length * segment / 3);
    const end: number = Math.max(start + 1, Math.floor(characters.length * (segment + 1) / 3));
    return this.currentWord().word.substring(start, Math.min(end, characters.length));
  }

  private isCorrectOption(option: string): boolean {
    return this.normalizeSpelling(option) === this.normalizeSpelling(this.currentWord().word);
  }

  private optionBorderColor(option: string): string {
    if (this.spellingChecked && this.isCorrectOption(option)) {
      return ThemeColor.get(this.darkMode).success;
    }
    if (this.spellingChecked && this.optionSelected(option) && !this.isCorrectOption(option)) {
      return ThemeColor.get(this.darkMode).danger;
    }
    return this.optionSelected(option) ? ThemeColor.get(this.darkMode).primary : ThemeColor.get(this.darkMode).border;
  }

  private optionTextColor(option: string): string {
    if (this.spellingChecked && this.isCorrectOption(option)) {
      return ThemeColor.get(this.darkMode).success;
    }
    if (this.spellingChecked && this.optionSelected(option) && !this.isCorrectOption(option)) {
      return ThemeColor.get(this.darkMode).danger;
    }
    return this.optionSelected(option) ? ThemeColor.get(this.darkMode).primary : ThemeColor.get(this.darkMode).textPrimary;
  }

  private spellingFeedbackColor(): string {
    return this.spellingCorrect ? ThemeColor.get(this.darkMode).success : ThemeColor.get(this.darkMode).danger;
  }

  private currentPartOfSpeech(): string {
    const partOfSpeech: string | undefined = this.currentWord().partOfSpeech;
    return partOfSpeech ? partOfSpeech : '';
  }

  private async handleSpellingSubmit(): Promise<void> {
    if (this.words.length === 0 || this.isSubmitting || this.spellingChecked) {
      return;
    }
    if (!this.isSpellingAnswerReady()) {
      this.spellingFeedback = this.spellingQuestionMode === 'choice' ? '请选择一个拼写' : '请补完整所有字母';
      this.spellingCorrect = false;
      return;
    }
    this.isSubmitting = true;
    try {
      const word: Word = this.currentWord();
      const isCorrect: boolean = this.normalizeSpelling(this.currentSpellingAnswer()) === this.normalizeSpelling(word.word);
      const elapsedSeconds: number = Math.max(0, Math.floor((Date.now() - this.answerStartedAt) / 1000));
      await this.onAnswer(word, isCorrect, elapsedSeconds);
      if (isCorrect) {
        this.correctCount++;
        this.spellingFeedback = '拼写正确';
      } else {
        this.wrongCount++;
        this.spellingFeedback = '拼写错误，正确拼写：' + word.word;
      }
      this.spellingCorrect = isCorrect;
      this.spellingChecked = true;
    } finally {
      this.isSubmitting = false;
    }
  }

  private handleSpellingNext(): void {
    if (!this.spellingChecked || this.isSubmitting) {
      return;
    }
    if (this.currentIndex >= this.words.length - 1) {
      this.onFinished(this.correctCount, this.wrongCount);
      return;
    }
    this.currentIndex++;
    this.answerStartedAt = Date.now();
    this.audioMessage = '';
    this.resetSpellingState();
    this.scheduleAutoPronounce();
  }

  @Builder
  private buildSpellingPronounceButton() {
    Image(this.spellingPronounceIcon())
      .width(26)
      .height(26)
      .objectFit(ImageFit.Contain)
      .margin({ right: 8 })
      .accessibilityText('播放当前单词发音')
      .onClick(() => {
        this.runSpellingPronounceAnimation(this.onPronounce(this.currentWord()));
      })
  }

  @Builder
  private buildLetterSlot(character: string, index: number) {
    Column() {
      Text(this.spellingLetterAt(index).length > 0 ? this.spellingLetterAt(index) : ' ')
        .width(30)
        .height(32)
        .fontSize(20)
        .lineHeight(32)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .textAlign(TextAlign.Center)
      Row()
        .width(30)
        .height(this.activeSpellingSlot === index && this.spellingEditableSlots[index] && !this.spellingChecked ? 3 : 2)
        .backgroundColor(this.spellingSlotLineColor(index))
        .borderRadius(1)
    }
    .width(34)
    .height(40)
    .margin({ right: 6, top: 2 })
    .alignItems(HorizontalAlign.Center)
    .accessibilityText(this.spellingSlotAccessibilityText(character, index))
    .onClick(() => {
      this.activateSpellingSlot(index);
    })
  }

  @Builder
  private buildSpellingInputLayer() {
    TextInput({ text: this.spellingInput, placeholder: '' })
      .width(1)
      .height(1)
      .id(this.SPELLING_INPUT_ID)
      .type(InputType.Normal)
      .autoCapitalizationMode(AutoCapitalizationMode.NONE)
      .enablePreviewText(false)
      .inputFilter('[A-Za-z]')
      .maxLength(1)
      .defaultFocus(!this.spellingChecked && this.spellingQuestionMode !== 'choice')
      .opacity(0.01)
      .fontColor(Color.Transparent)
      .placeholderColor(Color.Transparent)
      .backgroundColor(Color.Transparent)
      .caretColor(Color.Transparent)
      .enableAutoFill(false)
      .enableKeyboardOnFocus(true)
      .enabled(!this.spellingChecked && !this.isSubmitting)
      .onAppear(() => {
        this.focusSpellingInput();
      })
      .onChange((value: string) => {
        this.updateSpellingInput(value);
      })
      .onWillInsert((value: InsertValue): boolean => {
        this.updateSpellingInput(value.insertValue);
        return false;
      })
      .onWillDelete((_value: DeleteValue): boolean => {
        this.handleSpellingDelete();
        return false;
      })
  }

  @Builder
  private buildSpellingSlots() {
    Column() {
      this.buildSpellingInputLayer()
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        ForEach(this.currentWordCharacters(), (character: string, index: number) => {
          this.buildLetterSlot(character, index)
        }, (character: string, index: number) => index.toString() + '-' + character)
      }
      .width('100%')
      .height(this.spellingSlotAreaHeight())
      .onTouch((event: TouchEvent): void => {
        if (event.type === TouchType.Down && event.touches && event.touches.length > 0) {
          this.activateSpellingSlot(this.spellingSlotFromTouch(event.touches[0].x, event.touches[0].y));
        }
      })
      .margin({ top: 2 })
    }
    .width('100%')
    .margin({ bottom: 4 })
  }

  @Builder
  private buildSpellingOptionButtons() {
    Column() {
      ForEach(this.spellingOptions, (option: string) => {
        Column() {
          Text(this.optionPrimaryText(option))
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.optionTextColor(option))
            .textAlign(TextAlign.Center)
            .maxLines(this.spellingChecked ? 2 : 1)
            .wordBreak(WordBreak.BREAK_WORD)
            .width('100%')
          if (this.optionRevealText(option).length > 0) {
            Text(this.optionRevealText(option))
              .fontSize(13)
              .fontColor(ThemeColor.get(this.darkMode).textSecondary)
              .textAlign(TextAlign.Center)
              .maxLines(1)
              .width('100%')
              .margin({ top: 4 })
          }
        }
        .width('100%')
        .height(this.spellingChecked ? 66 : 48)
        .padding({ left: 14, right: 14 })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(this.optionSelected(option) ? ThemeColor.get(this.darkMode).primaryLight : ThemeColor.get(this.darkMode).background)
        .border({ width: this.spellingChecked && this.isCorrectOption(option) ? 2 : 1, color: this.optionBorderColor(option) })
        .borderRadius(14)
        .margin({ top: 10 })
        .onClick(() => {
          this.selectSpellingOption(option);
        })
      }, (option: string) => option)
    }
    .width('100%')
    .margin({ top: 10 })
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text(this.spellingModeTitle())
            .fontSize(11)
            .fontColor(ThemeColor.get(this.darkMode).textSecondary)
          Text(this.spellingPromptText())
            .width('100%')
            .fontSize(22)
            .lineHeight(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeColor.get(this.darkMode).textPrimary)
            .textAlign(TextAlign.Start)
            .wordBreak(WordBreak.BREAK_WORD)
            .margin({ top: 12 })
          if (this.currentWord().phonetic.length > 0 || this.currentPartOfSpeech().length > 0) {
            Row() {
              this.buildSpellingPronounceButton()
              Text((this.currentPartOfSpeech().length > 0 ? this.currentPartOfSpeech() + '  ' : '') + this.currentWord().phonetic)
                .fontSize(14)
                .fontColor(ThemeColor.get(this.darkMode).textSecondary)
                .layoutWeight(1)
            }
            .alignItems(VerticalAlign.Center)
            .margin({ top: 10 })
            .width('100%')
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .padding({ right: 10 })

        Column() {
          Text((this.currentIndex + 1).toString() + ' / ' + this.words.length.toString())
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeColor.get(this.darkMode).primary)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor(ThemeColor.get(this.darkMode).primaryLight)
            .borderRadius(12)
          if (this.spellingQuestionMode !== 'choice') {
            Button('提示')
              .buttonStyle(ButtonStyleMode.NORMAL)
              .controlSize(ControlSize.SMALL)
              .role(ButtonRole.NORMAL)
              .enabled(!this.spellingChecked && this.spellingHintLevel < 2)
              .margin({ top: 8 })
              .onClick(() => {
                this.handleSpellingHint();
              })
          }
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      if (this.spellingHintText.length > 0) {
        Text('提示：' + this.spellingHintText)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeColor.get(this.darkMode).primary)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor(ThemeColor.get(this.darkMode).primaryLight)
          .borderRadius(12)
          .margin({ top: 6 })
          .width('100%')
          .textAlign(TextAlign.Start)
      }

      if (this.spellingQuestionMode === 'choice') {
        this.buildSpellingOptionButtons()
      } else {
        this.buildSpellingSlots()
      }

      if (this.spellingFeedback.length > 0) {
        Text(this.spellingFeedback)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.spellingFeedbackColor())
          .margin({ top: 6 })
          .width('100%')
          .textAlign(TextAlign.Center)
      }

      Button(this.spellingChecked ?
        (this.currentIndex < this.words.length - 1 ? '下一个训练' : '完成复习') :
        (this.spellingQuestionMode === 'choice' ? '提交选择' : '提交答案'))
        .width('100%')
        .buttonStyle(ButtonStyleMode.EMPHASIZED)
        .controlSize(ControlSize.NORMAL)
        .role(ButtonRole.NORMAL)
        .enabled(!this.isSubmitting)
        .margin({ top: 10 })
        .onClick(() => {
          if (this.spellingChecked) {
            this.handleSpellingNext();
          } else {
            this.handleSpellingSubmit();
          }
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 18, bottom: 18 })
    .backgroundColor(this.darkMode ? '#111827' : '#FFFFFF')
    .borderRadius(20)
    .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
    .shadow({ radius: 10, color: 'rgba(15, 23, 42, 0.05)', offsetY: 4 })
    .margin({ top: 18 })
  }
}
