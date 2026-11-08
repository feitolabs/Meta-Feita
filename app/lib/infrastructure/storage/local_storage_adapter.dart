import 'package:localstorage/localstorage.dart';

abstract class LocalStorageAdapter {
  Future<void> init();
  String? getItem(String key);
  void setItem(String key, String value);
  void removeItem(String key);
  void clear();
}

class FlutterLocalStorageAdapter implements LocalStorageAdapter {
  bool _initialized = false;

  @override
  Future<void> init() async {
    if (_initialized) return;
    await initLocalStorage();
    _initialized = true;
  }

  @override
  String? getItem(String key) => localStorage.getItem(key);

  @override
  void setItem(String key, String value) => localStorage.setItem(key, value);

  @override
  void removeItem(String key) => localStorage.removeItem(key);

  @override
  void clear() => localStorage.clear();
}

class InMemoryLocalStorageAdapter implements LocalStorageAdapter {
  final Map<String, String> _store = {};

  @override
  Future<void> init() async {}

  @override
  String? getItem(String key) => _store[key];

  @override
  void setItem(String key, String value) {
    _store[key] = value;
  }

  @override
  void removeItem(String key) {
    _store.remove(key);
  }

  @override
  void clear() {
    _store.clear();
  }
}

