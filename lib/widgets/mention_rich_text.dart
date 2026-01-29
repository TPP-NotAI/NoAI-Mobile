import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../repositories/mention_repository.dart';
import '../screens/user_detail_screen.dart';
import '../utils/mention_text_parser.dart';

/// Navigates to the profile of a mentioned user by resolving their username.
Future<void> navigateToMentionedUser(
  BuildContext context,
  String username,
) async {
  final mentionRepo = MentionRepository();
  final results = await mentionRepo.searchUsers(username, limit: 1);
  if (results.isNotEmpty && context.mounted) {
    final data = results.first;
    final user = User(
      id: data['user_id'] as String,
      username: data['username'] as String? ?? username,
      displayName: data['display_name'] as String? ?? username,
      avatar: data['avatar_url'] as String?,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserDetailScreen(user: user)),
    );
  }
}

/// Renders text with @mentions styled and tappable.
class MentionRichText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? mentionStyle;
  final int? maxLines;
  final TextOverflow? overflow;
  final void Function(String username)? onMentionTap;

  const MentionRichText({
    super.key,
    required this.text,
    this.style,
    this.mentionStyle,
    this.maxLines,
    this.overflow,
    this.onMentionTap,
  });

  @override
  State<MentionRichText> createState() => _MentionRichTextState();
}

class _MentionRichTextState extends State<MentionRichText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dispose old recognizers before rebuilding
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final segments = parseMentions(widget.text);
    final defaultMentionStyle = widget.style?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ) ??
        TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        );

    final spans = segments.map((seg) {
      if (seg.isMention && widget.onMentionTap != null) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () => widget.onMentionTap!(seg.username!);
        _recognizers.add(recognizer);
        return TextSpan(
          text: seg.text,
          style: widget.mentionStyle ?? defaultMentionStyle,
          recognizer: recognizer,
        );
      }
      return TextSpan(text: seg.text, style: widget.style);
    }).toList();

    return Text.rich(
      TextSpan(children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow ?? TextOverflow.clip,
    );
  }
}
