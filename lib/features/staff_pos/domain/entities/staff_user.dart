class StaffUser {
  const StaffUser({
    required this.id,
    required this.username,
    required this.role,
    this.firstName,
    this.lastName,
  });

  final String id;
  final String username;
  final String role;
  final String? firstName;
  final String? lastName;

  factory StaffUser.fromJson(Map<String, dynamic> json) {
    return StaffUser(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      role: json['role']?.toString() ?? 'STAFF',
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
    );
  }
}

