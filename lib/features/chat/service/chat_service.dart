import 'package:dio/dio.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/pagination_response.dart';
import '../models/chat_message_model.dart';
import 'package:image_picker/image_picker.dart';

class ChatService {
  final Dio _dio = DioClient.getInstance;

  Future<PaginationResponse<ChatMessageModel>> getChats(String sessionUuid, int page, {int limit = 15}) async {
    try {
      final response = await _dio.get('/sessions/$sessionUuid/chats', queryParameters: {
        'page': page,
        'limit': limit,
      });

      return PaginationResponse<ChatMessageModel>.fromJson(
        response.data,
        (json) => ChatMessageModel.fromJson(json as Map<String, dynamic>),
      );
    } catch (e) {
      throw Exception('Gagal memuat pesan: $e');
    }
  }

  Future<ChatMessageModel> sendChat(String sessionUuid, String text, XFile? attachment) async {
    try {
      FormData formData = FormData();
      
      if (text.isNotEmpty) {
        formData.fields.add(MapEntry('message_content', text));
      }
      
      if (attachment != null) {
        final bytes = await attachment.readAsBytes();
        formData.files.add(MapEntry(
          'attachment',
          MultipartFile.fromBytes(bytes, filename: attachment.name),
        ));
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
      throw Exception('Gagal mengirim pesan: ${e.message}');
    } catch (e) {
      throw Exception('Terjadi kesalahan tak terduga: $e');
    }
  }
}
