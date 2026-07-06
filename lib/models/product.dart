class Product {
  int? id;
  String name;
  String sku;
  String productCode;
  int openingStock;
  int currentStock;
  int brandId;
  double sellingPrice;

  Product({
    this.id,
    required this.name,
    required this.sku,
    required this.productCode,
    required this.openingStock,
    required this.currentStock,
    required this.brandId,
    required this.sellingPrice,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'sku': sku,
        'product_code': productCode,
        'opening_stock': openingStock,
        'current_stock': currentStock,
        'brand_id': brandId,
        'selling_price': sellingPrice,
      };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'],
        name: map['name'],
        sku: map['sku'],
        productCode: map['product_code'],
        openingStock: map['opening_stock'],
        currentStock: map['current_stock'],
        brandId: map['brand_id'],
        sellingPrice: (map['selling_price'] as num?)?.toDouble() ?? 0.0,
      );
}
