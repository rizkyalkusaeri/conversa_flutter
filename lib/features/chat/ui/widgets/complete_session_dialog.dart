import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:fifgroup_android_ticketing/data/models/session_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cubit/session_action_cubit.dart';
import '../../cubit/session_action_state.dart';

class CompleteSessionDialog extends StatefulWidget {
  final SessionModel session;

  const CompleteSessionDialog({super.key, required this.session});

  @override
  State<CompleteSessionDialog> createState() => _CompleteSessionDialogState();
}

class _CompleteSessionDialogState extends State<CompleteSessionDialog> {
  int _rating = 0;
  final TextEditingController _feedbackController = TextEditingController();

  void _submit() {
    if (!widget.session.isHaveUniqueId && _rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan berikan rating terlebih dahulu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    context.read<SessionActionCubit>().completeSession(
      widget.session.id,
      rating: widget.session.isHaveUniqueId ? null : _rating,
      feedback: widget.session.isHaveUniqueId ? null : _feedbackController.text,
    );
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SessionActionCubit, SessionActionState>(
      listener: (context, state) {
        if (state is SessionActionSuccess) {
          Navigator.of(context).pop(state.session); 
        } else if (state is SessionActionError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: BlocBuilder<SessionActionCubit, SessionActionState>(
            builder: (context, state) {
              final isLoading = state is SessionActionLoading;

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Selesaikan Sesi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    
                    if (widget.session.isHaveUniqueId) ...[
                      const Text(
                        'Apakah Anda yakin ingin menyelesaikan sesi ini? Status tiket akan berubah menjadi CLOSED.',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
                      const Text(
                        'Berikan penilaian Anda untuk sesi ini',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return IconButton(
                            onPressed: isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _rating = index + 1;
                                    });
                                  },
                            icon: Icon(
                              index < _rating ? Icons.star : Icons.star_border,
                              color: index < _rating ? Colors.amber : Colors.grey,
                              size: 36,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _feedbackController,
                        enabled: !isLoading,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Tulis feedback (opsional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                          child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Selesaikan', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
