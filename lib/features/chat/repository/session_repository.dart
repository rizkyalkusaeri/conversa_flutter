import '../models/session_model.dart';
import '../models/master_data_model.dart';
import '../service/session_service.dart';
import '../../../core/network/pagination_response.dart';

class SessionRepository {
  final SessionService _service;

  SessionRepository({SessionService? service})
      : _service = service ?? SessionService();

  Future<PaginationResponse<SessionModel>> fetchSessions(String status, int page) {
    return _service.getSessions(status: status, page: page);
  }

  Future<SessionModel> createSession(Map<String, dynamic> data) async {
    final response = await _service.createSession(data);
    if (response.success && response.data != null) {
      return response.data!;
    } else {
      throw Exception(response.message.isNotEmpty ? response.message : "Terjadi kesalahan respon tanpa pesan");
    }
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
