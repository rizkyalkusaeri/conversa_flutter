class MasterDataModel {
  final int id;
  final String text;
  final bool? isHaveUniqueId;
  /// Informasi tambahan opsional (misalnya: role dan jabatan untuk resolver)
  final String? subtitle;

  MasterDataModel({
    required this.id,
    required this.text,
    this.isHaveUniqueId,
    this.subtitle,
  });

  factory MasterDataModel.fromJson(Map<String, dynamic> json, String keyName) {
    return MasterDataModel(
      id: json['id'] ?? 0,
      text: json[keyName]?.toString() ?? '',
      isHaveUniqueId: json['is_have_unique_id'] == 1 || json['is_have_unique_id'] == true,
    );
  }

  /// Factory khusus untuk resolver — sertakan role dan jabatan sebagai subtitle
  factory MasterDataModel.fromResolverJson(Map<String, dynamic> json) {
    final role  = json['role_name']?.toString() ?? '';
    final level = json['level_name']?.toString() ?? '';

    // Bangun subtitle: "HO · Manager" atau hanya salah satu jika ada yang kosong
    final parts = [role, level].where((s) => s.isNotEmpty).toList();
    final subtitle = parts.isNotEmpty ? parts.join(' · ') : null;

    return MasterDataModel(
      id: json['id'] ?? 0,
      text: json['full_name']?.toString() ?? '',
      subtitle: subtitle,
    );
  }
}
