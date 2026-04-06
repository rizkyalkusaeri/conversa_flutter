import 'package:image_picker/image_picker.dart';
import '../../../core/network/pagination_response.dart';
import '../models/chat_message_model.dart';
import '../service/chat_service.dart';

class ChatRepository {
  final ChatService _service;

  ChatRepository({ChatService? service}) : _service = service ?? ChatService();

  Future<PaginationResponse<ChatMessageModel>> getChats(String sessionUuid, int page) {
    return _service.getChats(sessionUuid, page);
  }

  Future<ChatMessageModel> sendChat(String sessionUuid, String text, XFile? attachment) {
    return _service.sendChat(sessionUuid, text, attachment);
  }
}
