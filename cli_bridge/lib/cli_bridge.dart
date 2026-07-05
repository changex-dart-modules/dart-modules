/// 通用 CLI Bridge 框架
///
/// TCP JSON-line 协议中间件，连接 Python 自动化脚本与 Flutter 应用。
/// 提供：
///   - 命令注册 + 路由分发
///   - 参数 schema 声明 + 自动校验
///   - 自动生成接口文档（help 命令）
///   - 错误统一处理 + JSON 响应格式化
library cli_bridge;

export 'src/bridge.dart';
export 'src/param.dart';
