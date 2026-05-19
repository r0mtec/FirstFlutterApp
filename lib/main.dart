import 'package:flutter/material.dart';

import 'api/cashdesk_api.dart';
import 'api/settings_store.dart';
import 'models/cashdesk_models.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const CashDeskApp());
}

class CashDeskApp extends StatefulWidget {
  const CashDeskApp({super.key, this.initialSettings});

  final AppSettings? initialSettings;

  @override
  State<CashDeskApp> createState() => _CashDeskAppState();
}

class _CashDeskAppState extends State<CashDeskApp> {
  final _store = SettingsStore();
  AppSettings? _settings;
  CashDeskApi? _api;
  CashierSession? _session;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = widget.initialSettings ?? await _store.loadSettings();
    final session = await _store.loadSession();
    setState(() {
      _settings = settings;
      _api = CashDeskApi(settings);
      _session = session;
      _loading = false;
    });
  }

  Future<void> _setSettings(AppSettings settings) async {
    await _store.saveSettings(settings);
    setState(() {
      _settings = settings;
      _api = CashDeskApi(settings);
    });
  }

  Future<void> _setSession(CashierSession session) async {
    await _store.saveSession(session);
    setState(() => _session = session);
  }

  Future<void> _logout() async {
    await _store.clearSession();
    setState(() => _session = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Мобильная касса',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F7A5A)),
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        cardTheme: const CardThemeData(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_loading || _settings == null || _api == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final api = _api!;
    final settings = _settings!;
    final session = _session;

    if (session == null) {
      return LoginScreen(
        api: api,
        settings: settings,
        onLogin: _setSession,
        onSettingsChanged: _setSettings,
      );
    }

    return HomeScreen(
      api: api,
      settings: settings,
      session: session,
      onLogout: _logout,
      onSettingsChanged: _setSettings,
    );
  }
}
