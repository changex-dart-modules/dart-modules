/// 参数定义 — 描述 CLI 命令的入参 schema
///
/// 在注册命令时声明，框架自动做校验 + 补默认值 + 生成文档。
class Param {
  /// 期望的 Dart 类型（用于校验和文档）
  final Type type;

  /// 是否必填（bata 时若缺失则返回错误）
  final bool required;

  /// 缺失时的默认值（仅 required=false 时生效）
  final dynamic defaultValue;

  /// 参数说明（显现在 help 文档中）
  final String? desc;

  const Param._({
    required this.type,
    this.required = false,
    this.defaultValue,
    this.desc,
  });

  // ── 工厂方法 ──────────────────────────────────────

  /// 字符串参数
  factory Param.string({bool required = false, String? desc}) =>
      _StringParam(required: required, desc: desc);

  /// 整数参数
  factory Param.integer({bool required = false, int? defaultValue, String? desc}) =>
      _IntParam(required: required, defaultValue: defaultValue, desc: desc);

  /// 布尔参数
  factory Param.boolean({bool defaultValue = false, String? desc}) =>
      _BoolParam(defaultValue: defaultValue, desc: desc);

  /// 字符串数组参数
  factory Param.stringList({bool required = false, String? desc}) =>
      _StringListParam(required: required, desc: desc);

  /// JSON 对象参数（任意 Map）
  factory Param.object({bool required = false, String? desc}) =>
      _ObjectParam(required: required, desc: desc);

  /// 数值参数（接受 int 或 double）
  factory Param.number({bool required = false, num? defaultValue, String? desc}) =>
      _NumberParam(required: required, defaultValue: defaultValue, desc: desc);
}

class _StringParam extends Param {
  const _StringParam({super.required, super.desc})
      : super._(type: String);
}

class _IntParam extends Param {
  const _IntParam({super.required, super.defaultValue, super.desc})
      : super._(type: int);
}

class _BoolParam extends Param {
  const _BoolParam({super.defaultValue, super.desc})
      : super._(type: bool, required: false);
}

class _StringListParam extends Param {
  const _StringListParam({super.required, super.desc})
      : super._(type: List);
}

class _ObjectParam extends Param {
  const _ObjectParam({super.required, super.desc})
      : super._(type: Map);
}

class _NumberParam extends Param {
  const _NumberParam({super.required, super.defaultValue, super.desc})
      : super._(type: num);
}

// ── 类型校验 ────────────────────────────────────────

/// 判断值是否匹配声明的参数类型
bool typeMatches(dynamic value, Param param) {
  if (value == null) return !param.required;

  if (param.type == String) return value is String;
  if (param.type == int) return value is int;
  if (param.type == double) return value is double || value is int;
  if (param.type == bool) return value is bool;
  if (param.type == List) return value is List;
  if (param.type == num) return value is num;
  if (param.type == Map) return value is Map;

  return true; // 未知类型放行
}

/// 参数类型的可读名称
String typeName(Param param) {
  if (param.type == String) return 'String';
  if (param.type == int) return 'int';
  if (param.type == num) return 'int | double';
  if (param.type == bool) return 'bool';
  if (param.type == List) return 'List<String>';
  if (param.type == Map) return 'Object';
  return param.type.toString();
}
