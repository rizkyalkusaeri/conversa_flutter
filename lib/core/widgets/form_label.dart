import 'package:flutter/material.dart';

class FormLabel extends StatelessWidget {
  final String text;
  final bool optional;

  const FormLabel({
    super.key,
    required this.text,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280), // Cool gray label
              letterSpacing: 0.5,
            ),
          ),
          if (optional)
            const Text(
              "OPTIONAL",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9CA3AF),
              ),
            ),
        ],
      ),
    );
  }
}
