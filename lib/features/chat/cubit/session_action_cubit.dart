import 'package:bloc/bloc.dart';
import 'package:fifgroup_android_ticketing/data/repositories/session_repository.dart';
import 'session_action_state.dart';

class SessionActionCubit extends Cubit<SessionActionState> {
  final SessionRepository _repository;

  SessionActionCubit({SessionRepository? repository})
      : _repository = repository ?? SessionRepository(),
        super(SessionActionInitial());

  Future<void> requestClose(String uuid) async {
    emit(const SessionActionLoading('request_close'));
    try {
      final session = await _repository.requestClose(uuid);
      emit(SessionActionSuccess(session, 'Permintaan tutup sesi berhasil dikirim', 'request_close'));
    } catch (e) {
      emit(SessionActionError(e.toString().replaceFirst('Exception: ', ''), 'request_close'));
    }
  }

  Future<void> rejectClose(String uuid) async {
    emit(const SessionActionLoading('reject_close'));
    try {
      final session = await _repository.rejectClose(uuid);
      emit(SessionActionSuccess(session, 'Permintaan tutup sesi telah ditolak', 'reject_close'));
    } catch (e) {
      emit(SessionActionError(e.toString().replaceFirst('Exception: ', ''), 'reject_close'));
    }
  }

  Future<void> completeSession(String uuid, {int? rating, String? feedback}) async {
    emit(const SessionActionLoading('complete_session'));
    try {
      final session = await _repository.completeSession(uuid, rating: rating, feedback: feedback);
      emit(SessionActionSuccess(session, 'Sesi berhasil ditutup', 'complete_session'));
    } catch (e) {
      emit(SessionActionError(e.toString().replaceFirst('Exception: ', ''), 'complete_session'));
    }
  }

  Future<void> reopenSession(String uuid) async {
    emit(const SessionActionLoading('reopen_session'));
    try {
      final session = await _repository.reopenSession(uuid);
      emit(SessionActionSuccess(session, 'Permintaan buka kembali berhasil dikirim', 'reopen_session'));
    } catch (e) {
      emit(SessionActionError(e.toString().replaceFirst('Exception: ', ''), 'reopen_session'));
    }
  }
}
