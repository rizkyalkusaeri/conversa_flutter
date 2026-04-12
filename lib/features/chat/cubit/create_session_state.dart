import 'package:equatable/equatable.dart';
import 'package:fifgroup_android_ticketing/data/models/master_data_model.dart';
import 'package:fifgroup_android_ticketing/data/models/session_model.dart';

abstract class CreateSessionState extends Equatable {
  const CreateSessionState();

  @override
  List<Object?> get props => [];
}

class CreateSessionInitial extends CreateSessionState {}

class CreateSessionLoadingMasterData extends CreateSessionState {}

class CreateSessionFormState extends CreateSessionState {
  final List<MasterDataModel> categories;
  final List<MasterDataModel> subCategories;
  final List<MasterDataModel> topics;
  final List<MasterDataModel> resolvers;
  
  final bool isLoadingCategoryData; // Loading subs & resolvers
  final bool isLoadingTopicData;    // Loading topics

  final bool isUniqueIdRequired; // Tentukan apakah subcategory memaksa unique ID

  const CreateSessionFormState({
    required this.categories,
    required this.subCategories,
    required this.topics,
    required this.resolvers,
    this.isLoadingCategoryData = false,
    this.isLoadingTopicData = false,
    this.isUniqueIdRequired = false,
  });

  CreateSessionFormState copyWith({
    List<MasterDataModel>? categories,
    List<MasterDataModel>? subCategories,
    List<MasterDataModel>? topics,
    List<MasterDataModel>? resolvers,
    bool? isLoadingCategoryData,
    bool? isLoadingTopicData,
    bool? isUniqueIdRequired,
  }) {
    return CreateSessionFormState(
      categories: categories ?? this.categories,
      subCategories: subCategories ?? this.subCategories,
      topics: topics ?? this.topics,
      resolvers: resolvers ?? this.resolvers,
      isLoadingCategoryData: isLoadingCategoryData ?? this.isLoadingCategoryData,
      isLoadingTopicData: isLoadingTopicData ?? this.isLoadingTopicData,
      isUniqueIdRequired: isUniqueIdRequired ?? this.isUniqueIdRequired,
    );
  }

  @override
  List<Object?> get props => [
        categories, subCategories, topics, resolvers, 
        isLoadingCategoryData, isLoadingTopicData, isUniqueIdRequired
      ];
}

class CreateSessionSubmitting extends CreateSessionFormState {
  const CreateSessionSubmitting({
    required super.categories,
    required super.subCategories,
    required super.topics,
    required super.resolvers,
    required super.isUniqueIdRequired,
  });
}

class CreateSessionSuccess extends CreateSessionState {
  final SessionModel newSession;

  const CreateSessionSuccess(this.newSession);

  @override
  List<Object?> get props => [newSession];
}

class CreateSessionError extends CreateSessionState {
  final String message;
  final bool isDuringSubmit;

  const CreateSessionError(this.message, {this.isDuringSubmit = false});

  @override
  List<Object?> get props => [message, isDuringSubmit];
}
