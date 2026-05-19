// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/cashdesk_api.dart';
import '../models/cashdesk_models.dart';
import 'common.dart';
import 'sale_completed_screen.dart';

enum _PaymentMethod { card, certificate }

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.api, required this.receipt});

  final CashDeskApi api;
  final Receipt receipt;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late Receipt _receipt;
  final _certificateController = TextEditingController();
  _PaymentMethod _method = _PaymentMethod.card;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _receipt = widget.receipt;
  }

  @override
  void dispose() {
    _certificateController.dispose();
    super.dispose();
  }

  Future<void> _payByCard() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final session = await widget.api.createCardPayment(
        _receipt.localReceiptId,
        _receipt.remainingAmount,
      );
      final url = Uri.parse(session.checkoutUrl);
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw CashDeskApiException('Платёж картой не завершён');
      }

      for (var attempt = 0; attempt < 30; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 3));
        final status = await widget.api.getCardPaymentStatus(session.paymentId);
        if (status.receipt != null) {
          setState(() => _receipt = status.receipt!);
        }
        if (status.paid) {
          setState(() => _message = 'Оплата картой прошла успешно');
          return;
        }
        if (status.isFinalFailure) {
          throw CashDeskApiException('Платёж картой не завершён');
        }
      }

      throw CashDeskApiException('Платёж картой не завершён');
    } catch (error) {
      setState(
        () => _message =
            '${userMessage(error, 'Платёж картой не завершён')}. Можно выбрать другой способ оплаты',
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _payByCertificate() async {
    final code = _certificateController.text.trim();
    if (code.isEmpty) {
      showAppSnack(context, 'Введите код сертификата');
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final updated = await widget.api.payByCertificate(
        receiptId: _receipt.localReceiptId,
        amount: _receipt.remainingAmount,
        code: code,
      );
      setState(() {
        _receipt = updated;
        _certificateController.clear();
        _message = updated.remainingAmount > 0
            ? 'Оплата сертификатом прошла успешно. Остаток можно оплатить картой или другим сертификатом'
            : 'Оплата сертификатом прошла успешно';
      });
    } catch (error) {
      showAppSnack(context, userMessage(error, 'Сертификат не найден'));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _confirm() async {
    if (!_receipt.isFullyPaid) {
      showAppSnack(context, 'Чек не оплачен полностью');
      return;
    }

    setState(() => _busy = true);
    try {
      final confirmed = await widget.api.confirmReceipt(
        _receipt.localReceiptId,
      );
      if (!mounted) {
        return;
      }
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              SaleCompletedScreen(api: widget.api, receipt: confirmed),
        ),
      );
    } catch (error) {
      showAppSnack(context, userMessage(error, 'Не удалось подтвердить чек'));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCard = _method == _PaymentMethod.card;
    return Scaffold(
      appBar: AppBar(title: const Text('Оплата')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PaymentSummary(receipt: _receipt),
          const SizedBox(height: 16),
          SegmentedButton<_PaymentMethod>(
            segments: const [
              ButtonSegment(
                value: _PaymentMethod.card,
                icon: Icon(Icons.credit_card),
                label: Text('Карта'),
              ),
              ButtonSegment(
                value: _PaymentMethod.certificate,
                icon: Icon(Icons.card_giftcard),
                label: Text('Сертификат'),
              ),
            ],
            selected: {_method},
            onSelectionChanged: _busy
                ? null
                : (value) => setState(() => _method = value.first),
          ),
          const SizedBox(height: 16),
          if (_message != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(_message!),
              ),
            ),
          if (!isCard) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _certificateController,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Код сертификата',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: ActionPanel(
        children: [
          if (isCard)
            FilledButton.icon(
              onPressed: _busy || _receipt.remainingAmount <= 0
                  ? null
                  : _payByCard,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.credit_card),
              label: const Text('Оплатить картой'),
            )
          else
            FilledButton.icon(
              onPressed: _busy || _receipt.remainingAmount <= 0
                  ? null
                  : _payByCertificate,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.card_giftcard),
              label: const Text('Оплатить сертификатом'),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy || !_receipt.isFullyPaid ? null : _confirm,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Подтвердить чек'),
          ),
        ],
      ),
    );
  }
}

class _PaymentSummary extends StatelessWidget {
  const _PaymentSummary({required this.receipt});

  final Receipt receipt;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
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
