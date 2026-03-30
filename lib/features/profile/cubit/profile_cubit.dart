import 'package:bloc/bloc.dart';
import '../repository/profile_repository.dart';
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
      emit(ProfileError(e.toString().replaceFirst('Exception: ', '')));
    }
  }
}
