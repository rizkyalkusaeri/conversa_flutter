class MasterDataModel {
  final int id;
  final String text;
  final bool? isHaveUniqueId;

  MasterDataModel({
    required this.id,
    required this.text,
    this.isHaveUniqueId,
  });

  factory MasterDataModel.fromJson(Map<String, dynamic> json, String keyName) {
    return MasterDataModel(
      id: json['id'] ?? 0,
      text: json[keyName]?.toString() ?? '',
      isHaveUniqueId: json['is_have_unique_id'] == 1 || json['is_have_unique_id'] == true,
    );
  }
}
