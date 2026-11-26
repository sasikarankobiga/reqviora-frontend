// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

/// Session storage persists through refresh in the same tab.
String? read(String key) {
  return html.window.sessionStorage[key];
}

void write(String key, String value) {
  html.window.sessionStorage[key] = value;
}

void remove(String key) {
  html.window.sessionStorage.remove(key);
}
