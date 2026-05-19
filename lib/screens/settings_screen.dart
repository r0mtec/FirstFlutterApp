// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';

import '../api/cashdesk_api.dart';
import '../models/cashdesk_models.dart';
import 'common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.api, required this.settings});

  final CashDeskApi api;
  final AppSettings settings;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _serverController;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _serverController = TextEditingController(text: widget.settings.serverUrl);
  }

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  AppSettings _settingsFromForm() {
    var url = _serverController.text.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    return AppSettings(serverUrl: url);
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      await CashDeskApi(_settingsFromForm()).checkConnection();
      showAppSnack(context, 'Подключение доступно');
    } catch (error) {
      showAppSnack(context, userMessage(error, 'Сервер кассы недоступен'));
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  void _save() {
    Navigator.of(context).pop(_settingsFromForm());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _serverController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Адрес CashDeskServer',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _checking ? null : _check,
            icon: _checking
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering),
            label: const Text('Проверить подключение'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}
