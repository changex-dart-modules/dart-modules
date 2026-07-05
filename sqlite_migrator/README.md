# sqlite_migrator

SQLite 数据库版本迁移管理器。

## 能力

| 能力 | 说明 |
|------|------|
| 版本追踪 | 通过 JSON prefs 文件记录当前 DB 版本 |
| 自动备份 | 版本不兼容时自动备份旧库文件 |
| 迁移链 | 逐版本执行 `onUpgrade` 回调 |
| WAL 模式 | 默认启用，读写不互斥 |
| 跨平台 FFI | 桌面端自动切换 sqflite FFI |

## 安装

```yaml
dependencies:
  sqlite_migrator:
    path: /workspace/dart-modules/sqlite_migrator
```

## 快速开始

```dart
import 'package:sqlite_migrator/sqlite_migrator.dart';

final db = await SqliteMigrator.open(
  dbName: 'bookmarks.db',
  currentVersion: 2,
  onCreate: (db, version) async {
    await db.execute('''
      CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        url TEXT NOT NULL,
        title TEXT,
        created TEXT DEFAULT (datetime('now'))
      )
    ''');
    await db.execute('CREATE INDEX idx_bookmarks_created ON bookmarks(created)');
  },
  migrations: {
    1: (db) async {
      // v1 → v2：添加标签列和全文搜索
      await db.execute('ALTER TABLE bookmarks ADD COLUMN tags TEXT');
      await db.execute(
        'CREATE VIRTUAL TABLE IF NOT EXISTS bookmarks_fts USING fts5(url, title, tags)',
      );
    },
  },
);
```

## 迁移链执行顺序

```
DB 版本 0（首次创建）
  → onCreate(db, currentVersion)   # 版本跳至 currentVersion

DB 版本 1
  → migrations[1](db)              # 版本变为 2

DB 版本 2（= currentVersion）
  → 无需迁移，直接打开
```

## 版本回退 / 文件损坏

当存储版本 < 1 但 DB 文件存在时，自动备份为 `{dbName}_v{old}_backup.db`，然后重建。
