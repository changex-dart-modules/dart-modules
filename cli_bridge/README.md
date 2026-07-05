# cli_bridge

通用 CLI Bridge 框架 — 给 Dart/Flutter 应用提供 TCP JSON-line 命令通道。
纯 Dart 包,不依赖 Flutter SDK。

## 用途

让外部进程(AI / CLI 工具 / 测试脚本)通过 TCP 命令操控正在运行的 Dart/Flutter 应用。
典型场景是给桌面 GUI 应用做自动化测试入口或 AI 操作入口。

## 核心能力

| 能力 | 说明 |
|------|------|
| 命令注册 + 路由分发 | `bridge.on('cmd', schema: {...}, handler: ...)` |
| 参数 schema 声明 | 必填/可选、类型、默认值、描述 |
| 自动校验 | 缺失必填字段 / 类型不匹配 → 自动返回错误 |
| 接口文档生成 | `help` 命令自动列出所有接口的参数表 |

## 安装

```yaml
# pubspec.yaml
dependencies:
  cli_bridge:
    path: /workspace/dart-modules/cli_bridge
```

## 快速开始

### Dart 端 — 注册并启动

```dart
import 'package:cli_bridge/cli_bridge.dart';

final bridge = CliBridge(port: 9999);

bridge.on('add_item', schema: {
  'name':  const Param.string(required: true, desc: '名称'),
  'count': const Param.integer(defaultValue: 0, desc: '数量'),
}, handler: (params) async {
  // params 已校验:name 是 String,count 是 int
  return myService.add(params['name'], count: params['count']);
});

await bridge.start();
```

### 客户端 — 通过 TCP 调用

任何能发 TCP JSON-line 的客户端都能用。atoms-habits 项目提供了 `atoms_cli` 二进制(基于 Dart)作为推荐客户端:

```bash
# 健康检查
atoms_cli ping

# 调用注册的命令
atoms_cli add_item --name "hello" --count 3
```

### 协议格式

请求(JSON 一行):
```json
{"cmd": "add_item", "name": "hello", "count": 3}
```

响应(JSON 一行):
```json
{"status": "ok", "data": {"id": 1, "name": "hello", "count": 3}}
```

错误:
```json
{"status": "error", "message": "缺少必填参数 'name'"}
```

## 参数类型

| 工厂方法 | JSON 类型 | 示例 |
|----------|----------|------|
| `Param.string(required: true)` | String | `"hello"` |
| `Param.integer(defaultValue: 0)` | int | `42` |
| `Param.number(defaultValue: 0.0)` | num | `3.14` |
| `Param.boolean(defaultValue: false)` | bool | `true` |
| `Param.stringList()` | List<String> | `["a","b"]` |
| `Param.object()` | Map | `{"key":"val"}` |

## 目录结构

```
cli_bridge/
├── lib/
│   ├── cli_bridge.dart    # 导出入口
│   └── src/
│       ├── bridge.dart    # TCP server + 路由分发 + 异常捕获
│       └── param.dart     # 参数声明 + 类型校验
├── pubspec.yaml           # 纯 Dart,不依赖 Flutter
└── README.md
```

## 客户端实现

本包只提供**服务端**(监听 TCP)。客户端由各项目按需实现:
- atoms-habits 项目用 `cli/atoms_cli.dart`(Dart 编译的单二进制)
- 其他项目可参考 atoms_cli 的实现,或直接用任何语言的 socket 库

历史上有 Python 版 `base_client.py`,已移除,改由 atoms_cli(Dart)统一承担客户端职责。
