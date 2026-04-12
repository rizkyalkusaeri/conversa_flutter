import 'package:equatable/equatable.dart';
import 'package:fifgroup_android_ticketing/data/models/chat_message_model.dart';
import 'package:fifgroup_android_ticketing/data/models/session_model.dart';

abstract class ChatDetailState extends Equatable {
  const ChatDetailState();

  @override
  List<Object?> get props => [];
}

class ChatDetailInitial extends ChatDetailState {}

class ChatDetailLoading extends ChatDetailState {
  final bool isFirstLoad;
  const ChatDetailLoading({this.isFirstLoad = true});
  
  @override
  List<Object?> get props => [isFirstLoad];
}

class ChatDetailLoaded extends ChatDetailState {
  final SessionModel session;
  final List<ChatMessageModel> chats;
  final bool hasReachedMax;
  final bool isSubmitting;
  final String? submitError;
  final String searchQuery;

  const ChatDetailLoaded({
    required this.session,
    required this.chats,
    required this.hasReachedMax,
    this.isSubmitting = false,
    this.submitError,
    this.searchQuery = '',
  });

  ChatDetailLoaded copyWith({
    SessionModel? session,
    List<ChatMessageModel>? chats,
    bool? hasReachedMax,
    bool? isSubmitting,
    String? submitError,
    String? searchQuery,
  }) {
    return ChatDetailLoaded(
      session: session ?? this.session,
      chats: chats ?? this.chats,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: submitError,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [session, chats, hasReachedMax, isSubmitting, submitError, searchQuery];
}

class ChatDetailError extends ChatDetailState {
  final String message;
  const ChatDetailError(this.message);

  @override
  List<Object?> get props => [message];
}
