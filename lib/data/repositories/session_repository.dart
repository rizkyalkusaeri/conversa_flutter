import 'package:fifgroup_android_ticketing/data/models/session_model.dart';
import 'package:fifgroup_android_ticketing/data/models/master_data_model.dart';
import 'package:fifgroup_android_ticketing/data/services/session_service.dart';
import '../../../core/network/pagination_response.dart';

class SessionRepository {
  final SessionService _service;

  SessionRepository({SessionService? service})
      : _service = service ?? SessionService();

  Future<PaginationResponse<SessionModel>> fetchSessions(String status, int page, {String? search}) {
    return _service.getSessions(status: status, page: page, search: search);
  }

  Future<PaginationResponse<SessionModel>> fetchGlobalSessions(int page, {String? status, String? search}) {
    return _service.getGlobalSessions(page: page, status: status, search: search);
  }

  Future<SessionModel> createSession(Map<String, dynamic> data) async {
    final response = await _service.createSession(data);
    if (response.success && response.data != null) {
      return response.data!;
    } else {
      throw Exception(response.message.isNotEmpty ? response.message : "Terjadi kesalahan respon tanpa pesan");
    }
  }

  Future<SessionModel> requestClose(String uuid) async {
    final response = await _service.requestClose(uuid);
    if (response.success && response.data != null) return response.data!;
    throw Exception(response.message);
  }

  Future<SessionModel> rejectClose(String uuid) async {
    final response = await _service.rejectClose(uuid);
    if (response.success && response.data != null) return response.data!;
    throw Exception(response.message);
  }

  Future<SessionModel> completeSession(String uuid, {int? rating, String? feedback}) async {
    final response = await _service.completeSession(uuid, rating: rating, feedback: feedback);
    if (response.success && response.data != null) return response.data!;
    throw Exception(response.message);
  }

  Future<SessionModel> reopenSession(String uuid) async {
    final response = await _service.reopenSession(uuid);
    if (response.success && response.data != null) return response.data!;
    throw Exception(response.message);
  }

  Future<List<MasterDataModel>> getCategories({String? search}) {
    Map<String, dynamic> params = {};
    if (search != null && search.isNotEmpty) params['search'] = search;
    return _service.getMasterData('/master/categories', 'category_name', queryParams: params);
  }
  
  Future<List<MasterDataModel>> getSubCategories(int categoryId, {String? search}) {
    Map<String, dynamic> params = {'category_id': categoryId};
    if (search != null && search.isNotEmpty) params['search'] = search;
    return _service.getMasterData('/master/sub-categories', 'sub_category_name', queryParams: params);
  }
      
  Future<List<MasterDataModel>> getTopics(int subCategoryId, {String? search}) {
    Map<String, dynamic> params = {'sub_category_id': subCategoryId};
    if (search != null && search.isNotEmpty) params['search'] = search;
    return _service.getMasterData('/master/topics', 'topic_name', queryParams: params);
  }
      
  Future<List<MasterDataModel>> getResolvers(int categoryId, {String? search}) {
    Map<String, dynamic> params = {'category_id': categoryId};
    if (search != null && search.isNotEmpty) params['search'] = search;
    return _service.getMasterData('/master/resolvers', 'full_name', queryParams: params);
  }
}
