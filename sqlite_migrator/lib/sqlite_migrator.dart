/// SQLite 数据库版本迁移管理器
///
/// 自动处理：
///   - 数据库版本追踪（JSON prefs）
///   - 旧库自动备份
///   - onCreate / onUpgrade 回调链
///   - WAL 模式 + 跨平台 FFI 适配
///
/// ```dart
/// final db = await SqliteMigrator.open(
///   dbName: 'myapp.db',
///   currentVersion: 5,
///   onCreate: (db, version) async {
///     await db.execute('CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT)');
///   },
///   migrations: {
///     2: (db) async => db.execute('ALTER TABLE items ADD COLUMN tags TEXT'),
///     3: (db) async => db.execute('ALTER TABLE items ADD COLUMN created TEXT'),
///     4: (db) async { /* 复杂迁移 */ },
///     5: (db) async => db.execute('ALTER TABLE items ADD COLUMN pinned INTEGER DEFAULT 0'),
///   },
/// );
/// ```
library sqlite_migrator;

export 'src/migrator.dart';
