import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:fifgroup_android_ticketing/data/repositories/thread_repository.dart';
import 'create_thread_state.dart';

class CreateThreadCubit extends Cubit<CreateThreadState> {
  final ThreadRepository _repository;

  CreateThreadCubit({ThreadRepository? repository})
      : _repository = repository ?? ThreadRepository(),
        super(CreateThreadInitial());

  /// Create a new thread
  Future<void> createThread({
    required String content,
    List<File>? attachments,
  }) async {
    emit(CreateThreadLoading());

    try {
      final map = <String, dynamic>{
        'content': content,
      };

      if (attachments != null && attachments.isNotEmpty) {
        final files = <MultipartFile>[];
        for (final file in attachments) {
          files.add(await MultipartFile.fromFile(
            file.path,
            filename: file.path.split(Platform.pathSeparator).last,
          ));
        }
        map['attachments[]'] = files;
      }

      final formData = FormData.fromMap(map);
      await _repository.createThread(formData);

      emit(const CreateThreadSuccess('Thread berhasil dipublikasikan.'));
    } catch (e) {
      emit(CreateThreadError(
          e.toString().replaceFirst('Exception: ', '')));
    }
  }

  /// Update an existing thread
  Future<void> updateThread({
    required String uuid,
    required String content,
    List<File>? newAttachments,
    List<int>? deleteAttachmentIds,
  }) async {
    emit(CreateThreadLoading());

    try {
      final map = <String, dynamic>{
        'content': content,
      };

      if (newAttachments != null && newAttachments.isNotEmpty) {
        final files = <MultipartFile>[];
        for (final file in newAttachments) {
          files.add(await MultipartFile.fromFile(
            file.path,
            filename: file.path.split(Platform.pathSeparator).last,
          ));
        }
        map['attachments[]'] = files;
      }

      if (deleteAttachmentIds != null && deleteAttachmentIds.isNotEmpty) {
        for (int i = 0; i < deleteAttachmentIds.length; i++) {
          map['delete_attachment_ids[$i]'] = deleteAttachmentIds[i];
        }
      }

      final formData = FormData.fromMap(map);
      await _repository.updateThread(uuid, formData);

      emit(const CreateThreadSuccess('Thread berhasil diperbarui.'));
    } catch (e) {
      emit(CreateThreadError(
          e.toString().replaceFirst('Exception: ', '')));
    }
  }

  /// Reset state back to initial
  void reset() {
    emit(CreateThreadInitial());
  }
}
