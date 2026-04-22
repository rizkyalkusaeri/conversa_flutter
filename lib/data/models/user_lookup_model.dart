/// Model ringan untuk dropdown pilih user berdasarkan jabatan/level.
///
/// Digunakan di form Create/Edit Thread saat user memilih
/// user spesifik berdasarkan jabatan yang sudah dipilih.
/// Data dimuat dari endpoint GET /master/users-by-level.
class UserLookupModel {
  final int id;
  final String fullName;

  const UserLookupModel({
    required this.id,
    required this.fullName,
  });

  factory UserLookupModel.fromJson(Map<String, dynamic> json) {
    return UserLookupModel(
      id: json['id'] as int,
      fullName: json['full_name'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserLookupModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => fullName;
}
