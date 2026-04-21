import 'package:dio/dio.dart';
import 'package:fifgroup_android_ticketing/data/models/thread_model.dart';
import 'package:fifgroup_android_ticketing/data/models/comment_model.dart';
import 'package:fifgroup_android_ticketing/data/services/thread_service.dart';
import '../../../core/network/pagination_response.dart';

class ThreadRepository {
  final ThreadService _service;

  ThreadRepository({ThreadService? service})
      : _service = service ?? ThreadService();

  Future<PaginationResponse<ThreadModel>> fetchThreads({
    required int page,
    String? search,
  }) {
    return _service.getThreads(page: page, search: search);
  }

  Future<ThreadModel> fetchThreadDetail(String uuid) async {
    final response = await _service.getThreadDetail(uuid);
    if (response.success && response.data != null) {
      return response.data!;
    }
    throw Exception(
        response.message.isNotEmpty ? response.message : 'Thread tidak ditemukan');
  }

  Future<ThreadModel> createThread(FormData formData) async {
    final response = await _service.createThread(formData);
    if (response.success && response.data != null) {
      return response.data!;
    }
    throw Exception(
        response.message.isNotEmpty ? response.message : 'Gagal membuat thread');
  }

  Future<ThreadModel> updateThread(String uuid, FormData formData) async {
    final response = await _service.updateThread(uuid, formData);
    if (response.success && response.data != null) {
      return response.data!;
    }
    throw Exception(response.message.isNotEmpty
        ? response.message
        : 'Gagal memperbarui thread');
  }

  Future<PaginationResponse<CommentModel>> fetchComments(
    String threadUuid, {
    int page = 1,
  }) {
    return _service.getComments(threadUuid, page: page);
  }

  Future<int> toggleLikeThread(String uuid) {
    return _service.toggleLikeThread(uuid);
  }

  Future<CommentModel> postComment(
      String threadUuid, FormData formData) async {
    final response = await _service.postComment(threadUuid, formData);
    if (response.success && response.data != null) {
      return response.data!;
    }
    throw Exception(response.message.isNotEmpty
        ? response.message
        : 'Gagal mengirim komentar');
  }

  Future<int> toggleLikeComment(int commentId) {
    return _service.toggleLikeComment(commentId);
  }
}
