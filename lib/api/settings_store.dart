import '../models/cashdesk_models.dart';
import 'native_bridge.dart';

class SettingsStore {
  SettingsStore({NativeBridge? bridge}) : _bridge = bridge ?? NativeBridge();

  static const _serverUrlKey = 'cashDeskServerUrl';
  static const _loginKey = 'cashierLogin';
  static const _displayNameKey = 'cashierDisplayName';
  static const _roleKey = 'cashierRole';

  final NativeBridge _bridge;

  Future<AppSettings> loadSettings() async {
    final serverUrl = await _bridge.getString(_serverUrlKey);
    return AppSettings(
      serverUrl: _normalizeServerUrl(
        serverUrl == null || serverUrl.isEmpty
            ? AppSettings.defaultServerUrl
            : serverUrl,
      ),
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _bridge.setString(
      _serverUrlKey,
      _normalizeServerUrl(settings.serverUrl),
    );
  }

  Future<CashierSession?> loadSession() async {
    final login = await _bridge.getString(_loginKey);
    if (login == null || login.isEmpty) {
      return null;
    }

    return CashierSession(
      login: login,
      displayName: await _bridge.getString(_displayNameKey) ?? login,
      role: await _bridge.getString(_roleKey) ?? '',
    );
  }

  Future<void> saveSession(CashierSession session) async {
    await _bridge.setString(_loginKey, session.login);
    await _bridge.setString(_displayNameKey, session.displayName);
    await _bridge.setString(_roleKey, session.role);
  }

  Future<void> clearSession() async {
    await _bridge.remove(_loginKey);
    await _bridge.remove(_displayNameKey);
    await _bridge.remove(_roleKey);
  }

  String _normalizeServerUrl(String value) {
    var url = value.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }

    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }
}
