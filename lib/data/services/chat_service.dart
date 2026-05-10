import 'dart:io';
import 'package:dio/dio.dart';
import 'package:mime/mime.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/pagination_response.dart';
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
      throw Exception('Gagal memuat pesan: $e');
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
      throw Exception('Gagal memuat pesan global: $e');
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
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        final data = e.response!.data is Map ? e.response!.data : {};
        String errorMessage = data['message'] ?? 'Gagal mengirim pesan';
        
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
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Koneksi timeout. Pastikan ukuran file tidak terlalu besar dan koneksi stabil.');
      }
      throw Exception('Gagal mengirim pesan: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }
}
