class SalePayment {
  int? id;
  String transactionId;
  double amount;
  String date;

  SalePayment({
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

  factory SalePayment.fromMap(Map<String, dynamic> map) {
    return SalePayment(
      id: map['id'],
      transactionId: map['transaction_id'],
      amount: map['amount'],
      date: map['date'],
    );
  }
}
