import 'user_model.dart';

class LoginResponse {
  final String accessToken;
  final String tokenType;
  final UserModel user;

  LoginResponse({
    required this.accessToken,
    required this.tokenType,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['access_token'] ?? '',
      tokenType: json['token_type'] ?? 'Bearer',
      user: UserModel.fromJson(json['user'] ?? {}),
    );
  }
}
