/// OpenAI-compatible 工具参数支持的基础类型。
enum AiToolParameterType {
  string('string'),
  number('number'),
  integer('integer'),
  boolean('boolean');

  const AiToolParameterType(this.jsonName);

  final String jsonName;
}

/// 单个工具参数的声明。
///
/// 这是原生 JSON Schema、兼容协议提示词和本地参数检查的共同数据源。
class AiToolParameter {
  const AiToolParameter({
    required this.type,
    required this.description,
    this.enumValues = const <Object>[],
    this.minimum,
    this.maximum,
  });

  final AiToolParameterType type;
  final String description;
  final List<Object> enumValues;
  final num? minimum;
  final num? maximum;

  Map<String, Object?> toJsonSchema() => <String, Object?>{
    'type': type.jsonName,
    'description': description,
    if (enumValues.isNotEmpty) 'enum': enumValues,
    if (minimum != null) 'minimum': minimum,
    if (maximum != null) 'maximum': maximum,
  };

  /// 对模型返回值做无副作用的基础类型检查。
  bool accepts(Object? value) {
    if (value == null) return false;
    final typeMatches = switch (type) {
      AiToolParameterType.string => value is String,
      AiToolParameterType.number => value is num,
      AiToolParameterType.integer => value is int,
      AiToolParameterType.boolean => value is bool,
    };
    if (!typeMatches) return false;
    if (enumValues.isNotEmpty && !enumValues.contains(value)) return false;
    if (value is num && minimum != null && value < minimum!) return false;
    if (value is num && maximum != null && value > maximum!) return false;
    return true;
  }
}

/// 一个工具的参数对象 Schema。
class AiToolSchema {
  const AiToolSchema({
    this.properties = const <String, AiToolParameter>{},
    this.required = const <String>{},
  });

  final Map<String, AiToolParameter> properties;
  final Set<String> required;

  Map<String, Object?> toJsonSchema() => <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{
      for (final entry in properties.entries)
        entry.key: entry.value.toJsonSchema(),
    },
    if (required.isNotEmpty) 'required': required.toList(growable: false),
    'additionalProperties': false,
  };

  /// 生成兼容提示词协议使用的紧凑参数说明。
  String get promptDescription => properties.entries
      .map((entry) => '${entry.key}：${entry.value.description}')
      .join('；');

  /// 返回模型参数中的基础错误。工具仍须自行处理缺省和领域降级。
  List<String> validate(Map<String, Object?> arguments) {
    final errors = <String>[];
    for (final name in required) {
      if (!arguments.containsKey(name)) errors.add('$name is required');
    }
    for (final entry in arguments.entries) {
      final parameter = properties[entry.key];
      if (parameter == null) {
        errors.add('${entry.key} is not allowed');
      } else if (!parameter.accepts(entry.value)) {
        errors.add('${entry.key} has an invalid value');
      }
    }
    return errors;
  }
}
