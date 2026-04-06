import 'package:dio/dio.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/pagination_response.dart';
import '../models/session_model.dart';
import '../models/master_data_model.dart';

class SessionService {
  final Dio _dio = DioClient.getInstance;

  Future<PaginationResponse<SessionModel>> getSessions({
    required String status,
    required int page,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get('/sessions', queryParameters: {
        'status': status,
        'page': page,
        'limit': limit,
      });

      return PaginationResponse<SessionModel>.fromJson(
        response.data,
        (json) => SessionModel.fromJson(json as Map<String, dynamic>),
      );
    } catch (e) {
      throw Exception('Gagal memuat daftar sesi (Chat): $e');
    }
  }

  Future<ApiResponse<SessionModel>> createSession(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/sessions', data: data);
      return ApiResponse<SessionModel>.fromJson(
        response.data,
        (json) => SessionModel.fromJson(json as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        final data = e.response!.data is Map ? e.response!.data : {};
        String errorMessage = data['message'] ?? 'Gagal membuat sesi';
        
        if (data['errors'] != null && data['errors'] is Map) {
          final Map errors = data['errors'];
          if (errors.isNotEmpty) {
            final firstKey = errors.keys.first;
            final errorValues = errors[firstKey];
            if (errorValues is List && errorValues.isNotEmpty) {
              errorMessage = errorValues.first.toString();
            } else if (errorValues is String) {
              errorMessage = errorValues;
            }
          }
        }
        
        throw Exception(errorMessage);
      }
      throw Exception('Gagal membuat sesi: ${e.message}');
    } catch (e) {
      throw Exception('Terjadi kesalahan tak terduga: $e');
    }
  }

  Future<List<MasterDataModel>> getMasterData(String endpoint, String keyName, {Map<String, dynamic>? queryParams}) async {
    try {
      final response = await _dio.get(endpoint, queryParameters: queryParams);
      final listData = response.data['data'] as List<dynamic>? ?? [];
      return listData.map((e) => MasterDataModel.fromJson(e, keyName)).toList();
    } catch (e) {
      throw Exception('Gagal load master data $endpoint: $e');
    }
  }
}
