import 'package:image_picker/image_picker.dart';
import '../../../core/network/pagination_response.dart';
import 'package:fifgroup_android_ticketing/data/models/chat_message_model.dart';
import 'package:fifgroup_android_ticketing/data/services/chat_service.dart';

class ChatRepository {
  final ChatService _service;

  ChatRepository({ChatService? service}) : _service = service ?? ChatService();

  Future<PaginationResponse<ChatMessageModel>> getChats(String sessionUuid, int page, {String? search}) {
    return _service.getChats(sessionUuid, page, search: search);
  }

  Future<PaginationResponse<ChatMessageModel>> getGlobalChats(String sessionUuid, int page, {String? search}) {
    return _service.getGlobalChats(sessionUuid, page, search: search);
  }

  Future<void> markAsRead(String sessionUuid) {
    return _service.markAsRead(sessionUuid);
  }

  Future<ChatMessageModel> sendChat(String sessionUuid, String text, XFile? attachment) {
    return _service.sendChat(sessionUuid, text, attachment);
  }
}
