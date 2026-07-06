class Sale {
  int? id;
  int productId;
  int quantity;
  double price;
  String date;
  String? transactionId;
  int? customerId;
  String status; // 'Paid', 'Unpaid', or 'Partially Paid'
  String? dueDate;
  double paidAmount;

  // Joined field for display
  String? productName;
  String? customerName;
  String? customerContact;
  String? customerAddress;
  String? customerCompany;
  String? productCode;
  String? brandName;

  Sale({
    this.id,
    required this.productId,
    required this.quantity,
    required this.price,
    required this.date,
    this.transactionId,
    this.customerId,
    this.status = 'Paid',
    this.dueDate,
    this.paidAmount = 0.0,
    this.productName,
    this.customerName,
    this.customerContact,
    this.customerAddress,
    this.customerCompany,
    this.productCode,
    this.brandName,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'product_id': productId,
        'quantity': quantity,
        'price': price,
        'date': date,
        'transaction_id': transactionId,
        'customer_id': customerId,
        'status': status,
        'due_date': dueDate,
        'paid_amount': paidAmount,
      };

  factory Sale.fromMap(Map<String, dynamic> map) => Sale(
        id: map['id'] as int?,
        productId: map['product_id'] as int? ?? 0,
        quantity: map['quantity'] as int? ?? 0,
        price: (map['price'] as num?)?.toDouble() ?? 0.0,
        date: map['date'] as String? ?? '',
        transactionId: map['transaction_id'] as String?,
        customerId: map['customer_id'] as int?,
        status: map['status'] as String? ?? 'Paid',
        dueDate: map['due_date'] as String?,
        paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0.0,
        productName: map['product_name'] as String?,
        customerName: map['customer_name'] as String?,
        customerContact: map['customer_contact'] as String?,
        customerAddress: map['customer_address'] as String?,
        customerCompany: map['customer_company'] as String?,
        productCode: map['product_code'] as String?,
        brandName: map['brand_name'] as String?,
      );
}
