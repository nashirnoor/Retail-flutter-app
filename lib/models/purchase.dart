class Purchase {
  int? id;
  int productId;
  int supplierId;
  int quantity;
  double price;
  String date;
  String? transactionId;
  String status; // 'Ordered' or 'Received'
  double commission; // 0.0 by default
  String paymentStatus; // 'Paid', 'Partially Paid', 'Unpaid'
  String? dueDate;
  double paidAmount;

  // Joined fields for display
  String? productName;
  String? supplierName;
  String? productCode;
  String? brandName;

  Purchase({
    this.id,
    required this.productId,
    required this.supplierId,
    required this.quantity,
    required this.price,
    required this.date,
    this.status = 'Received',
    this.commission = 0.0,
    this.paymentStatus = 'Paid',
    this.dueDate,
    this.paidAmount = 0.0,
    this.transactionId,
    this.productName,
    this.supplierName,
    this.productCode,
    this.brandName,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'product_id': productId,
        'supplier_id': supplierId,
        'quantity': quantity,
        'price': price,
        'date': date,
        'transaction_id': transactionId,
        'status': status,
        'commission': commission,
        'payment_status': paymentStatus,
        'due_date': dueDate,
        'paid_amount': paidAmount,
      };

  factory Purchase.fromMap(Map<String, dynamic> map) => Purchase(
        id: map['id'] as int?,
        productId: map['product_id'] as int? ?? 0,
        supplierId: map['supplier_id'] as int? ?? 0,
        quantity: map['quantity'] as int? ?? 0,
        price: (map['price'] as num?)?.toDouble() ?? 0.0,
        date: map['date'] as String? ?? '',
        transactionId: map['transaction_id'] as String?,
        status: map['status'] as String? ?? 'Received',
        commission: (map['commission'] as num?)?.toDouble() ?? 0.0,
        paymentStatus: map['payment_status'] as String? ?? 'Paid',
        dueDate: map['due_date'] as String?,
        paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0.0,
        productName: map['product_name'] as String?,
        supplierName: map['supplier_name'] as String?,
        productCode: map['product_code'] as String?,
        brandName: map['brand_name'] as String?,
      );
}
