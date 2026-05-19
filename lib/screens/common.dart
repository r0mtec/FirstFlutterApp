import 'package:flutter/material.dart';

import '../api/cashdesk_api.dart';

void showAppSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String userMessage(Object error, String fallback) {
  if (error is CashDeskApiException) {
    final message = error.message;
    if (message.contains('ERP')) {
      return 'ERP недоступна. Проведение продаж невозможно';
    }
    if (message.contains('Сертификат') && message.contains('использ')) {
      return 'Сертификат уже использован';
    }
    if (message.contains('Сертификат')) {
      return 'Сертификат не найден';
    }
    if (message.contains('Штрихкод')) {
      return 'Штрихкод не распознан';
    }
    if (message.contains('Товар')) {
      return 'Товар не найден';
    }

    return message;
  }

  return fallback;
}

class ActionPanel extends StatelessWidget {
  const ActionPanel({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}
