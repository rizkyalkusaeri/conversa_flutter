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

  /// Buat thread baru.
  ///
  /// [levelIds] — jabatan yang bisa melihat thread (opsional, kosong = publik)
  /// [visibleUserIds] — user spesifik yang bisa melihat thread (opsional)
  Future<void> createThread({
    required String content,
    List<File>? attachments,
    List<int>? levelIds,
    List<int>? visibleUserIds,
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

      // Kirim jabatan yang ditarget (multi-value array)
      if (levelIds != null && levelIds.isNotEmpty) {
        for (int i = 0; i < levelIds.length; i++) {
          map['levels[$i]'] = levelIds[i];
        }
      }

      // Kirim user spesifik yang ditarget (multi-value array)
      if (visibleUserIds != null && visibleUserIds.isNotEmpty) {
        for (int i = 0; i < visibleUserIds.length; i++) {
          map['visible_users[$i]'] = visibleUserIds[i];
        }
      }

      final formData = FormData.fromMap(map);
      await _repository.createThread(formData);

      emit(const CreateThreadSuccess('Thread berhasil dipublikasikan.'));
    } catch (e) {
      emit(CreateThreadError(
          e.toString().replaceFirst('Exception: ', '')));
    }
  }

  /// Update thread yang sudah ada.
  ///
  /// [levelIds] — jabatan yang bisa melihat thread (opsional)
  /// [visibleUserIds] — user spesifik yang bisa melihat thread (opsional)
  Future<void> updateThread({
    required String uuid,
    required String content,
    List<File>? newAttachments,
    List<int>? deleteAttachmentIds,
    List<int>? levelIds,
    List<int>? visibleUserIds,
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

      // Kirim jabatan yang ditarget (sync — kosong = hapus semua target)
      if (levelIds != null) {
        if (levelIds.isEmpty) {
          // Kirim array kosong agar backend sync & hapus semua level
          map['levels'] = <int>[];
        } else {
          for (int i = 0; i < levelIds.length; i++) {
            map['levels[$i]'] = levelIds[i];
          }
        }
      }

      // Kirim user spesifik yang ditarget
      if (visibleUserIds != null) {
        if (visibleUserIds.isEmpty) {
          map['visible_users'] = <int>[];
        } else {
          for (int i = 0; i < visibleUserIds.length; i++) {
            map['visible_users[$i]'] = visibleUserIds[i];
          }
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

  /// Reset state ke initial
  void reset() {
    emit(CreateThreadInitial());
  }
}
