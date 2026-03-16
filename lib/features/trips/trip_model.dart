class Trip {
  final int id;
  final String name;
  final String status;
  final String? startTime;

  Trip({
    required this.id,
    required this.name,
    required this.status,
    this.startTime,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'],
      name: json['route']?['name'] ?? 'Trip ${json['id']}',
      status: json['status'] ?? '',
      startTime: json['start_time']?.toString(),
    );
  }
}
