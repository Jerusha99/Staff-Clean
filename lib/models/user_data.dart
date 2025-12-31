class AppUserData {
  final String uid;
  final String email;
  final String role;
  final String? name;
  final String? phone;
  final String? address;
  final String? profileImageUrl;

  AppUserData({
    required this.uid,
    required this.email,
    required this.role,
    this.name,
    this.phone,
    this.address,
    this.profileImageUrl,
  });

  factory AppUserData.fromMap(String uid, Map<dynamic, dynamic> data) {
    return AppUserData(
      uid: uid,
      email: data['email'] ?? '',
      role: data['role'] ?? 'staff',
      name: data['name'],
      phone: data['phone'],
      address: data['address'],
      profileImageUrl: data['profileImageUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role,
      'name': name,
      'phone': phone,
      'address': address,
      'profileImageUrl': profileImageUrl,
    };
  }
}
