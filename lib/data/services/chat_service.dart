import 'dart:io';
import 'package:dio/dio.dart';
import 'package:mime/mime.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/pagination_response.dart';
import '../../../core/utils/error_helper.dart';
import 'package:fifgroup_android_ticketing/data/models/chat_message_model.dart';
import 'package:fifgroup_android_ticketing/core/utils/file_validator.dart';

class ChatService {
  final Dio _dio = DioClient.getInstance;

  Future<PaginationResponse<ChatMessageModel>> getChats(String sessionUuid, int page, {int limit = 15, String? search}) async {
    try {
      final Map<String, dynamic> queryParams = {
        'page': page,
        'limit': limit,
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _dio.get('/sessions/$sessionUuid/chats', queryParameters: queryParams);

      return PaginationResponse<ChatMessageModel>.fromJson(
        response.data,
        (json) => ChatMessageModel.fromJson(json as Map<String, dynamic>),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<PaginationResponse<ChatMessageModel>> getGlobalChats(String sessionUuid, int page, {int limit = 15, String? search}) async {
    try {
      final Map<String, dynamic> queryParams = {
        'page': page,
        'limit': limit,
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _dio.get('/global/sessions/$sessionUuid/chats', queryParameters: queryParams);

      return PaginationResponse<ChatMessageModel>.fromJson(
        response.data,
        (json) => ChatMessageModel.fromJson(json as Map<String, dynamic>),
      );
    } catch (e) {
      rethrow;
    }
  }

  // Menandai semua pesan dari lawan pada sesi ini sebagai sudah dibaca
  Future<void> markAsRead(String sessionUuid) async {
    try {
      await _dio.post('/sessions/$sessionUuid/chats/mark-read');
    } catch (e) {
      // fail silently untuk error receipt
    }
  }

  Future<ChatMessageModel> sendChat(String sessionUuid, String text, XFile? attachment) async {
    try {
      FormData formData = FormData();
      
      if (text.isNotEmpty) {
        formData.fields.add(MapEntry('message_content', text));
      }
      
      if (attachment != null) {
        await FileValidator.validateXFile(attachment);

        final String filePath = attachment.path;
        final String fileName = attachment.name.isNotEmpty
            ? attachment.name
            : filePath.split('/').last;
        final String? mimeType = lookupMimeType(fileName);

        MultipartFile multipartFile;

        // Cek apakah path ini adalah file fisik lokal atau content:// URI Android
        if (filePath.startsWith('/') && await File(filePath).exists()) {
          // File fisik: gunakan streaming untuk hemat RAM
          multipartFile = await MultipartFile.fromFile(
            filePath,
            filename: fileName,
            contentType: mimeType != null
                ? DioMediaType.parse(mimeType)
                : null,
          );
        } else {
          // Content URI (Android Gallery): baca sebagai bytes
          final bytes = await attachment.readAsBytes();
          multipartFile = MultipartFile.fromBytes(
            bytes,
            filename: fileName,
            contentType: mimeType != null
                ? DioMediaType.parse(mimeType)
                : null,
          );
        }

        formData.files.add(MapEntry('attachment', multipartFile));
      }

      final response = await _dio.post('/sessions/$sessionUuid/chats', data: formData);
      final apiResponse = ApiResponse<ChatMessageModel>.fromJson(
        response.data,
        (json) => ChatMessageModel.fromJson(json as Map<String, dynamic>),
      );
      
      if (apiResponse.success && apiResponse.data != null) {
        return apiResponse.data!;
      } else {
        throw Exception(apiResponse.message);
      }
    } catch (e) {
      throw Exception(ErrorHelper.getFriendlyError(e));
    }
  }

  Future<void> forwardChats(List<int> messageIds, List<String> destinationSessionUuids) async {
    try {
      final response = await _dio.post('/sessions/forward', data: {
        'message_ids': messageIds,
        'destination_session_uuids': destinationSessionUuids,
      });
      final apiResponse = ApiResponse<dynamic>.fromJson(
        response.data,
        (json) => json,
      );
      if (!apiResponse.success) {
        throw Exception(apiResponse.message);
      }
    } catch (e) {
      throw Exception(ErrorHelper.getFriendlyError(e));
    }
  }
}
