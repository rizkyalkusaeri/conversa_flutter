import 'package:dio/dio.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../models/login_response.dart';

class AuthService {
  final Dio _dio = DioClient.getInstance;

  Future<ApiResponse<LoginResponse>> loginRequest(String username, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'username': username,
        'password': password,
        'device_name': 'Mobile App', // bisa diganti atau dari build_context
      });

      // Mapping response Dio ke dalam ApiResponse Generik
      return ApiResponse<LoginResponse>.fromJson(
        response.data,
        (json) => LoginResponse.fromJson(json as Map<String, dynamic>),
      );

    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        return ApiResponse<LoginResponse>.fromJson(
          e.response!.data,
          (json) => LoginResponse.fromJson(json as Map<String, dynamic>),
        );
      }
      throw Exception('Gagal menghubungi server: ${e.message}');
    } catch (e) {
      throw Exception('Terjadi kesalahan yang tidak terduga: $e');
    }
  }

  Future<ApiResponse<dynamic>> logoutRequest() async {
    try {
      final response = await _dio.post('/auth/logout');
      return ApiResponse.fromJson(response.data, null);
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
         return ApiResponse.fromJson(e.response!.data, null);
      }
      throw Exception('Gagal menghubungi server: ${e.message}');
    } catch (e) {
      throw Exception('Terjadi kesalahan yang tidak terduga: $e');
    }
  }
}
