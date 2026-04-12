import 'dart:convert';

class UserModel {
  final int id;
  final String fullName;
  final String username;
  final String? role;
  final String? fcmToken;
  final String? location;
  final String? level;

  UserModel({
    required this.id,
    required this.fullName,
    required this.username,
    this.role,
    this.fcmToken,
    this.location,
    this.level,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Handling kalau relasi location atau level adalah Object dari API Laravel
    String? getRelationName(dynamic field, String key) {
      if (field is Map<String, dynamic>) {
        return field[key]?.toString();
      }
      return field?.toString();
    }

    return UserModel(
      id: json['id'] ?? 0,
      fullName: json['full_name'] ?? '',
      username: json['username'] ?? '',
      role: getRelationName(json['role'], 'role_name') ?? json['role']?.toString() ?? json['role_name']?.toString(), // Handle direct string OR object OR role_name root key
      fcmToken: json['fcm_token'],
      location: getRelationName(json['location'], 'location_name'),
      level: getRelationName(json['level'], 'name') ?? json['level']?.toString(), 
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'username': username,
      'role': role,
      'fcm_token': fcmToken,
      'location': location,
      'level': level,
    };
  }

  // Helper untuk storage_manager persistency
  String toJsonString() => json.encode(toJson());
  
  factory UserModel.fromJsonString(String source) => 
      UserModel.fromJson(json.decode(source));
}
