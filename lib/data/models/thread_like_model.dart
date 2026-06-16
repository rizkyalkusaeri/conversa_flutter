class ThreadLikeModel {
  final int id;
  final String? createdAt;
  final String userName;
  final String? userRole;
  final String? userLevel;

  ThreadLikeModel({
    required this.id,
    this.createdAt,
    required this.userName,
    this.userRole,
    this.userLevel,
  });

  factory ThreadLikeModel.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] as Map<String, dynamic>? ?? {};
    return ThreadLikeModel(
      id: json['id'] ?? 0,
      createdAt: json['created_at'],
      userName: userJson['full_name'] ?? 'User',
      userRole: userJson['role_name'],
      userLevel: userJson['level_name'],
    );
  }
}
