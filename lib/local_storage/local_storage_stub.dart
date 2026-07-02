class LocalKeyValueStore {
  final Map<String, String> _memory = <String, String>{};

  String? read(String key) => _memory[key];

  void write(String key, String value) {
    _memory[key] = value;
  }

  void delete(String key) {
    _memory.remove(key);
  }
}
