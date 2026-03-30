import 'package:dio/dio.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../models/dashboard_summary_model.dart';

class DashboardService {
  final Dio _dio = DioClient.getInstance;

  Future<ApiResponse<DashboardSummaryModel>> fetchSummary() async {
    try {
      final response = await _dio.get('/dashboard/summary');

      return ApiResponse<DashboardSummaryModel>.fromJson(
        response.data,
        (json) => DashboardSummaryModel.fromJson(json as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        return ApiResponse<DashboardSummaryModel>.fromJson(
          e.response!.data,
          (json) => DashboardSummaryModel.fromJson(json as Map<String, dynamic>),
        );
      }
      throw Exception('Gagal menghubungi server: ${e.message}');
    } catch (e) {
      throw Exception('Terjadi kesalahan yang tidak terduga: $e');
    }
  }
}
