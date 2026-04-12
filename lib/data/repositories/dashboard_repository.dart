import 'package:fifgroup_android_ticketing/data/services/dashboard_service.dart';
import 'package:fifgroup_android_ticketing/data/models/dashboard_summary_model.dart';

class DashboardRepository {
  final DashboardService _service;

  DashboardRepository({DashboardService? service})
      : _service = service ?? DashboardService();

  Future<DashboardSummaryModel> getSummary() async {
    final response = await _service.fetchSummary();

    if (response.success && response.data != null) {
      return response.data!;
    } else {
      throw Exception(response.message.isNotEmpty
          ? response.message
          : 'Gagal memuat dashboard');
    }
  }
}
