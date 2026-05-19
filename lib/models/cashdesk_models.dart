class AppSettings {
  const AppSettings({required this.serverUrl});

  static const defaultServerUrl = 'http://10.0.2.2:8083';

  final String serverUrl;

  Uri get serverUri => Uri.parse(serverUrl);

  String get barcodeBaseUrl => serverUri.replace(port: 8091).origin;

  String get scaleBaseUrl => serverUri.replace(port: 8090).origin;
}

class CashierSession {
  CashierSession({
    required this.login,
    required this.displayName,
    required this.role,
  });

  final String login;
  final String displayName;
  final String role;
}

class CashDeskStatus {
  CashDeskStatus({required this.erpAvailable, required this.mode});

  final bool erpAvailable;
  final String mode;

  factory CashDeskStatus.fromJson(Map<String, dynamic> json) {
    return CashDeskStatus(
      erpAvailable: json['erpAvailable'] == true,
      mode: (json['mode'] ?? '').toString(),
    );
  }
}

class Product {
  Product({
    required this.id,
    required this.name,
    required this.price,
    this.barcode,
    this.unit = 'pcs',
  });

  final int id;
  final String name;
  final double price;
  final String? barcode;
  final String unit;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      price: _toDouble(json['price']),
      barcode: json['barcode']?.toString(),
      unit: (json['unit'] ?? 'pcs').toString(),
    );
  }
}

class ReceiptItem {
  ReceiptItem({
    required this.productId,
    required this.quantity,
    required this.price,
    this.productName,
    this.barcode,
  });

  final int productId;
  final double quantity;
  final double price;
  final String? productName;
  final String? barcode;

  double get lineTotal => quantity * price;

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    return ReceiptItem(
      productId: (json['productId'] as num).toInt(),
      quantity: _toDouble(json['quantity']),
      price: _toDouble(json['price']),
      productName: json['productName']?.toString(),
      barcode: json['barcode']?.toString(),
    );
  }
}

class ReceiptPayment {
  ReceiptPayment({
    required this.paymentType,
    required this.amount,
    this.certificateCode,
  });

  final String paymentType;
  final double amount;
  final String? certificateCode;

  factory ReceiptPayment.fromJson(Map<String, dynamic> json) {
    return ReceiptPayment(
      paymentType: (json['paymentType'] ?? '').toString(),
      amount: _toDouble(json['amount']),
      certificateCode: json['certificateCode']?.toString(),
    );
  }
}

class Receipt {
  Receipt({
    required this.localReceiptId,
    required this.status,
    required this.initialAmount,
    required this.finalAmount,
    required this.paidAmount,
    required this.items,
    required this.payments,
    this.paymentType,
  });

  final String localReceiptId;
  final String status;
  final double initialAmount;
  final double finalAmount;
  final double paidAmount;
  final List<ReceiptItem> items;
  final List<ReceiptPayment> payments;
  final String? paymentType;

  double get remainingAmount {
    final remaining = finalAmount - paidAmount;
    return remaining < 0 ? 0 : remaining;
  }

  bool get isReadyForPayment =>
      status == 'ReadyForPayment' ||
      status == 'PartiallyPaid' ||
      status == 'Paid';

  bool get isFullyPaid => remainingAmount <= 0.009 && finalAmount > 0;

  factory Receipt.fromJson(Map<String, dynamic> json) {
    return Receipt(
      localReceiptId: (json['localReceiptId'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      initialAmount: _toDouble(json['initialAmount']),
      finalAmount: _toDouble(json['finalAmount']),
      paidAmount: _toDouble(json['paidAmount']),
      paymentType: json['paymentType']?.toString(),
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ReceiptItem.fromJson)
          .toList(),
      payments: (json['payments'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ReceiptPayment.fromJson)
          .toList(),
    );
  }
}

class CardPaymentSession {
  CardPaymentSession({required this.paymentId, required this.checkoutUrl});

  final String paymentId;
  final String checkoutUrl;

  factory CardPaymentSession.fromJson(Map<String, dynamic> json) {
    return CardPaymentSession(
      paymentId: (json['paymentId'] ?? '').toString(),
      checkoutUrl: (json['checkoutUrl'] ?? json['confirmationUrl'] ?? '')
          .toString(),
    );
  }
}

class CardPaymentStatus {
  CardPaymentStatus({
    required this.status,
    required this.paid,
    required this.message,
    this.receipt,
  });

  final String status;
  final bool paid;
  final String message;
  final Receipt? receipt;

  bool get isFinalFailure =>
      status == 'Failed' ||
      status == 'Canceled' ||
      status == 'Expired' ||
      status == 'AlreadyPaid';

  factory CardPaymentStatus.fromJson(Map<String, dynamic> json) {
    final receiptJson = json['receipt'];
    return CardPaymentStatus(
      status: (json['status'] ?? '').toString(),
      paid: json['paid'] == true,
      message: (json['message'] ?? '').toString(),
      receipt: receiptJson is Map<String, dynamic>
          ? Receipt.fromJson(receiptJson)
          : null,
    );
  }
}

String formatMoney(double value) => '${value.toStringAsFixed(2)} ₽';

String formatQuantity(double value) {
  if ((value - value.roundToDouble()).abs() < 0.0001) {
    return value.toStringAsFixed(0);
  }

  return value.toStringAsFixed(3);
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
