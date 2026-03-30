import 'package:bloc/bloc.dart';
import '../repository/dashboard_repository.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final DashboardRepository _repository;

  DashboardCubit({DashboardRepository? repository})
      : _repository = repository ?? DashboardRepository(),
        super(DashboardInitial());

  Future<void> fetchSummary() async {
    emit(DashboardLoading());
    try {
      final summary = await _repository.getSummary();
      emit(DashboardLoaded(summary));
    } catch (e) {
      emit(DashboardError(e.toString().replaceFirst('Exception: ', '')));
    }
  }
}
