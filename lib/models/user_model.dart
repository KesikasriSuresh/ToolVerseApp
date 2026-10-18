class UserModel {
  final String uid;
  String name;
  String society;
  String phone;
  String profilePic; // URL or empty
  String email;
  double? latitude;
  double? longitude;
  String formattedAddress;

  UserModel({
    required this.uid,
    required this.name,
    required this.society,
    required this.phone,
    this.profilePic = '',
    this.email = '',
    this.latitude,
    this.longitude,
    this.formattedAddress = '',
  });

  factory UserModel.fromJson(Map<String, dynamic> json, String uid) {
    return UserModel(
      uid: uid,
      name: json['name'] as String? ?? '',
      society: json['society'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      profilePic: json['profilePic'] as String? ?? '',
      email: json['email'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ??
          (json['lat'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble() ??
          (json['lng'] as num?)?.toDouble(),
      formattedAddress: json['formattedAddress'] as String? ??
          json['address'] as String? ??
          '',
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'name': name,
      'society': society,
      'phone': phone,
      'profilePic': profilePic,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (email.isNotEmpty) data['email'] = email;
    if (latitude != null) data['latitude'] = latitude;
    if (longitude != null) data['longitude'] = longitude;
    if (formattedAddress.isNotEmpty) {
      data['formattedAddress'] = formattedAddress;
    }
    return data;
  }
}
