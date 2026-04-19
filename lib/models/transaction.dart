class Transaction {
  final String id;
  final String merchantName;
  final double totalAmount;
  final DateTime date;
  final String paymentMethod;
  final double? taxAmount;
  final String? imagePath;

  Transaction({
    required this.id,
    required this.merchantName,
    required this.totalAmount,
    required this.date,
    required this.paymentMethod,
    this.taxAmount,
    this.imagePath,
  });

  Transaction copyWith({
    String? id,
    String? merchantName,
    double? totalAmount,
    DateTime? date,
    String? paymentMethod,
    double? taxAmount,
    String? imagePath,
  }) {
    return Transaction(
      id: id ?? this.id,
      merchantName: merchantName ?? this.merchantName,
      totalAmount: totalAmount ?? this.totalAmount,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      taxAmount: taxAmount ?? this.taxAmount,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}
