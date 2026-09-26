import { relationalStore } from '@kit.ArkData';
import { WordBook } from '../model/WordBook';
import { DatabaseService } from './DatabaseService';

export class WordBookService {
  public static async getAllWordBooks(): Promise<WordBook[]> {
    const books: WordBook[] = [];
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await DatabaseService.querySql(
        'SELECT id, name, description, total_count, created_at FROM word_book ORDER BY created_at DESC'
      );
      while (resultSet.goToNextRow()) {
        books.push({
          id: resultSet.getLong(resultSet.getColumnIndex('id')),
          name: resultSet.getString(resultSet.getColumnIndex('name')),
          description: resultSet.getString(resultSet.getColumnIndex('description')),
          totalCount: resultSet.getLong(resultSet.getColumnIndex('total_count')),
          createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at'))
        });
      }
    } catch (error) {
      console.error('getAllWordBooks failed: ' + JSON.stringify(error));
    } finally {
      if (resultSet) {
        resultSet.close();
      }
    }
    return books;
  }

  public static async createWordBook(name: string, description: string): Promise<number> {
    try {
      const store = DatabaseService.getStore();
      const rowId: number = await store.insert('word_book', {
        'name': name,
        'description': description,
        'total_count': 0,
        'created_at': Date.now()
      });
      console.info('createWordBook: inserted ' + name + ', rowId=' + rowId.toString());
      return rowId;
    } catch (error) {
      console.error('createWordBook failed: ' + JSON.stringify(error));
    }
    return 0;
  }

  public static async getBookById(bookId: number): Promise<WordBook | null> {
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await DatabaseService.querySql(
        'SELECT id, name, description, total_count, created_at FROM word_book WHERE id = ? LIMIT 1',
        [bookId]
      );
      if (resultSet.goToFirstRow()) {
        return {
          id: resultSet.getLong(resultSet.getColumnIndex('id')),
          name: resultSet.getString(resultSet.getColumnIndex('name')),
          description: resultSet.getString(resultSet.getColumnIndex('description')),
          totalCount: resultSet.getLong(resultSet.getColumnIndex('total_count')),
          createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at'))
        };
      }
    } catch (error) {
      console.error('getBookById failed: ' + JSON.stringify(error));
    } finally {
      if (resultSet) {
        resultSet.close();
      }
    }
    return null;
  }

  public static async updateTotalCount(bookId: number): Promise<void> {
    try {
      const count: number = await WordBookService.getWordCount(bookId);
      await DatabaseService.executeSql('UPDATE word_book SET total_count = ? WHERE id = ?', [count, bookId]);
    } catch (error) {
      console.error('updateTotalCount failed: ' + JSON.stringify(error));
    }
  }

  public static async getWordCount(bookId: number): Promise<number> {
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await DatabaseService.querySql('SELECT COUNT(*) AS count FROM words WHERE book_id = ?', [bookId]);
      if (resultSet.goToFirstRow()) {
        return resultSet.getLong(resultSet.getColumnIndex('count'));
      }
    } catch (error) {
      console.error('getWordCount failed: ' + JSON.stringify(error));
    } finally {
      if (resultSet) {
        resultSet.close();
      }
    }
    return 0;
  }

  public static async deleteWordBook(bookId: number): Promise<void> {
    try {
      await DatabaseService.executeSqlThrow(
        'DELETE FROM study_record WHERE word_id IN (SELECT id FROM words WHERE book_id = ?)',
        [bookId]
      );
      await DatabaseService.executeSqlThrow(
        'DELETE FROM study_event WHERE word_id IN (SELECT id FROM words WHERE book_id = ?)',
        [bookId]
      );
      await DatabaseService.executeSqlThrow('DELETE FROM words WHERE book_id = ?', [bookId]);
      await DatabaseService.executeSqlThrow('DELETE FROM word_book WHERE id = ?', [bookId]);
    } catch (error) {
      console.error('deleteWordBook failed: ' + JSON.stringify(error));
    }
  }

  public static async deleteEmptyWordBooksByName(name: string): Promise<void> {
    const books: WordBook[] = await WordBookService.getAllWordBooks();
    for (let index: number = 0; index < books.length; index++) {
      const book: WordBook = books[index];
      if (book.name === name) {
        await WordBookService.deleteWordBook(book.id);
      }
    }
  }

  private static async getLastInsertId(): Promise<number> {
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await DatabaseService.querySql('SELECT last_insert_rowid() AS id');
      if (resultSet.goToFirstRow()) {
        return resultSet.getLong(resultSet.getColumnIndex('id'));
      }
    } catch (error) {
      console.error('getLastInsertId failed: ' + JSON.stringify(error));
    } finally {
      if (resultSet) {
        resultSet.close();
      }
    }
    return 0;
  }
}
