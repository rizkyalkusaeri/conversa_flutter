import 'package:bloc/bloc.dart';
import '../repository/session_repository.dart';
import '../models/master_data_model.dart';
import 'create_session_state.dart';

class CreateSessionCubit extends Cubit<CreateSessionState> {
  final SessionRepository _repository;
  
  // Cache state internal untuk backup bila terjadi error saat fetching lanjutan
  CreateSessionFormState? _lastFormState; 

  CreateSessionCubit({SessionRepository? repository})
      : _repository = repository ?? SessionRepository(),
        super(CreateSessionInitial());

  // Di panggil pertama kali sheet dibuka (Hanya load Category)
  Future<void> loadInitialMasterData() async {
    emit(CreateSessionLoadingMasterData());
    try {
      final categories = await _repository.getCategories();
      
      final newState = CreateSessionFormState(
        categories: categories,
        subCategories: const [],
        topics: const [],
        resolvers: const [],
      );
      _lastFormState = newState;
      emit(newState);
      
    } catch (e) {
      emit(CreateSessionError("Gagal mengambil data kategori: $e"));
    }
  }

  // Dipanggil ketika dropdown Kategori berubah
  Future<void> onCategorySelected(int categoryId) async {
    if (state is CreateSessionFormState) {
      final currentState = state as CreateSessionFormState;
      
      emit(currentState.copyWith(
        isLoadingCategoryData: true,
        // Reset state child
        subCategories: [],
        topics: [],
        resolvers: [],
        isUniqueIdRequired: false,
      ));

      try {
        final futures = await Future.wait([
          _repository.getSubCategories(categoryId),
          _repository.getResolvers(categoryId),
        ]);

        final newState = currentState.copyWith(
          isLoadingCategoryData: false,
          subCategories: futures[0],
          resolvers: futures[1],
        );
        _lastFormState = newState;
        emit(newState);
      } catch (e) {
        emit(CreateSessionError("Gagal mengambil subordinat kategori: $e"));
        if (_lastFormState != null) emit(_lastFormState!);
      }
    }
  }

  // Dipanggil ketika dropdown Sub-Kategori berubah
  Future<void> onSubCategorySelected(MasterDataModel subCategory) async {
    if (state is CreateSessionFormState) {
      final currentState = state as CreateSessionFormState;
      final bool requiresUnique = subCategory.isHaveUniqueId ?? false;

      emit(currentState.copyWith(
        isLoadingTopicData: !requiresUnique,
        isUniqueIdRequired: requiresUnique,
        topics: [], // Bersihkan topik sebelumnya
      ));

      // Jika dia mewajibkan unique ID (No APPL dsb), kita TIDAK PERLU Fetch topic
      if (!requiresUnique) {
        try {
          final topics = await _repository.getTopics(subCategory.id);
          final newState = currentState.copyWith(
            isLoadingTopicData: false,
            topics: topics,
          );
          _lastFormState = newState;
          emit(newState);
        } catch (e) {
          emit(CreateSessionError("Gagal mengambil data Topik: $e"));
          if (_lastFormState != null) emit(_lastFormState!);
        }
      } else {
        _lastFormState = currentState.copyWith(
            isLoadingTopicData: false, 
            isUniqueIdRequired: true,
        );
        emit(_lastFormState!);
      }
    }
  }

  Future<void> submitSession(Map<String, dynamic> data) async {
    if (state is CreateSessionFormState) {
      final currentState = state as CreateSessionFormState;
      _lastFormState = currentState; // simpan cadangan sebelum submit

      emit(CreateSessionSubmitting(
        categories: currentState.categories,
        subCategories: currentState.subCategories,
        topics: currentState.topics,
        resolvers: currentState.resolvers,
        isUniqueIdRequired: currentState.isUniqueIdRequired,
      ));

      try {
        final session = await _repository.createSession(data);
        emit(CreateSessionSuccess(session));
      } catch (e) {
        emit(CreateSessionError(e.toString().replaceFirst('Exception: ', ''), isDuringSubmit: true));
        // Kembalikan form state agar User dapat mencoba lagi
        if (_lastFormState != null) emit(_lastFormState!);
      }
    }
  }
}
