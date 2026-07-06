class Brand {
  int? id;
  String name;

  Brand({this.id, required this.name});

  Map<String, dynamic> toMap() => {'id': id, 'name': name};

  factory Brand.fromMap(Map<String, dynamic> map) =>
      Brand(id: map['id'], name: map['name']);
}
