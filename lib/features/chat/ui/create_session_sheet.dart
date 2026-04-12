import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/create_session_cubit.dart';
import '../cubit/create_session_state.dart';
import '../../../core/constants/app_colors.dart';
import 'package:fifgroup_android_ticketing/data/models/master_data_model.dart';
import 'package:fifgroup_android_ticketing/data/repositories/session_repository.dart';
import 'widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/form_label.dart';
import '../../../core/widgets/form_text_field.dart';

class CreateSessionSheet extends StatefulWidget {
  const CreateSessionSheet({super.key});

  @override
  State<CreateSessionSheet> createState() => _CreateSessionSheetState();
}

class _CreateSessionSheetState extends State<CreateSessionSheet> {
  int? _selectedCategoryId;
  MasterDataModel? _selectedCategoryModel;

  int? _selectedSubCategoryId;
  MasterDataModel? _selectedSubCategoryModel;

  int? _selectedTopicId;
  MasterDataModel? _selectedTopicModel;

  int? _selectedResolverId;
  MasterDataModel? _selectedResolverModel;

  final TextEditingController _noApplController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final SessionRepository _sessionRepo = SessionRepository();
  
  String? _submitError;

  @override
  void dispose() {
    _noApplController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context, bool isUniqueIdRequired) {
    setState(() => _submitError = null);
    if (_formKey.currentState!.validate()) {
      if (_selectedCategoryId == null ||
          _selectedSubCategoryId == null ||
          _selectedResolverId == null) {
        _showErrorSnack(
          context,
          'Kategori, Sub Kategori, dan Pencarian Resolver harus dipilih.',
        );
        return;
      }
      if (!isUniqueIdRequired && _selectedTopicId == null) {
        _showErrorSnack(context, 'Silakan pilih topik sesi.');
        return;
      }

      context.read<CreateSessionCubit>().submitSession({
        'category_id': _selectedCategoryId,
        'sub_category_id': _selectedSubCategoryId,
        'topic_id': _selectedTopicId,
        'resolver_id': _selectedResolverId,
        'no_appl': _noApplController.text.isNotEmpty
            ? _noApplController.text
            : null,
        'description': _descController.text,
      });
    }
  }

  void _showErrorSnack(BuildContext context, String text) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CreateSessionCubit, CreateSessionState>(
      listener: (context, state) {
        if (state is CreateSessionSuccess) {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context, true);
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Sesi berhasil dibuat!'),
              backgroundColor: AppColors.success,
            ),
          );
        } else if (state is CreateSessionError && state.isDuringSubmit) {
          setState(() {
            _submitError = state.message;
          });
        }
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        padding: EdgeInsets.only(
          top: 24,
          left: 24,
          right: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        child: BlocBuilder<CreateSessionCubit, CreateSessionState>(
          builder: (context, state) {
            if (state is CreateSessionInitial ||
                state is CreateSessionLoadingMasterData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is CreateSessionError && !state.isDuringSubmit) {
              return Center(
                child: Text(
                  state.message,
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            if (state is CreateSessionFormState) {
              bool isSubmitting = state is CreateSessionSubmitting;
              final isUniqueRequired = state.isUniqueIdRequired;

              return Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "NEW ENTRY",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Create New Session",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_submitError != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _submitError!,
                                        style: const TextStyle(color: Colors.red, fontSize: 13, height: 1.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            FormLabel(text: "CATEGORY"),
                            SearchableDropdownField(
                              hintText: "Select category",
                              selectedItem: _selectedCategoryModel,
                              onSearch: (keyword) => _sessionRepo.getCategories(search: keyword),
                              onChanged: (item) {
                                if (item != null && item.id != _selectedCategoryId) {
                                  setState(() {
                                    _selectedCategoryId = item.id;
                                    _selectedCategoryModel = item;
                                    _selectedSubCategoryId = null;
                                    _selectedSubCategoryModel = null;
                                    _selectedTopicId = null;
                                    _selectedTopicModel = null;
                                    _selectedResolverId = null;
                                    _selectedResolverModel = null;
                                    _noApplController.clear();
                                    _descController.clear();
                                  });
                                  context.read<CreateSessionCubit>().onCategorySelected(item.id);
                                }
                              },
                            ),
                            const SizedBox(height: 20),

                            if (_selectedCategoryId != null) ...[
                              FormLabel(text: "SUB-CATEGORY"),
                              SearchableDropdownField(
                                hintText: "Select sub-category",
                                selectedItem: _selectedSubCategoryModel,
                                onSearch: (keyword) => _sessionRepo.getSubCategories(_selectedCategoryId!, search: keyword),
                                onChanged: (item) {
                                  if (item != null && item.id != _selectedSubCategoryId) {
                                    setState(() {
                                      _selectedSubCategoryId = item.id;
                                      _selectedSubCategoryModel = item;
                                      _selectedTopicId = null;
                                      _selectedTopicModel = null;
                                      _noApplController.clear();
                                    });
                                    context.read<CreateSessionCubit>().onSubCategorySelected(item);
                                  }
                                },
                              ),
                              const SizedBox(height: 20),
                            ],

                            if (_selectedSubCategoryId != null) ...[
                              // TOPIC ATAU UNIQUE NUMBER
                              if (isUniqueRequired) ...[
                                FormLabel(text: "UNIQUE NUMBER"),
                                FormTextField(
                                  controller: _noApplController,
                                  hintText: "e.g. #REF-9921",
                                  validator: (v) => v!.isEmpty
                                      ? "Nomor aplikasi wajib diisi"
                                      : null,
                                ),
                              ] else ...[
                                FormLabel(text: "TOPIC"),
                                SearchableDropdownField(
                                  hintText: "Brief description of the session",
                                  selectedItem: _selectedTopicModel,
                                  onSearch: (keyword) => _sessionRepo.getTopics(_selectedSubCategoryId!, search: keyword),
                                  onChanged: (item) {
                                    setState(() {
                                      if (item != null) {
                                        _selectedTopicId = item.id;
                                        _selectedTopicModel = item;
                                      }
                                    });
                                  },
                                ),
                              ],
                              const SizedBox(height: 20),

                              // DESKRIPSI
                              FormLabel(text: "DESCRIPTION/MESSAGE"),
                              FormTextField(
                                controller: _descController,
                                hintText: "Describe the issue...",
                                maxLines: 3,
                                validator: (val) => val == null || val.isEmpty
                                    ? "Deskripsi wajib diisi"
                                    : null,
                              ),
                              const SizedBox(height: 20),

                              // RESOLVER
                              FormLabel(text: "RESOLVER SEARCH"),
                              SearchableDropdownField(
                                hintText: "Search team members...",
                                selectedItem: _selectedResolverModel,
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: AppColors.primary,
                                ),
                                onSearch: (keyword) => _sessionRepo.getResolvers(_selectedCategoryId!, search: keyword),
                                onChanged: (item) {
                                  setState(() {
                                    if (item != null) {
                                      _selectedResolverId = item.id;
                                      _selectedResolverModel = item;
                                    }
                                  });
                                },
                              ),
                            ],

                            const SizedBox(height: 48), // Bottom padding
                          ],
                        ),
                      ),
                    ),
                    if (_selectedSubCategoryId != null)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () => _submit(context, isUniqueRequired),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "Launch Session",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

}
