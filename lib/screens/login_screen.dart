// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';

import '../api/cashdesk_api.dart';
import '../models/cashdesk_models.dart';
import 'common.dart';
import 'settings_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.api,
    required this.settings,
    required this.onLogin,
    required this.onSettingsChanged,
  });

  final CashDeskApi api;
  final AppSettings settings;
  final ValueChanged<CashierSession> onLogin;
  final ValueChanged<AppSettings> onSettingsChanged;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final session = await widget.api.login(
        _loginController.text.trim(),
        _passwordController.text,
      );
      widget.onLogin(session);
    } catch (error) {
      showAppSnack(context, userMessage(error, 'Не удалось авторизоваться'));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openSettings() async {
    final changed = await Navigator.of(context).push<AppSettings>(
      MaterialPageRoute(
        builder: (_) =>
            SettingsScreen(api: widget.api, settings: widget.settings),
      ),
    );
    if (changed != null) {
      widget.onSettingsChanged(changed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Вход кассира'),
        actions: [
          IconButton(
            tooltip: 'Настройки',
            onPressed: _loading ? null : _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _loginController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Логин',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            onSubmitted: (_) => _loading ? null : _login(),
            decoration: const InputDecoration(
              labelText: 'Пароль',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _login,
            icon: _loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: const Text('Войти'),
          ),
        ],
      ),
    );
  }
}
