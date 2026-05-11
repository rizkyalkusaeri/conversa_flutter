import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_config.dart';
import '../cubit/create_thread_cubit.dart';
import '../cubit/create_thread_state.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../chat/ui/widgets/image_preview_dialog.dart';
import 'package:fifgroup_android_ticketing/core/network/dio_client.dart';
import 'package:fifgroup_android_ticketing/data/models/thread_model.dart';
import 'package:fifgroup_android_ticketing/data/models/master_data_model.dart';
import 'widgets/thread_target_selector.dart';

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

  // Jabatan yang ditarget — kosong = thread publik (notifikasi ke semua)
  List<int> _selectedLevelIds = [];
  // User spesifik yang ditarget — kosong = semua user jabatan terpilih
  List<int> _selectedUserIds = [];

  List<MasterDataModel> _categories = [];
  List<MasterDataModel> _subCategories = [];
  List<MasterDataModel> _topics = [];
  
  int? _selectedCategoryId;
  int? _selectedSubCategoryId;
  int? _selectedTopicId;

  bool _isLoadingCategories = false;
  bool _isLoadingSubCategories = false;
  bool _isLoadingTopics = false;

  bool get _isEditMode => widget.editThread != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _contentController.text = widget.editThread!.content;
      _selectedLevelIds = List.from(widget.editThread!.selectedLevelIds);
      _selectedUserIds = List.from(widget.editThread!.selectedUserIds);
      _selectedTopicId = widget.editThread!.topicId;
    }
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final response = await DioClient.getInstance.get('/master/categories', queryParameters: {'limit': 100});
      final items = response.data['data'] as List<dynamic>? ?? [];
      setState(() {
        _categories = items.map((e) => MasterDataModel.fromJson(e, 'category_name')).toList();
      });
    } catch (e) {
      debugPrint('Gagal load categories: $e');
    } finally {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _loadSubCategories(int categoryId) async {
    setState(() {
      _isLoadingSubCategories = true;
      _subCategories = [];
      _selectedSubCategoryId = null;
      _topics = [];
      _selectedTopicId = null;
    });
    try {
      final response = await DioClient.getInstance.get(
        '/master/sub-categories',
        queryParameters: {'category_id': categoryId, 'limit': 100},
      );
      final items = response.data['data'] as List<dynamic>? ?? [];
      setState(() {
        _subCategories = items.map((e) => MasterDataModel.fromJson(e, 'sub_category_name')).toList();
      });
    } catch (e) {
      debugPrint('Gagal load sub-categories: $e');
    } finally {
      if (mounted) setState(() => _isLoadingSubCategories = false);
    }
  }

  Future<void> _loadTopics(int subCategoryId) async {
    setState(() {
      _isLoadingTopics = true;
      _topics = [];
      _selectedTopicId = null;
    });
    try {
      final response = await DioClient.getInstance.get(
        '/master/topics',
        queryParameters: {'sub_category_id': subCategoryId, 'limit': 100},
      );
      final items = response.data['data'] as List<dynamic>? ?? [];
      setState(() {
        _topics = items.map((e) => MasterDataModel.fromJson(e, 'topic_name')).toList();
      });
    } catch (e) {
      debugPrint('Gagal load topics: $e');
    } finally {
      if (mounted) setState(() => _isLoadingTopics = false);
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

                  // ─── Cascading Selectors ──────────────────────────────────
                  if (_isLoadingCategories)
                    const _LoadingPlaceholder(label: 'Memuat kategori...')
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildDropdown(
                        label: 'Kategori',
                        value: _selectedCategoryId,
                        items: _categories,
                        onChanged: (val) {
                          setState(() => _selectedCategoryId = val);
                          if (val != null) _loadSubCategories(val);
                        },
                      ),
                    ),

                  if (_selectedCategoryId != null)
                    if (_isLoadingSubCategories)
                      const _LoadingPlaceholder(label: 'Memuat sub kategori...')
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildDropdown(
                          label: 'Sub Kategori',
                          value: _selectedSubCategoryId,
                          items: _subCategories,
                          onChanged: (val) {
                            setState(() => _selectedSubCategoryId = val);
                            if (val != null) _loadTopics(val);
                          },
                        ),
                      ),

                  if (_selectedSubCategoryId != null)
                    if (_isLoadingTopics)
                      const _LoadingPlaceholder(label: 'Memuat topik...')
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildDropdown(
                          label: 'Topik (Opsional)',
                          value: _selectedTopicId,
                          items: _topics,
                          onChanged: (val) => setState(() => _selectedTopicId = val),
                          allowNull: true,
                          nullLabel: 'Tanpa Topik',
                        ),
                      ),
                  // ────────────────────────────────────────────────────────

                  // ─── Jabatan & User Spesifik selector ───────────────────
                  ThreadTargetSelector(
                    initialLevelIds: _selectedLevelIds,
                    initialUserIds: _selectedUserIds,
                    onLevelsChanged: (ids) {
                      setState(() => _selectedLevelIds = ids);
                    },
                    onUsersChanged: (ids) {
                      setState(() => _selectedUserIds = ids);
                    },
                  ),
                  // ────────────────────────────────────────────────────────

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
                      : _isVideoFile(file.path)
                          ? Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(20),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.videocam,
                                      color: AppColors.primary),
                                  SizedBox(height: 4),
                                  Text(
                                    'Video',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
            icon: const Icon(
              Icons.attach_file,
              color: AppColors.primary,
              size: 22,
            ),
            onPressed: _showAttachmentOptions,
            tooltip: 'Tambah Lampiran',
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                  title: const Text('Ambil Foto'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _takePhoto();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.videocam, color: AppColors.primary),
                  title: const Text('Ambil Video'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _takeVideo();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.perm_media_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text('Galeri Media (Foto & Video)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickMedia();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.insert_drive_file,
                    color: AppColors.primary,
                  ),
                  title: const Text('Dokumen'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickFiles();
                  },
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _takePhoto() async {
    final messenger = ScaffoldMessenger.of(context);

    // Request Permission
    var status = await Permission.camera.status;
    if (status.isDenied) {
      status = await Permission.camera.request();
    }

    if (status.isPermanentlyDenied) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Akses kamera ditolak permanen. Silakan aktifkan di pengaturan.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!status.isGranted) return;

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );

    if (image != null) {
      if (!mounted) return;

      final result = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => ImagePreviewDialog(
              imagePath: image.path,
              onSend: () => Navigator.pop(ctx, true),
              onRetake: () => Navigator.pop(ctx, false),
            ),
      );

      if (result == true) {
        setState(() {
          _selectedFiles.add(File(image.path));
        });
      } else if (result == false) {
        _takePhoto();
      }
    }
  }

  Future<void> _takeVideo() async {
    final status = await Permission.camera.status;
    if (status.isDenied) await Permission.camera.request();
    if (!status.isGranted) return;

    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.camera);
    if (video != null) {
      setState(() {
        _selectedFiles.add(File(video.path));
      });
    }
  }

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final media = await picker.pickMultipleMedia();

    if (media.isNotEmpty) {
      setState(() {
        _selectedFiles.addAll(media.map((xfile) => File(xfile.path)));
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
        deleteAttachmentIds:
            _deleteAttachmentIds.isNotEmpty ? _deleteAttachmentIds : null,
        levelIds: _selectedLevelIds,
        visibleUserIds: _selectedUserIds,
        topicId: _selectedTopicId,
        clearTopic: _selectedTopicId == null,
      );
    } else {
      context.read<CreateThreadCubit>().createThread(
        content: content,
        attachments: _selectedFiles.isNotEmpty ? _selectedFiles : null,
        levelIds: _selectedLevelIds,
        visibleUserIds: _selectedUserIds,
        topicId: _selectedTopicId,
      );
    }
  }

  bool _isVideoFile(String path) {
    final ext = path.toLowerCase().split('.').last;
    return ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext);
  }

  bool _isImageFile(String path) {
    final ext = path.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
  }

  Widget _buildDropdown({
    required String label,
    required int? value,
    required List<MasterDataModel> items,
    required ValueChanged<int?> onChanged,
    bool allowNull = false,
    String nullLabel = 'Pilih...',
  }) {
    return DropdownButtonFormField<int>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      items: [
        if (allowNull || value == null)
          DropdownMenuItem<int>(
            value: null,
            child: Text(
              nullLabel,
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ),
        ...items.map(
          (t) => DropdownMenuItem<int>(value: t.id, child: Text(t.text)),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  final String label;
  const _LoadingPlaceholder({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
