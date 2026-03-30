import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

part 'user_state.dart';

class UserCubit extends Cubit<UserState> {
  UserCubit() : super(UserInitial());

  final Dio _dio = Dio();

  Future<void> getUsers() async {
    emit(UserLoading());
    try {
      final response = await _dio.get(
        'https://jsonplaceholder.typicode.com/users',
      );
      emit(UserSuccess(users: response.data));
    } catch (e) {
      emit(UserError(message: e.toString()));
    }
  }
}
