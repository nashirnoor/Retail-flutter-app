class Supplier {
  int? id;
  String name;
  String contact;
  String address;

  Supplier({
    this.id,
    required this.name,
    required this.contact,
    required this.address,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'contact': contact,
        'address': address,
      };

  factory Supplier.fromMap(Map<String, dynamic> map) => Supplier(
        id: map['id'],
        name: map['name'] ?? '',
        contact: map['contact'] ?? '',
        address: map['address'] ?? '',
      );
}
