import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 是否为 web 平台(纯 Dart 版,不依赖 flutter)
/// dart:io 在 web 平台不可用,所以用 try-catch 检测
final bool _kIsWeb = _detectWeb();
bool _detectWeb() {
  try {
    // web 平台访问 Platform 会抛错
    return !Platform.isLinux && !Platform.isWindows && !Platform.isMacOS &&
           !Platform.isAndroid && !Platform.isIOS;
  } catch (_) {
    return true;  // Platform 不可用 = web
  }
}

/// 迁移回调签名：接收已打开的 Database，执行 DDL 变更。
typedef MigrationHandler = Future<void> Function(Database db);

/// 建库回调签名：首次创建时调用，版本号即为 currentVersion。
typedef CreateHandler = Future<void> Function(Database db, int version);

/// SQLite 数据库迁移管理器。
///
/// 使用示例：
/// ```dart
/// final db = await SqliteMigrator.open(
///   dbName: 'myapp.db',
///   currentVersion: 3,
///   onCreate: (db, v) async {
///     await db.execute('CREATE TABLE items (id INTEGER PRIMARY KEY)');
///   },
///   migrations: {
///     2: (db) async => db.execute('ALTER TABLE ...'),
///     3: (db) async => db.execute('ALTER TABLE ...'),
///   },
/// );
/// ```
class SqliteMigrator {
  SqliteMigrator._();

  /// 打开（或创建）数据库，自动处理迁移。
  ///
  /// [dbName] 数据库文件名（如 `myapp.db`）。
  /// [currentVersion] 当前代码期望的数据库版本号（正整数）。
  /// [onCreate] 新库创建时的回调，版本号为 [currentVersion]。
  /// [migrations] 迁移映射：key 为旧版本号，value 为从该版本升级到下一版本的迁移函数。
  ///   例如 `{2: v2toV3}` 会在 DB 版本 == 2 时执行，执行后版本变为 3。
  /// [enableFfi] 桌面端是否启用 FFI 模式（默认自动检测）。
  /// [enableWal] 是否启用 WAL 日志模式（推荐，默认 true）。
  static Future<Database> open({
    required String dbName,
    required int currentVersion,
    CreateHandler? onCreate,
    Map<int, MigrationHandler> migrations = const {},
    bool? enableFfi,
    bool enableWal = true,
  }) async {
    // ── FFI 适配（桌面端）──
    if (enableFfi ?? (!_kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS))) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbDir = await getDatabasesPath();
    final dbPath = path.join(dbDir, dbName);

    // ── 版本检测 ──
    final storedVersion = await _readVersion(dbDir, dbName);
    final dbFile = File(dbPath);
    final dbExists = await dbFile.exists();

    // ── DB 文件与 prefs 不同步：清除版本号，重新执行 onCreate ──
    if (!dbExists && storedVersion > 0) {
      await _clearVersion(dbDir, dbName);
    }

    // ── 需要重建：版本标记为 0（v0 无版本时代的残留）──
    if (storedVersion == 0 && dbExists) {
      final backupPath = path.join(dbDir, '${dbName}_v${storedVersion}_backup.db');
      try {
        await dbFile.copy(backupPath);
      } catch (_) {
        // 备份失败不阻塞
      }
      await dbFile.delete();
    }

    // ── 打开数据库 ──
    final db = await openDatabase(
      dbPath,
      version: currentVersion,
      onCreate: (db, version) async {
        if (enableWal) {
          await db.execute('PRAGMA journal_mode=WAL');
        }
        await onCreate?.call(db, version);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        for (var v = oldVersion; v < newVersion; v++) {
          final handler = migrations[v];
          if (handler != null) {
            await handler(db);
          }
        }
      },
    );

    // ── 记录当前版本（DB 打开成功后再写）──
    await _writeVersion(dbDir, dbName, currentVersion);

    return db;
  }

  // ── 版本持久化 ──────────────────────────────────

  static Future<int> _readVersion(String dbDir, String dbName) async {
    final prefsPath = path.join(dbDir, '${dbName}_prefs.json');
    final prefsFile = File(prefsPath);
    if (!await prefsFile.exists()) return -1; // 从未被 SqliteMigrator 管理过
    try {
      final content = await prefsFile.readAsString();
      final prefs = jsonDecode(content) as Map<String, dynamic>;
      return prefs['db_version'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> _writeVersion(String dbDir, String dbName, int version) async {
    final prefsPath = path.join(dbDir, '${dbName}_prefs.json');
    final prefsFile = File(prefsPath);
    final dir = prefsFile.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await prefsFile.writeAsString(jsonEncode({'db_version': version}));
  }

  static Future<void> _clearVersion(String dbDir, String dbName) async {
    final prefsPath = path.join(dbDir, '${dbName}_prefs.json');
    final prefsFile = File(prefsPath);
    if (await prefsFile.exists()) {
      await prefsFile.delete();
    }
  }
}
