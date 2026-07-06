class PurchasePayment {
  int? id;
  String transactionId;
  double amount;
  String date;

  PurchasePayment({
    this.id,
    required this.transactionId,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'amount': amount,
      'date': date,
    };
  }

  factory PurchasePayment.fromMap(Map<String, dynamic> map) {
    return PurchasePayment(
      id: map['id'],
      transactionId: map['transaction_id'],
      amount: map['amount'],
      date: map['date'],
    );
  }
}
