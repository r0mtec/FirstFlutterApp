import 'package:flutter/services.dart';

class NativeBridge {
  static const _channel = MethodChannel('cashdesk_mobile/native');
  static final Map<String, String> _memory = {};

  Future<String?> pickImagePath() async {
    final path = await _channel.invokeMethod<String>('pickImage');
    if (path == null || path.isEmpty) {
      return null;
    }

    return path;
  }

  Future<String?> getString(String key) async {
    try {
      return await _channel.invokeMethod<String>('getString', {'key': key});
    } on MissingPluginException {
      return _memory[key];
    }
  }

  Future<void> setString(String key, String value) async {
    try {
      await _channel.invokeMethod<void>('setString', {
        'key': key,
        'value': value,
      });
    } on MissingPluginException {
      _memory[key] = value;
    }
  }

  Future<void> remove(String key) async {
    try {
      await _channel.invokeMethod<void>('remove', {'key': key});
    } on MissingPluginException {
      _memory.remove(key);
    }
  }
}
