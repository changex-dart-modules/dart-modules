import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'param.dart';

/// CLI 命令的 handler 签名
///
/// [params] — 已经过 schema 校验和补默认值的参数 Map
typedef CliHandler = FutureOr<dynamic> Function(Map<String, dynamic> params);

// ── 内部路由条目 ──────────────────────────────────────

class _Route {
  final Map<String, Param> schema;
  final CliHandler handler;

  const _Route({required this.schema, required this.handler});
}

// ── CliBridge ─────────────────────────────────────────

/// TCP JSON-line CLI Bridge
///
/// ```dart
/// final bridge = CliBridge(port: 9999);
///
/// bridge.on('ping', schema: {}, handler: (_) => {'time': DateTime.now().toIso8601String()});
///
/// bridge.on('add_item', schema: {
///   'name': const Param.string(required: true, desc: '项目名称'),
///   'count': const Param.integer(defaultValue: 0, desc: '数量'),
/// }, handler: (params) async {
///   // params 已校验，类型安全
///   return myService.add(params['name'], count: params['count']);
/// });
///
/// await bridge.start();
/// ```
class CliBridge {
  final int port;

  ServerSocket? _server;
  final List<Socket> _clients = [];
  final Map<String, _Route> _routes = {};
  final DateTime _startTime = DateTime.now();

  /// 可选的静默模式（不打印客户端连接日志）
  final bool quiet;

  CliBridge({this.port = 9999, this.quiet = false});

  // ── 注册命令 ──────────────────────────────────────

  /// 注册一条 CLI 命令。
  ///
  /// [command] — 命令名字符串（Python 端 `cmd` 字段的值）
  /// [schema] — 参数声明（空 Map 表示无参数）
  /// [handler] — 业务处理函数
  void on(
    String command, {
    required Map<String, Param> schema,
    required CliHandler handler,
  }) {
    _routes[command] = _Route(schema: schema, handler: handler);
  }

  /// 批量注册命令
  void registerAll(Map<String, ({Map<String, Param> schema, CliHandler handler})> routes) {
    for (final entry in routes.entries) {
      on(entry.key, schema: entry.value.schema, handler: entry.value.handler);
    }
  }

  // ── 生命周期 ──────────────────────────────────────

  Future<void> start() async {
    // 自动注册 help 命令
    if (!_routes.containsKey('help')) {
      _registerHelpCommand();
    }

    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    if (!quiet) {
      // ignore: avoid_print
      print('[CliBridge] 启动在 localhost:$port');
    }

    _server!.listen(
      (socket) {
        _clients.add(socket);
        socket
            .cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              (line) => _handleLine(socket, line),
              onDone: () => _removeClient(socket),
              onError: (_) => _removeClient(socket),
            );
      },
    );
  }

  Future<void> stop() async {
    for (final c in _clients) {
      try {
        c.destroy();
      } catch (_) {}
    }
    _clients.clear();
    await _server?.close();
    _server = null;
  }

  /// 运行时长（秒）
  int get uptimeSeconds => DateTime.now().difference(_startTime).inSeconds;

  // ── 内部逻辑 ──────────────────────────────────────

  void _registerHelpCommand() {
    on('help', schema: {}, handler: (_) {
      final docs = <String, dynamic>{};
      for (final entry in _routes.entries) {
        if (entry.key == 'help') continue;
        final paramsDocs = <Map<String, dynamic>>[];
        for (final p in entry.value.schema.entries) {
          paramsDocs.add({
            'name': p.key,
            'type': typeName(p.value),
            'required': p.value.required,
            'default': p.value.defaultValue,
            'desc': p.value.desc,
          });
        }
        docs[entry.key] = {'params': paramsDocs};
      }
      return docs;
    });
  }

  Future<void> _handleLine(Socket socket, String line) async {
    try {
      final msg = jsonDecode(line) as Map<String, dynamic>;
      final cmd = msg.remove('cmd') as String?;

      if (cmd == null) {
        _respond(socket, status: 'error', message: '缺少 cmd 字段');
        return;
      }

      final route = _routes[cmd];
      if (route == null) {
        _respond(socket, status: 'error', message: '未知命令: $cmd');
        return;
      }

      // ── schema 校验 ──
      final validParams = <String, dynamic>{};
      for (final entry in route.schema.entries) {
        final name = entry.key;
        final param = entry.value;

        if (param.required && !msg.containsKey(name)) {
          _respond(socket, status: 'error', message: "缺少必填参数 '$name'");
          return;
        }

        dynamic value;
        if (msg.containsKey(name)) {
          value = msg[name];
          if (value != null && !typeMatches(value, param)) {
            _respond(
              socket,
              status: 'error',
              message: "参数 '$name' 类型错误：期望 ${typeName(param)}，实际 ${value.runtimeType}",
            );
            return;
          }
        } else {
          value = param.defaultValue;
        }

        validParams[name] = value;
      }

      // ── 调用 handler ──
      final result = await route.handler(validParams);
      _respond(socket, status: 'ok', data: result);
    } catch (e, st) {
      _respond(
        socket,
        status: 'error',
        message: '${e.runtimeType}: $e',
        data: st.toString().split('\n').take(5).toList(),
      );
    }
  }

  void _respond(Socket socket, {
    required String status,
    dynamic data,
    String? message,
  }) {
    final resp = <String, dynamic>{'status': status};
    if (data != null) resp['data'] = data;
    if (message != null) resp['message'] = message;
    try {
      socket.write('${jsonEncode(resp)}\n');
      socket.flush();
    } catch (_) {
      _removeClient(socket);
    }
  }

  void _removeClient(Socket socket) {
    _clients.remove(socket);
    try {
      socket.destroy();
    } catch (_) {}
  }
}
