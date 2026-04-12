import 'package:dio/dio.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/pagination_response.dart';
import 'package:fifgroup_android_ticketing/data/models/thread_model.dart';
import 'package:fifgroup_android_ticketing/data/models/comment_model.dart';

class ThreadService {
  final Dio _dio = DioClient.getInstance;

  /// Fetch paginated list of threads
  Future<PaginationResponse<ThreadModel>> getThreads({
    required int page,
    int limit = 15,
    String? search,
  }) async {
    try {
      final params = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (search != null && search.isNotEmpty) {
        params['search'] = search;
      }

      final response = await _dio.get('/threads', queryParameters: params);

      return PaginationResponse<ThreadModel>.fromJson(
        response.data,
        (json) => ThreadModel.fromJson(json as Map<String, dynamic>),
      );
    } catch (e) {
      throw Exception('Gagal memuat daftar thread: $e');
    }
  }

  /// Fetch single thread detail with comments
  Future<ApiResponse<ThreadModel>> getThreadDetail(String uuid) async {
    try {
      final response = await _dio.get('/threads/$uuid');

      return ApiResponse<ThreadModel>.fromJson(
        response.data,
        (json) => ThreadModel.fromJson(json as Map<String, dynamic>),
      );
    } catch (e) {
      throw Exception('Gagal memuat detail thread: $e');
    }
  }

  /// Create a new thread (multipart form-data)
  Future<ApiResponse<ThreadModel>> createThread(FormData formData) async {
    try {
      final response = await _dio.post(
        '/threads',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      return ApiResponse<ThreadModel>.fromJson(
        response.data,
        (json) => ThreadModel.fromJson(json as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        final data = e.response!.data is Map ? e.response!.data : {};
        String errorMessage = data['message'] ?? 'Gagal membuat thread';
        throw Exception(errorMessage);
      }
      throw Exception('Gagal membuat thread: ${e.message}');
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  /// Update an existing thread (multipart form-data via POST)
  Future<ApiResponse<ThreadModel>> updateThread(
      String uuid, FormData formData) async {
    try {
      final response = await _dio.post(
        '/threads/$uuid/update',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      return ApiResponse<ThreadModel>.fromJson(
        response.data,
        (json) => ThreadModel.fromJson(json as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        final data = e.response!.data is Map ? e.response!.data : {};
        String errorMessage = data['message'] ?? 'Gagal memperbarui thread';
        throw Exception(errorMessage);
      }
      throw Exception('Gagal memperbarui thread: ${e.message}');
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  /// Toggle like on a thread
  Future<int> toggleLikeThread(String uuid) async {
    try {
      final response = await _dio.post('/threads/$uuid/like');
      final data = response.data['data'] ?? {};
      return data['likes_count'] ?? 0;
    } catch (e) {
      throw Exception('Gagal mengubah status like: $e');
    }
  }

  /// Post a comment on a thread
  Future<ApiResponse<CommentModel>> postComment(
      String threadUuid, FormData formData) async {
    try {
      final response = await _dio.post(
        '/threads/$threadUuid/comments',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      return ApiResponse<CommentModel>.fromJson(
        response.data,
        (json) => CommentModel.fromJson(json as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        final data = e.response!.data is Map ? e.response!.data : {};
        String errorMessage = data['message'] ?? 'Gagal mengirim komentar';
        throw Exception(errorMessage);
      }
      throw Exception('Gagal mengirim komentar: ${e.message}');
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  /// Toggle like on a comment
  Future<int> toggleLikeComment(int commentId) async {
    try {
      final response = await _dio.post('/comments/$commentId/like');
      final data = response.data['data'] ?? {};
      return data['likes_count'] ?? 0;
    } catch (e) {
      throw Exception('Gagal mengubah status like komentar: $e');
    }
  }
}
