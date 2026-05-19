// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';

import '../api/cashdesk_api.dart';
import '../models/cashdesk_models.dart';
import 'common.dart';
import 'receipt_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.api,
    required this.settings,
    required this.session,
    required this.onLogout,
    required this.onSettingsChanged,
  });

  final CashDeskApi api;
  final AppSettings settings;
  final CashierSession session;
  final VoidCallback onLogout;
  final ValueChanged<AppSettings> onSettingsChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CashDeskStatus? _status;
  bool _loading = true;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    setState(() => _loading = true);
    try {
      final status = await widget.api.getStatus();
      setState(() => _status = status);
    } catch (error) {
      setState(() => _status = CashDeskStatus(erpAvailable: false, mode: ''));
      showAppSnack(context, userMessage(error, 'Сервер кассы недоступен'));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createReceipt() async {
    setState(() => _creating = true);
    try {
      final status = await widget.api.getStatus();
      if (!status.erpAvailable) {
        setState(() => _status = status);
        showAppSnack(context, 'ERP недоступна. Проведение продаж невозможно');
        return;
      }

      final receipt = await widget.api.createReceipt();
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReceiptScreen(api: widget.api, receipt: receipt),
        ),
      );
      await _refreshStatus();
    } catch (error) {
      showAppSnack(context, userMessage(error, 'Сервер кассы недоступен'));
    } finally {
      if (mounted) {
        setState(() => _creating = false);
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
    final erpAvailable = _status?.erpAvailable == true;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мобильная касса'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: _loading ? null : _refreshStatus,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Настройки',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'Выйти',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshStatus,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.session.displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.settings.serverUrl,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Icon(
                  erpAvailable
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  color: erpAvailable ? Colors.green : Colors.red,
                ),
                title: Text(erpAvailable ? 'ERP доступна' : 'ERP недоступна'),
                subtitle: !erpAvailable
                    ? const Text(
                        'ERP недоступна. Проведение продаж невозможно.',
                      )
                    : const Text('Продажи разрешены'),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: erpAvailable && !_loading && !_creating
                  ? _createReceipt
                  : null,
              icon: _creating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.receipt_long_outlined),
              label: const Text('Новый чек'),
            ),
          ],
        ),
      ),
    );
  }
}
