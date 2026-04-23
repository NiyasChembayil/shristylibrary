import 'package:flutter/material.dart';

class MentionTextEditingController extends TextEditingController {
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<InlineSpan> children = [];
    
    // User Mention: @{ID|Name}
    // Book Mention: @[ID|Name]
    // Regex explanation:
    // Group 1-3: User (@, ID|, Name)
    // Group 4-6: Book (@, ID|, Title)
    final RegExp exp = RegExp(r'(@)\{(\d+\|)([^}]+)\}|(@)\[(\d+\|)([^\]]+)\]');

    text.splitMapJoin(
      exp,
      onMatch: (Match match) {
        if (match.group(1) == '@') {
          // User Mention
          children.add(TextSpan(
            text: '@',
            style: style?.copyWith(color: const Color(0xFF6C63FF), fontWeight: FontWeight.bold),
          ));
          children.add(TextSpan(
            text: '{${match.group(2)}',
            style: style?.copyWith(color: Colors.transparent, fontSize: 0.01),
          ));
          children.add(TextSpan(
            text: match.group(3),
            style: style?.copyWith(color: const Color(0xFF6C63FF), fontWeight: FontWeight.bold),
          ));
          children.add(TextSpan(
            text: '}',
            style: style?.copyWith(color: Colors.transparent, fontSize: 0.01),
          ));
        } else if (match.group(4) == '@') {
          // Book Mention
          children.add(TextSpan(
            text: '@',
            style: style?.copyWith(color: const Color(0xFFFF6584), fontWeight: FontWeight.bold),
          ));
          children.add(TextSpan(
            text: '[${match.group(5)}',
            style: style?.copyWith(color: Colors.transparent, fontSize: 0.01),
          ));
          children.add(TextSpan(
            text: match.group(6),
            style: style?.copyWith(color: const Color(0xFFFF6584), fontWeight: FontWeight.bold),
          ));
          children.add(TextSpan(
            text: ']',
            style: style?.copyWith(color: Colors.transparent, fontSize: 0.01),
          ));
        }
        return '';
      },
      onNonMatch: (String text) {
        children.add(TextSpan(text: text, style: style));
        return '';
      },
    );

    return TextSpan(style: style, children: children);
  }
}
