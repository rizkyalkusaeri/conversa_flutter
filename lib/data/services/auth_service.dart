import 'package:dio/dio.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/error_helper.dart';
import 'package:fifgroup_android_ticketing/data/models/login_response.dart';

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
        if (e.response!.statusCode == 429) rethrow; // Biarkan login cubit menangani rate limit
        return ApiResponse<LoginResponse>.fromJson(
          e.response!.data,
          (json) => LoginResponse.fromJson(json as Map<String, dynamic>),
        );
      }
      throw Exception(ErrorHelper.getFriendlyError(e));
    } catch (e) {
      throw Exception(ErrorHelper.getFriendlyError(e));
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
      throw Exception(ErrorHelper.getFriendlyError(e));
    } catch (e) {
      throw Exception(ErrorHelper.getFriendlyError(e));
    }
  }

  Future<ApiResponse<dynamic>> changePasswordRequest({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final response = await _dio.post('/auth/change-password', data: {
        'current_password': currentPassword,
        'password': password,
        'password_confirmation': passwordConfirmation,
      });

      return ApiResponse.fromJson(response.data, null);
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        return ApiResponse.fromJson(e.response!.data, null);
      }
      throw Exception(ErrorHelper.getFriendlyError(e));
    } catch (e) {
      throw Exception(ErrorHelper.getFriendlyError(e));
    }
  }
}
