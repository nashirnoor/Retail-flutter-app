class Expense {
  int? id;
  String description;
  double amount;
  String status; // 'Paid' or 'Unpaid'
  String date;

  Expense({
    this.id,
    required this.description,
    required this.amount,
    this.status = 'Paid',
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'status': status,
      'date': date,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      description: map['description'] as String? ?? 'Unknown',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] as String? ?? 'Paid',
      date: map['date'] as String? ?? '',
    );
  }
}
