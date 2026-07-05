# cli_bridge

通用 CLI Bridge 框架 — Flutter 应用与 Python 自动化脚本之间的 TCP JSON-line 中间件。

## 核心能力

| 能力 | 说明 |
|------|------|
| 命令注册 + 路由分发 | `bridge.on('cmd', schema: {...}, handler: ...)` |
| 参数 schema 声明 | 必填/可选、类型、默认值、描述 |
| 自动校验 | 缺失必填字段 / 类型不匹配 → 自动返回错误 |
| 接口文档生成 | `help` 命令自动列出所有接口的参数表 |
| Python SDK | 配套 `cli_client.py`，开箱即用 |

## 安装

```yaml
# pubspec.yaml
dependencies:
  cli_bridge:
    path: ../dart-modules/cli_bridge
```

## 快速开始

### Dart 端 — 注册命令

```dart
import 'package:cli_bridge/cli_bridge.dart';

final bridge = CliBridge(port: 9999);

bridge.on('add_bookmark', schema: {
  'url':    const Param.string(required: true, desc: '书签链接'),
  'tags':   const Param.stringList(desc: '标签列表'),
  'pinned': const Param.boolean(defaultValue: false, desc: '是否置顶'),
}, handler: (params) async {
  // params 已校验：url 保证是 String，tags 保证是 List，pinned 保证是 bool
  return bookmarkService.add(
    params['url'],
    tags: params['tags'],
    pinned: params['pinned'],
  );
});

await bridge.start();
```

### Python 端 — 调用

```python
from cli_client import CliClient

cli = CliClient(port=9999)

# 先看接口文档
print(cli.help())

# 调用
result = cli.call('add_bookmark', url='https://flutter.dev', tags=['dev'], pinned=True)
print(result)  # {'id': 1, 'url': '...', ...}

cli.shutdown()
```

### 工作流

```
Dart 端                               Python 端
═══════                               ════════
注册 schema → 框架校验参数              help() → 看接口文档
              ↑                                     ↓
         唯一真相来源                           照 schema 传参
              ↓                                     ↓
         handler 执行                        cli.call('cmd', ...)
              ↓                                     ↑
         返回数据  ──── JSON-line ────→  拿到返回数据
```

## 参数类型

| 工厂方法 | JSON 类型 | 示例 |
|----------|----------|------|
| `Param.string(required: true)` | String | `"hello"` |
| `Param.integer(defaultValue: 0)` | int | `42` |
| `Param.boolean(defaultValue: false)` | bool | `true` |
| `Param.stringList()` | List | `["a","b"]` |
| `Param.object()` | Object | `{"key":"val"}` |

## Python SDK

基础类在 `dart-modules/cli_bridge/lib/src/base_client.py`。

业务项目使用方式：

```python
import sys
sys.path.insert(0, '/workspace/dart-modules/cli_bridge/lib/src')

from base_client import CliClient, CliError
```
