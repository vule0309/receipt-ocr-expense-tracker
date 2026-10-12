import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/category.dart';
import '../models/expense.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('expenses.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        merchant TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        category TEXT NOT NULL,
        note TEXT,
        rawOcrText TEXT,
        imagePath TEXT,
        thumbnailPath TEXT,
        confidence REAL DEFAULT 1.0,
        lineItems TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // Create index on date and category for fast analytics query
    await db.execute('CREATE INDEX idx_expenses_date ON expenses(date)');
    await db.execute('CREATE INDEX idx_expenses_category ON expenses(category)');
  }

  // Insert
  Future<ExpenseItem> insertExpense(ExpenseItem expense) async {
    final db = await database;
    final id = await db.insert('expenses', expense.toMap());
    return expense.copyWith(id: id);
  }

  // Read all or with filters
  Future<List<ExpenseItem>> getExpenses({
    ExpenseCategory? category,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    final db = await database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (category != null) {
      whereClauses.add('category = ?');
      whereArgs.add(category.name);
    }

    if (startDate != null) {
      whereClauses.add('date >= ?');
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereClauses.add('date <= ?');
      whereArgs.add(endDate.toIso8601String());
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('(merchant LIKE ? OR note LIKE ?)');
      whereArgs.add('%$searchQuery%');
      whereArgs.add('%$searchQuery%');
    }

    final where = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final maps = await db.query(
      'expenses',
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'date DESC, id DESC',
    );

    return maps.map((map) => ExpenseItem.fromMap(map)).toList();
  }

  // Get by ID
  Future<ExpenseItem?> getExpenseById(int id) async {
    final db = await database;
    final maps = await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return ExpenseItem.fromMap(maps.first);
    }
    return null;
  }

  // Update
  Future<int> updateExpense(ExpenseItem expense) async {
    final db = await database;
    return await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  // Delete
  Future<int> deleteExpense(int id) async {
    final db = await database;
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Total spending sum
  Future<double> getTotalSpending({DateTime? startDate, DateTime? endDate}) async {
    final db = await database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (startDate != null) {
      whereClauses.add('date >= ?');
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      whereClauses.add('date <= ?');
      whereArgs.add(endDate.toIso8601String());
    }

    final where = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM expenses ${where != null ? 'WHERE $where' : ''}',
      whereArgs,
    );

    final total = result.first['total'];
    return (total as num?)?.toDouble() ?? 0.0;
  }

  // Spending aggregated by category for Pie / Donut Chart
  Future<Map<ExpenseCategory, double>> getSpendingByCategory({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (startDate != null) {
      whereClauses.add('date >= ?');
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      whereClauses.add('date <= ?');
      whereArgs.add(endDate.toIso8601String());
    }

    final where = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';
    final result = await db.rawQuery(
      'SELECT category, SUM(amount) as total FROM expenses $where GROUP BY category',
      whereArgs,
    );

    final map = <ExpenseCategory, double>{};
    for (final cat in ExpenseCategory.values) {
      map[cat] = 0.0;
    }

    for (final row in result) {
      final catStr = row['category'] as String?;
      final total = (row['total'] as num?)?.toDouble() ?? 0.0;
      if (catStr != null) {
        final cat = ExpenseCategoryExtension.fromString(catStr);
        map[cat] = (map[cat] ?? 0.0) + total;
      }
    }

    return map;
  }

  // Spending aggregated by day of week for Bar Chart
  Future<Map<int, double>> getWeeklySpending({DateTime? anchorDate}) async {
    final anchor = anchorDate ?? DateTime.now();
    // Start of week: Monday
    final startOfWeek = DateTime(anchor.year, anchor.month, anchor.day)
        .subtract(Duration(days: anchor.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minute: 59, second: 59));

    final db = await database;
    final result = await db.rawQuery(
      'SELECT date, amount FROM expenses WHERE date >= ? AND date <= ?',
      [startOfWeek.toIso8601String(), endOfWeek.toIso8601String()],
    );

    // Days: 1 (Mon) to 7 (Sun)
    final weeklyMap = <int, double>{
      1: 0.0,
      2: 0.0,
      3: 0.0,
      4: 0.0,
      5: 0.0,
      6: 0.0,
      7: 0.0,
    };

    for (final row in result) {
      final dateStr = row['date'] as String?;
      final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
      if (dateStr != null) {
        final date = DateTime.tryParse(dateStr);
        if (date != null) {
          weeklyMap[date.weekday] = (weeklyMap[date.weekday] ?? 0.0) + amount;
        }
      }
    }

    return weeklyMap;
  }

  // Seed sample mock receipts for demonstration
  Future<void> seedMockDataIfEmpty() async {
    final expenses = await getExpenses();
    if (expenses.isNotEmpty) return;

    final now = DateTime.now();
    final sampleData = [
      ExpenseItem(
        merchant: 'WinMart Supermarket',
        amount: 215000,
        date: now.subtract(const Duration(days: 1)),
        category: ExpenseCategory.food,
        note: 'Fresh milk, bread, instant noodles',
        confidence: 0.95,
      ),
      ExpenseItem(
        merchant: 'Nhà Sách Fahasa',
        amount: 340000,
        date: now.subtract(const Duration(days: 2)),
        category: ExpenseCategory.study,
        note: 'Data structures textbook & notebooks',
        confidence: 0.92,
      ),
      ExpenseItem(
        merchant: 'Grab Bike',
        amount: 45000,
        date: now.subtract(const Duration(days: 2)),
        category: ExpenseCategory.travel,
        note: 'Commute from campus to dorm',
        confidence: 0.98,
      ),
      ExpenseItem(
        merchant: 'Highlands Coffee',
        amount: 65000,
        date: now.subtract(const Duration(days: 3)),
        category: ExpenseCategory.food,
        note: 'Iced peach jelly tea',
        confidence: 0.95,
      ),
      ExpenseItem(
        merchant: 'GearVN',
        amount: 520000,
        date: now.subtract(const Duration(days: 4)),
        category: ExpenseCategory.gear,
        note: 'Logitech silent mouse & mousepad',
        confidence: 0.89,
      ),
      ExpenseItem(
        merchant: 'CGV Cinemas',
        amount: 190000,
        date: now.subtract(const Duration(days: 5)),
        category: ExpenseCategory.entertainment,
        note: 'Weekend movie ticket with popcorn',
        confidence: 0.91,
      ),
      ExpenseItem(
        merchant: 'Cây Xăng Petrolimex',
        amount: 100000,
        date: now.subtract(const Duration(days: 6)),
        category: ExpenseCategory.travel,
        note: 'Full tank RON 95',
        confidence: 0.88,
      ),
    ];

    for (final item in sampleData) {
      await insertExpense(item);
    }
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
