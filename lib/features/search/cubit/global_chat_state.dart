import 'package:equatable/equatable.dart';
import 'package:fifgroup_android_ticketing/data/models/chat_message_model.dart';

abstract class GlobalChatState extends Equatable {
  const GlobalChatState();

  @override
  List<Object?> get props => [];
}

class GlobalChatInitial extends GlobalChatState {}

class GlobalChatLoading extends GlobalChatState {
  final bool isFirstLoad;
  const GlobalChatLoading({this.isFirstLoad = true});
  
  @override
  List<Object?> get props => [isFirstLoad];
}

class GlobalChatLoaded extends GlobalChatState {
  final List<ChatMessageModel> chats;
  final bool hasReachedMax;
  final String searchQuery;

  const GlobalChatLoaded({
    required this.chats,
    required this.hasReachedMax,
    this.searchQuery = '',
  });

  GlobalChatLoaded copyWith({
    List<ChatMessageModel>? chats,
    bool? hasReachedMax,
    String? searchQuery,
  }) {
    return GlobalChatLoaded(
      chats: chats ?? this.chats,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [chats, hasReachedMax, searchQuery];
}

class GlobalChatError extends GlobalChatState {
  final String message;
  const GlobalChatError(this.message);

  @override
  List<Object?> get props => [message];
}
