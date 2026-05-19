// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';

import '../api/cashdesk_api.dart';
import '../models/cashdesk_models.dart';
import 'common.dart';

class ScaleScreen extends StatefulWidget {
  const ScaleScreen({
    super.key,
    required this.api,
    required this.receiptId,
    required this.product,
  });

  final CashDeskApi api;
  final String receiptId;
  final Product product;

  @override
  State<ScaleScreen> createState() => _ScaleScreenState();
}

class _ScaleScreenState extends State<ScaleScreen> {
  double? _weight;
  bool _loading = true;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _readWeight();
  }

  Future<void> _readWeight() async {
    setState(() => _loading = true);
    try {
      final weight = await widget.api.readScaleWeight();
      setState(() => _weight = weight);
    } catch (error) {
      showAppSnack(context, userMessage(error, 'Весы недоступны'));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _apply() async {
    final weight = _weight;
    if (weight == null || weight <= 0) {
      showAppSnack(context, 'Весы недоступны');
      return;
    }

    setState(() => _applying = true);
    try {
      final receipt = await widget.api.addItem(
        receiptId: widget.receiptId,
        productId: widget.product.id,
        quantity: weight,
      );
      if (mounted) {
        Navigator.of(context).pop(receipt);
      }
    } catch (error) {
      showAppSnack(context, userMessage(error, 'Весы недоступны'));
    } finally {
      if (mounted) {
        setState(() => _applying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Весы')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.product.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: _loading
                        ? const CircularProgressIndicator()
                        : Text(
                            _weight == null
                                ? 'Вес не получен'
                                : '${formatQuantity(_weight!)} кг',
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: ActionPanel(
        children: [
          OutlinedButton.icon(
            onPressed: _loading || _applying ? null : _readWeight,
            icon: const Icon(Icons.monitor_weight_outlined),
            label: const Text('Получить вес'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _loading || _applying || _weight == null ? null : _apply,
            icon: _applying
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Применить'),
          ),
        ],
      ),
    );
  }
}
