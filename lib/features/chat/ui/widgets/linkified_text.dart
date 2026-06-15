import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkifiedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? linkStyle;

  const LinkifiedText({
    super.key,
    required this.text,
    this.style,
    this.linkStyle,
  });

  @override
  Widget build(BuildContext context) {
    // Regex matches URLs starting with http://, https://, or www.
    final RegExp urlRegExp = RegExp(
      r'(https?:\/\/[^\s]+|www\.[^\s]+)',
      caseSensitive: false,
    );

    final List<TextSpan> spans = [];
    int start = 0;

    for (final match in urlRegExp.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, match.start),
          style: style,
        ));
      }

      final String urlText = match.group(0)!;

      spans.add(TextSpan(
        text: urlText,
        style: linkStyle ??
            (style ?? const TextStyle()).copyWith(
              color: Colors.blue.shade600,
              decoration: TextDecoration.underline,
            ),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            String uriString = urlText;
            if (urlText.toLowerCase().startsWith('www.')) {
              uriString = 'https://$urlText';
            }
            final Uri? uri = Uri.tryParse(uriString);
            if (uri != null) {
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (e) {
                debugPrint('Could not launch URL: $e');
              }
            }
          },
      ));

      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: style,
      ));
    }

    if (spans.isEmpty) {
      return SelectableText(
        text,
        style: style,
      );
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      style: style,
    );
  }
}
