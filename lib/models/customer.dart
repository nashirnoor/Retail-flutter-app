class Customer {
  int? id;
  String name;
  String contact;
  String address;
  String company;

  Customer({
    this.id,
    required this.name,
    required this.contact,
    required this.address,
    this.company = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'contact': contact,
      'address': address,
      'company': company,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'],
      name: map['name'] ?? '',
      contact: map['contact'] ?? '',
      address: map['address'] ?? '',
      company: map['company'] ?? '',
    );
  }
}
