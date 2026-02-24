class Trip {
  final int id;
  final String name;

  Trip({required this.id, required this.name});

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(id: json['id'], name: json['name'] ?? 'Trip ${json['id']}');
  }
}
