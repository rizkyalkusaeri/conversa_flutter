import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_config.dart';
import '../cubit/create_thread_cubit.dart';
import '../cubit/create_thread_state.dart';
import 'package:fifgroup_android_ticketing/data/models/thread_model.dart';

class CreateThreadPage extends StatefulWidget {
  final ThreadModel? editThread;

  const CreateThreadPage({super.key, this.editThread});

  @override
  State<CreateThreadPage> createState() => _CreateThreadPageState();
}

class _CreateThreadPageState extends State<CreateThreadPage> {
  final TextEditingController _contentController = TextEditingController();
  final List<File> _selectedFiles = [];
  final List<int> _deleteAttachmentIds = [];

  bool get _isEditMode => widget.editThread != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _contentController.text = widget.editThread!.content;
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CreateThreadCubit(),
      child: BlocConsumer<CreateThreadCubit, CreateThreadState>(
        listener: (context, state) {
          if (state is CreateThreadSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.success,
              ),
            );
            Navigator.pop(context, true);
          } else if (state is CreateThreadError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is CreateThreadLoading;

          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: AppColors.textDark),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                _isEditMode ? 'Edit Thread' : 'Buat Thread',
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              centerTitle: true,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: TextButton(
                    onPressed: isLoading ? null : () => _submit(context),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isEditMode ? 'Update' : 'Publish',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Content input
                  TextField(
                    controller: _contentController,
                    maxLines: null,
                    minLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Apa yang ingin kamu bagikan?',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textDark,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Existing attachments (edit mode)
                  if (_isEditMode && widget.editThread!.attachments.isNotEmpty)
                    _buildExistingAttachments(),

                  // New files preview
                  if (_selectedFiles.isNotEmpty) _buildSelectedFiles(),

                  const SizedBox(height: 16),

                  // Attachment buttons
                  _buildAttachmentActions(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExistingAttachments() {
    final remaining = widget.editThread!.attachments
        .where((a) => !_deleteAttachmentIds.contains(a.id))
        .toList();

    if (remaining.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lampiran Saat Ini',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: remaining.map((att) {
            final isImage = att.isImage;
            return Stack(
              children: [
                Container(
                  width: isImage ? 100 : null,
                  height: isImage ? 100 : null,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: isImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            '${ApiConfig.imageUrl}${att.url}',
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image),
                            ),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.attach_file,
                                size: 16,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                att.originalName ?? 'File',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _deleteAttachmentIds.add(att.id);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSelectedFiles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'File Baru',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_selectedFiles.length, (index) {
            final file = _selectedFiles[index];
            final isImage = _isImageFile(file.path);

            return Stack(
              children: [
                Container(
                  width: isImage ? 100 : null,
                  height: isImage ? 100 : null,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: isImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(file, fit: BoxFit.cover),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.attach_file,
                                size: 16,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                file.path.split(Platform.pathSeparator).last,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedFiles.removeAt(index);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAttachmentActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Text(
            'Lampiran',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              Icons.photo_outlined,
              color: AppColors.primary,
              size: 22,
            ),
            onPressed: _pickImages,
            tooltip: 'Pilih Gambar',
          ),
          IconButton(
            icon: Icon(Icons.attach_file, color: AppColors.secondary, size: 22),
            onPressed: _pickFiles,
            tooltip: 'Pilih File',
          ),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 80);

    if (images.isNotEmpty) {
      setState(() {
        _selectedFiles.addAll(images.map((xfile) => File(xfile.path)));
      });
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'jpeg',
        'png',
        'jpg',
        'pdf',
        'xls',
        'xlsx',
        'doc',
        'docx',
      ],
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFiles.addAll(
          result.files.where((f) => f.path != null).map((f) => File(f.path!)),
        );
      });
    }
  }

  void _submit(BuildContext context) {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konten thread tidak boleh kosong'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_isEditMode) {
      context.read<CreateThreadCubit>().updateThread(
        uuid: widget.editThread!.id,
        content: content,
        newAttachments: _selectedFiles.isNotEmpty ? _selectedFiles : null,
        deleteAttachmentIds: _deleteAttachmentIds.isNotEmpty
            ? _deleteAttachmentIds
            : null,
      );
    } else {
      context.read<CreateThreadCubit>().createThread(
        content: content,
        attachments: _selectedFiles.isNotEmpty ? _selectedFiles : null,
      );
    }
  }

  bool _isImageFile(String path) {
    final ext = path.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
  }
}
