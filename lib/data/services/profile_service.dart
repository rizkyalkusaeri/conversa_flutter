import 'package:dio/dio.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import 'package:fifgroup_android_ticketing/data/models/user_model.dart';

class ProfileService {
  final Dio _dio = DioClient.getInstance;

  Future<ApiResponse<UserModel>> fetchProfile() async {
    try {
      final response = await _dio.get('/profile');
      return ApiResponse<UserModel>.fromJson(
        response.data,
        (json) => UserModel.fromJson(json as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        return ApiResponse<UserModel>.fromJson(
          e.response!.data,
          (json) => UserModel.fromJson(json as Map<String, dynamic>),
        );
      }
      throw Exception('Gagal menghubungi server: ${e.message}');
    } catch (e) {
      throw Exception('Terjadi kesalahan yang tidak terduga: $e');
    }
  }
}
