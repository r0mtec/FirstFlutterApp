// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';

import '../api/cashdesk_api.dart';
import '../models/cashdesk_models.dart';
import 'common.dart';
import 'receipt_screen.dart';

class SaleCompletedScreen extends StatefulWidget {
  const SaleCompletedScreen({
    super.key,
    required this.api,
    required this.receipt,
  });

  final CashDeskApi api;
  final Receipt receipt;

  @override
  State<SaleCompletedScreen> createState() => _SaleCompletedScreenState();
}

class _SaleCompletedScreenState extends State<SaleCompletedScreen> {
  bool _creating = false;

  Future<void> _newReceipt() async {
    setState(() => _creating = true);
    try {
      final receipt = await widget.api.createReceipt();
      if (!mounted) {
        return;
      }
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => ReceiptScreen(api: widget.api, receipt: receipt),
        ),
        (route) => route.isFirst,
      );
    } catch (error) {
      showAppSnack(context, userMessage(error, 'Сервер кассы недоступен'));
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final receipt = widget.receipt;
    final paymentMethods = receipt.payments
        .map((payment) => _paymentName(payment.paymentType))
        .toSet()
        .join(', ');

    return Scaffold(
      appBar: AppBar(title: const Text('Продажа завершена')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _InfoRow('Номер чека', receipt.localReceiptId),
                  const SizedBox(height: 8),
                  _InfoRow('Итоговая сумма', formatMoney(receipt.finalAmount)),
                  const SizedBox(height: 8),
                  _InfoRow('Оплачено', formatMoney(receipt.paidAmount)),
                  const SizedBox(height: 8),
                  _InfoRow(
                    'Способ оплаты',
                    paymentMethods.isEmpty
                        ? _paymentName(receipt.paymentType)
                        : paymentMethods,
                  ),
                  const SizedBox(height: 8),
                  _InfoRow('Статус продажи', receipt.status),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: _creating ? null : _newReceipt,
                icon: _creating
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: const Text('Новый чек'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                icon: const Icon(Icons.home_outlined),
                label: const Text('На главный экран'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _paymentName(String? paymentType) {
    return switch (paymentType) {
      'Card' => 'Карта',
      'GiftCertificate' => 'Сертификат',
      'Mixed' => 'Карта, сертификат',
      _ => 'Карта',
    };
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ],
    );
  }
}
