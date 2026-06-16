# dart-modules

Flutter 项目通用可复用模块仓库。

## 目录结构

```
dart-modules/
├── cli_bridge/          # CLI Bridge 框架 — TCP JSON-line 中间件
├── sqlite_migrator/     # (待创建) SQLite 迁移管理器
└── ...
```

## 使用方式

在业务项目的 `pubspec.yaml` 中引入：

```yaml
dependencies:
  cli_bridge:
    path: ../dart-modules/cli_bridge
```

## 创建新模块

每个模块是一个标准 Dart 包，遵循以下结构：

```
module_name/
├── pubspec.yaml         # name: module_name
├── lib/
│   ├── module_name.dart # 库入口（export src/*.dart）
│   └── src/             # 源码
├── README.md            # 使用文档
└── test/                # 单元测试
```

### 命名规范

- 目录名：`snake_case`
- Dart 包名：`snake_case`
- 类名：`PascalCase`

## 模块列表

| 模块 | 状态 | 说明 |
|------|------|------|
| `cli_bridge` | ✅ | Flutter ↔ Python CLI 自动化测试框架 |
| `sqlite_migrator` | ✅ | SQLite 数据库版本迁移管理器 |
