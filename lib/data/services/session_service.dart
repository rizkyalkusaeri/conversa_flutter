import 'package:dio/dio.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/pagination_response.dart';
import 'package:fifgroup_android_ticketing/data/models/session_model.dart';
import 'package:fifgroup_android_ticketing/data/models/master_data_model.dart';
import 'package:fifgroup_android_ticketing/core/exceptions/pending_feedback_exception.dart';
import '../../../core/utils/error_helper.dart';


class SessionService {
  final Dio _dio = DioClient.getInstance;

  Future<PaginationResponse<SessionModel>> getSessions({
    required String status,
    required int page,
    int limit = 20,
    String? search,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {
        'status': status,
        'page': page,
        'limit': limit,
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _dio.get('/sessions', queryParameters: queryParams);

      return PaginationResponse<SessionModel>.fromJson(
        response.data,
        (json) => SessionModel.fromJson(json as Map<String, dynamic>),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<PaginationResponse<SessionModel>> getGlobalSessions({
    required int page,
    String? status,
    int limit = 20,
    String? search,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {
        'page': page,
        'limit': limit,
      };

      if (status != null && status.isNotEmpty && status != 'all') {
        queryParams['status'] = status.toLowerCase();
      }

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _dio.get('/global/sessions', queryParameters: queryParams);

      return PaginationResponse<SessionModel>.fromJson(
        response.data,
        (json) => SessionModel.fromJson(json as Map<String, dynamic>),
      );
    } catch (e) {
      rethrow;
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
        final resData = e.response!.data is Map ? e.response!.data as Map : {};
        final String errorMessage = resData['message'] ?? 'Gagal membuat sesi';
        final errors = resData['errors'];

        // Cek pending_session_uuid di errors (bukan di data)
        if (e.response!.statusCode == 403 &&
            errors is Map &&
            errors['pending_session_uuid'] != null) {
          throw PendingFeedbackException(
            message: errorMessage,
            pendingSessionUuid: errors['pending_session_uuid'].toString(),
          );
        }

        // Parse validation errors biasa
        if (errors != null && errors is Map && errors.isNotEmpty) {
          final firstKey = errors.keys.first;
          final errorValues = errors[firstKey];
          if (errorValues is List && errorValues.isNotEmpty) {
            throw Exception(errorValues.first.toString());
          } else if (errorValues is String) {
            throw Exception(errorValues);
          }
        }
      }
      throw Exception(ErrorHelper.getFriendlyError(e));
    } on PendingFeedbackException {
      // Rethrow tanpa membungkus — agar cubit dapat menangani dialog rating
      rethrow;
    } catch (e) {
      throw Exception(ErrorHelper.getFriendlyError(e));
    }
  }


  Future<ApiResponse<SessionModel>> requestClose(String uuid) async {
    try {
      final response = await _dio.post('/sessions/$uuid/request-close');
      return ApiResponse<SessionModel>.fromJson(
        response.data,
        (json) => SessionModel.fromJson(json as Map<String, dynamic>),
      );
    } catch (e) {
      throw Exception(ErrorHelper.getFriendlyError(e));
    }
  }

  Future<ApiResponse<SessionModel>> submitFeedback(
      String uuid, int rating, String? feedback) async {
    try {
      final response = await _dio.post(
        '/sessions/$uuid/submit-feedback',
        data: {
          'rating': rating,
          if (feedback != null && feedback.isNotEmpty) 'feedback': feedback,
        },
      );
      return ApiResponse<SessionModel>.fromJson(
        response.data,
        (json) => SessionModel.fromJson(json as Map<String, dynamic>),
      );
    } catch (e) {
      throw Exception(ErrorHelper.getFriendlyError(e));
    }
  }

  Future<ApiResponse<SessionModel>> rejectClose(String uuid) async {
    try {
      final response = await _dio.post('/sessions/$uuid/reject-close');
      return ApiResponse<SessionModel>.fromJson(
        response.data,
        (json) => SessionModel.fromJson(json as Map<String, dynamic>),
      );
    } catch (e) {
      throw Exception(ErrorHelper.getFriendlyError(e));
    }
  }

  Future<ApiResponse<SessionModel>> completeSession(String uuid, {int? rating, String? feedback}) async {
    try {
      final data = <String, dynamic>{};
      if (rating != null) data['rating'] = rating;
      if (feedback != null && feedback.isNotEmpty) data['feedback'] = feedback;

      final response = await _dio.post('/sessions/$uuid/complete', data: data);
      return ApiResponse<SessionModel>.fromJson(
        response.data,
        (json) => SessionModel.fromJson(json as Map<String, dynamic>),
      );
    } catch (e) {
      throw Exception(ErrorHelper.getFriendlyError(e));
    }
  }

  Future<ApiResponse<SessionModel>> reopenSession(String uuid) async {
    try {
      final response = await _dio.post('/sessions/$uuid/reopen');
      return ApiResponse<SessionModel>.fromJson(
        response.data,
        (json) => SessionModel.fromJson(json as Map<String, dynamic>),
      );
    } catch (e) {
      throw Exception(ErrorHelper.getFriendlyError(e));
    }
  }

  Future<SessionModel> getSessionByUuid(String uuid) async {
    try {
      final response = await _dio.get('/sessions/$uuid');
      final data = response.data['data'];
      return SessionModel.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      throw Exception(ErrorHelper.getFriendlyError(e));
    }
  }

  Future<List<MasterDataModel>> getMasterData(String endpoint, String keyName, {Map<String, dynamic>? queryParams}) async {
    try {
      final response = await _dio.get(endpoint, queryParameters: queryParams);
      final listData = response.data['data'] as List<dynamic>? ?? [];
      return listData.map((e) => MasterDataModel.fromJson(e, keyName)).toList();
    } catch (e) {
      throw Exception(ErrorHelper.getFriendlyError(e));
    }
  }
}
