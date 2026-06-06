import 'package:dio/dio.dart';
import 'package:bloc/bloc.dart';
import 'package:fifgroup_android_ticketing/data/repositories/profile_repository.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final ProfileRepository _repository;

  ProfileCubit({ProfileRepository? repository})
      : _repository = repository ?? ProfileRepository(),
        super(ProfileInitial());

  Future<void> getProfileDetails() async {
    emit(ProfileLoading());
    try {
      final user = await _repository.getProfile();
      emit(ProfileLoaded(user));
    } catch (e) {
      emit(ProfileError(_friendlyError(e)));
    }
  }

  static String _friendlyError(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
        case DioExceptionType.badResponse:
          final code = e.response?.statusCode;
          if (code == 401) return 'Sesi telah berakhir. Silakan login kembali.';
          if (code == 403) return 'Anda tidak memiliki akses.';
          if (code == 404) return 'Data tidak ditemukan.';
          if (code != null && code >= 500) return 'Server sedang bermasalah. Coba beberapa saat lagi.';
          return 'Terjadi kesalahan dari server.';
        case DioExceptionType.cancel:
          return 'Permintaan dibatalkan.';
        default:
          return 'Terjadi kesalahan jaringan.';
      }
    }
    final raw = e.toString();
    return raw.startsWith('Exception: ') ? raw.replaceFirst('Exception: ', '') : raw;
  }
}
