// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';

import '../api/cashdesk_api.dart';
import '../api/native_bridge.dart';
import '../models/cashdesk_models.dart';
import 'common.dart';
import 'payment_screen.dart';
import 'scale_screen.dart';

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, required this.api, required this.receipt});

  final CashDeskApi api;
  final Receipt receipt;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  late Receipt _receipt;
  final _nativeBridge = NativeBridge();
  bool _busy = false;
  String? _calculationMessage;

  @override
  void initState() {
    super.initState();
    _receipt = widget.receipt;
  }

  Future<void> _recognizeBarcode() async {
    setState(() => _busy = true);
    try {
      final imagePath = await _nativeBridge.pickImagePath();
      if (imagePath == null) {
        return;
      }

      final barcode = await widget.api.recognizeBarcode(File(imagePath));
      final product = await widget.api.getProductByBarcode(barcode);
      if (!mounted) {
        return;
      }

      final needScale = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Нужно взвесить товар?'),
          content: Text(product.name),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Нет'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Да'),
            ),
          ],
        ),
      );

      if (needScale == true) {
        final updated = await Navigator.of(context).push<Receipt>(
          MaterialPageRoute(
            builder: (_) => ScaleScreen(
              api: widget.api,
              receiptId: _receipt.localReceiptId,
              product: product,
            ),
          ),
        );
        if (updated != null) {
          setState(() {
            _receipt = updated;
            _calculationMessage = null;
          });
        }
      } else {
        final updated = await widget.api.addItem(
          receiptId: _receipt.localReceiptId,
          productId: product.id,
          quantity: 1,
        );
        setState(() {
          _receipt = updated;
          _calculationMessage = null;
        });
      }
    } catch (error) {
      showAppSnack(context, userMessage(error, 'Штрихкод не распознан'));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteItem(ReceiptItem item) async {
    setState(() => _busy = true);
    try {
      final updated = await widget.api.deleteItem(
        receiptId: _receipt.localReceiptId,
        productId: item.productId,
      );
      setState(() {
        _receipt = updated;
        _calculationMessage = null;
      });
    } catch (error) {
      showAppSnack(context, userMessage(error, 'Товар не найден'));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _calculate() async {
    setState(() => _busy = true);
    try {
      final updated = await widget.api.calculateWithoutLoyalty(
        _receipt.localReceiptId,
      );
      setState(() {
        _receipt = updated;
        _calculationMessage = 'Чек рассчитан без лояльности.';
      });
    } catch (error) {
      showAppSnack(
        context,
        userMessage(error, 'ERP недоступна. Проведение продаж невозможно'),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openPayment() async {
    final paidReceipt = await Navigator.of(context).push<Receipt>(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(api: widget.api, receipt: _receipt),
      ),
    );
    if (paidReceipt != null) {
      setState(() => _receipt = paidReceipt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCalculate = _receipt.items.isNotEmpty && !_busy;
    final canPay = _receipt.isReadyForPayment && !_busy;

    return Scaffold(
      appBar: AppBar(title: const Text('Чек')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _TotalsCard(receipt: _receipt),
          if (_calculationMessage != null) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(_calculationMessage!),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text('Позиции', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_receipt.items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Добавьте товар распознаванием штрихкода с фото.'),
              ),
            )
          else
            ..._receipt.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    title: Text(item.productName ?? 'Товар ${item.productId}'),
                    subtitle: Text(
                      '${formatQuantity(item.quantity)} × ${formatMoney(item.price)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(formatMoney(item.lineTotal)),
                        IconButton(
                          tooltip: 'Удалить',
                          onPressed: _busy ? null : () => _deleteItem(item),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: ActionPanel(
        children: [
          OutlinedButton.icon(
            onPressed: _busy ? null : _recognizeBarcode,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Распознать штрихкод с фото'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: canCalculate ? _calculate : null,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.calculate_outlined),
            label: const Text('Рассчитать без лояльности'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: canPay ? _openPayment : null,
            icon: const Icon(Icons.credit_card),
            label: const Text('Перейти к оплате'),
          ),
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.receipt});

  final Receipt receipt;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AmountRow('Сумма', formatMoney(receipt.initialAmount)),
            const SizedBox(height: 8),
            _AmountRow('Итого', formatMoney(receipt.finalAmount)),
            const SizedBox(height: 8),
            _AmountRow('Оплачено', formatMoney(receipt.paidAmount)),
            const Divider(height: 24),
            _AmountRow('Остаток', formatMoney(receipt.remainingAmount)),
          ],
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
