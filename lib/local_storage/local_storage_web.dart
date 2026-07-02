// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

class LocalKeyValueStore {
  String? read(String key) => html.window.localStorage[key];

  void write(String key, String value) {
    html.window.localStorage[key] = value;
  }

  void delete(String key) {
    html.window.localStorage.remove(key);
  }
}
