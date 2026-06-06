import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:fifgroup_android_ticketing/data/models/session_model.dart';
import '../../cubit/session_action_cubit.dart';
import '../../cubit/session_action_state.dart';

class RatingDialog extends StatefulWidget {
  final SessionModel session;

  const RatingDialog({super.key, required this.session});

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _rating = 0;
  final TextEditingController _feedbackController = TextEditingController();

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan berikan rating (1–5 bintang) terlebih dahulu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    context.read<SessionActionCubit>().submitRating(
          widget.session.id,
          _rating,
          _feedbackController.text.trim().isEmpty
              ? null
              : _feedbackController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SessionActionCubit, SessionActionState>(
      listener: (context, state) {
        if (state is SessionActionSuccess && state.actionType == 'submit_rating') {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: BlocBuilder<SessionActionCubit, SessionActionState>(
            builder: (context, state) {
              final isLoading = state is SessionActionLoading;

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Icon header
                    Container(
                      width: 60,
                      height: 60,
                      margin: const EdgeInsets.only(bottom: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.star_rate_rounded,
                        color: Colors.amber,
                        size: 36,
                      ),
                    ),

                    const Text(
                      'Beri Penilaian',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Bagaimana pengalaman Anda pada sesi #${widget.session.ticketNumber.substring(0, 8)}?',
                      style:
                          const TextStyle(fontSize: 13, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Star rating
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: isLoading
                              ? null
                              : () => setState(() => _rating = index + 1),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              index < _rating ? Icons.star : Icons.star_border,
                              color: index < _rating
                                  ? Colors.amber
                                  : Colors.grey.shade300,
                              size: 40,
                            ),
                          ),
                        );
                      }),
                    ),

                    if (_rating > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        ['', 'Sangat Kurang', 'Kurang', 'Cukup', 'Baik',
                            'Sangat Baik'][_rating],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _rating >= 4
                              ? Colors.green
                              : _rating >= 3
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 18),

                    // Feedback input
                    TextField(
                      controller: _feedbackController,
                      enabled: !isLoading,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Tulis komentar/feedback (opsional)',
                        hintStyle: const TextStyle(fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                isLoading ? null : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            child: const Text('Nanti',
                                style: TextStyle(color: Colors.grey)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Kirim Penilaian',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
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
