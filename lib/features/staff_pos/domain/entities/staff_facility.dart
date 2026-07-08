class StaffFacility {
  const StaffFacility({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory StaffFacility.fromJson(Map<String, dynamic> json) {
    return StaffFacility(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}
