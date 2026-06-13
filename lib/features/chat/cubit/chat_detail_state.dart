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
  final bool isUploadingAttachment; // true hanya saat ada file/gambar yang sedang diupload
  final String? submitError;
  final int submitErrorTimestamp;
  final String searchQuery;
  // Multi-file upload progress: jumlah total file dalam antrian & yang sudah terkirim
  final int uploadingCount;
  final int uploadedCount;

  const ChatDetailLoaded({
    required this.session,
    required this.chats,
    required this.hasReachedMax,
    this.isSubmitting = false,
    this.isUploadingAttachment = false,
    this.submitError,
    this.submitErrorTimestamp = 0,
    this.searchQuery = '',
    this.uploadingCount = 0,
    this.uploadedCount = 0,
  });

  ChatDetailLoaded copyWith({
    SessionModel? session,
    List<ChatMessageModel>? chats,
    bool? hasReachedMax,
    bool? isSubmitting,
    bool? isUploadingAttachment,
    String? submitError,
    int? submitErrorTimestamp,
    String? searchQuery,
    int? uploadingCount,
    int? uploadedCount,
  }) {
    return ChatDetailLoaded(
      session: session ?? this.session,
      chats: chats ?? this.chats,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isUploadingAttachment: isUploadingAttachment ?? this.isUploadingAttachment,
      submitError: submitError,
      submitErrorTimestamp: submitErrorTimestamp ?? this.submitErrorTimestamp,
      searchQuery: searchQuery ?? this.searchQuery,
      uploadingCount: uploadingCount ?? this.uploadingCount,
      uploadedCount: uploadedCount ?? this.uploadedCount,
    );
  }

  @override
  List<Object?> get props => [
        session,
        chats,
        hasReachedMax,
        isSubmitting,
        isUploadingAttachment,
        submitError,
        submitErrorTimestamp,
        searchQuery,
        uploadingCount,
        uploadedCount,
      ];
}

class ChatDetailError extends ChatDetailState {
  final String message;
  const ChatDetailError(this.message);

  @override
  List<Object?> get props => [message];
}
