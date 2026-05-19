import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/cashdesk_models.dart';

class CashDeskApiException implements Exception {
  CashDeskApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CashDeskApi {
  CashDeskApi(this.settings);

  AppSettings settings;
  final http.Client _client = http.Client();

  Future<CashierSession> login(String login, String password) async {
    try {
      final json = await _postJson('/api/auth/login-cashier', {
        'login': login,
        'password': password,
      });
      await _postJson('/api/workstation/ensure', {
        "workstationCode": "WS-TEST-02",
        "machineName": "mobile",
        "clientType": "mobile"
      });

      return CashierSession(
        login: login,
        displayName: (json['displayName'] ?? login).toString(),
        role: (json['role'] ?? '').toString(),
      );
    } on CashDeskApiException {
      rethrow;
    } catch (_) {
      throw CashDeskApiException('Не удалось авторизоваться');
    }
  }

  Future<CashDeskStatus> getStatus() async {
    final json = await _getJson('/api/cash/status');
    return CashDeskStatus.fromJson(json);
  }

  Future<void> checkConnection() async {
    await getStatus();
  }

  Future<void> ensureShift() async {
    final current = await _request('GET', '/api/shifts/current');
    if (current.statusCode == 404) {
      await _postJson('/api/shifts/open', {});
      return;
    }

    _ensureSuccess(current);
  }

  Future<Receipt> createReceipt() async {
    await ensureShift();
    final json = await _postJson('/api/cash/receipts/draft', {});
    final receipt = json['receipt'];
    if (receipt is Map<String, dynamic>) {
      return Receipt.fromJson(receipt);
    }

    throw CashDeskApiException('Сервер кассы недоступен');
  }

  Future<Product> getProductByBarcode(String barcode) async {
    try {
      final json = await _getJson('/api/cash/products/by-barcode/$barcode');
      return Product.fromJson(json);
    } on CashDeskApiException {
      throw CashDeskApiException('Товар не найден');
    }
  }

  Future<Receipt> addItem({
    required String receiptId,
    required int productId,
    required double quantity,
  }) async {
    final json = await _postJson('/api/cash/receipts/$receiptId/items', {
      'productId': productId,
      'quantity': quantity,
    });
    return Receipt.fromJson(json);
  }

  Future<Receipt> deleteItem({
    required String receiptId,
    required int productId,
  }) async {
    final response = await _request(
      'DELETE',
      '/api/cash/receipts/$receiptId/items/$productId',
    );
    _ensureSuccess(response);
    return Receipt.fromJson(_decodeObject(response.body));
  }

  Future<Receipt> calculateWithoutLoyalty(String receiptId) async {
    final json = await _postJson(
      '/api/cash/receipts/$receiptId/calculate-no-loyalty',
      {},
    );
    final receipt = json['receipt'];
    if (receipt is Map<String, dynamic>) {
      return Receipt.fromJson(receipt);
    }

    throw CashDeskApiException('Сервер кассы недоступен');
  }

  Future<CardPaymentSession> createCardPayment(
    String receiptId,
    double amount,
  ) async {
    final json = await _postJson(
      '/api/cash/receipts/$receiptId/payments/card/create',
      {'amount': amount},
    );
    final session = CardPaymentSession.fromJson(json);
    if (session.checkoutUrl.isEmpty) {
      throw CashDeskApiException('Платёж картой не завершён');
    }

    return session;
  }

  Future<CardPaymentStatus> getCardPaymentStatus(String paymentId) async {
    final json = await _getJson('/api/cash/payments/$paymentId/status');
    return CardPaymentStatus.fromJson(json);
  }

  Future<Receipt> payByCertificate({
    required String receiptId,
    required double amount,
    required String code,
  }) async {
    final json = await _postJson('/api/cash/receipts/$receiptId/pay', {
      'localReceiptId': receiptId,
      'paymentType': 'GiftCertificate',
      'amount': amount,
      'certificateCode': code,
    });
    final receipt = json['receipt'];
    if (receipt is Map<String, dynamic>) {
      return Receipt.fromJson(receipt);
    }

    throw CashDeskApiException('Сертификат не найден');
  }

  Future<Receipt> confirmReceipt(String receiptId) async {
    final json = await _postJson('/api/cash/receipts/$receiptId/confirm', {});
    final receipt = json['receipt'] ?? json['Receipt'];
    if (receipt is Map<String, dynamic>) {
      return Receipt.fromJson(receipt);
    }

    throw CashDeskApiException('Не удалось подтвердить чек');
  }

  Future<String> recognizeBarcode(File image) async {
    final uri = Uri.parse('${settings.barcodeBaseUrl}/api/barcode/recognize');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', image.path));

    try {
      final streamed = await request.send().timeout(
        const Duration(seconds: 20),
      );
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CashDeskApiException('Штрихкод не распознан');
      }

      final json = _decodeObject(response.body);
      final success = json['success'] == true;
      final barcode = json['barcode']?.toString();
      if (!success || barcode == null || barcode.isEmpty) {
        throw CashDeskApiException('Штрихкод не распознан');
      }

      return barcode;
    } on CashDeskApiException {
      rethrow;
    } catch (_) {
      throw CashDeskApiException('Штрихкод не распознан');
    }
  }

  Future<double> readScaleWeight() async {
    try {
      final response = await _client
          .get(Uri.parse('${settings.scaleBaseUrl}/api/scale/weight'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CashDeskApiException('Весы недоступны');
      }

      final json = _decodeObject(response.body);
      if (json['success'] != true || json['weight'] == null) {
        throw CashDeskApiException('Весы недоступны');
      }

      return _toDouble(json['weight']);
    } on CashDeskApiException {
      rethrow;
    } catch (_) {
      throw CashDeskApiException('Весы недоступны');
    }
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final response = await _request('GET', path);
    _ensureSuccess(response);
    return _decodeObject(response.body);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _request('POST', path, body: body);
    _ensureSuccess(response);
    return _decodeObject(response.body);
  }

  Future<http.Response> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('${settings.serverUrl}$path');
    final headers = {'Content-Type': 'application/json'};

    try {
      final future = switch (method) {
        'GET' => _client.get(uri, headers: headers),
        'POST' => _client.post(
          uri,
          headers: headers,
          body: jsonEncode(body ?? const {}),
        ),
        'DELETE' => _client.delete(uri, headers: headers),
        _ => throw UnsupportedError(method),
      };

      return await future.timeout(const Duration(seconds: 20));
    } on CashDeskApiException {
      rethrow;
    } catch (_) {
      throw CashDeskApiException('Сервер кассы недоступен');
    }
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final error = _extractError(response.body);
    if (response.statusCode == 503 && error.contains('ERP')) {
      throw CashDeskApiException(
        'ERP недоступна. Проведение продаж невозможно',
      );
    }

    throw CashDeskApiException(error);
  }

  static Map<String, dynamic> _decodeObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return <String, dynamic>{};
  }

  static String _extractError(String body) {
    try {
      final json = _decodeObject(body);
      final value = json['error'] ?? json['message'] ?? json['details'];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    } catch (_) {
      // Fall through to the generic message.
    }

    return 'Сервер кассы недоступен';
  }
}

double _toDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }

  if (value is String) {
    return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  }

  return 0;
}
