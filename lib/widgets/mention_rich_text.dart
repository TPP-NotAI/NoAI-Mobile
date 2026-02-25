import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
  final TextStyle? hashtagStyle;
  final int? maxLines;
  final TextOverflow? overflow;
  final void Function(String username)? onMentionTap;
  final void Function(String hashtag)? onHashtagTap;

  const MentionRichText({
    super.key,
    required this.text,
    this.style,
    this.mentionStyle,
    this.hashtagStyle,
    this.maxLines,
    this.overflow,
    this.onMentionTap,
    this.onHashtagTap,
  });

  @override
  State<MentionRichText> createState() => _MentionRichTextState();
}

class _MentionRichTextState extends State<MentionRichText> {
  final List<TapGestureRecognizer> _recognizers = [];
  static final RegExp _urlRegex = RegExp(
    r'((?:https?:\/\/|www\.)[^\s<]+)',
    caseSensitive: false,
  );

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
    final defaultHashtagStyle = widget.style?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ) ??
        TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        );
    final defaultLinkStyle = widget.style?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
        ) ??
        TextStyle(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
        );

    final spans = <InlineSpan>[];
    for (final seg in segments) {
      if (seg.isMention && widget.onMentionTap != null) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () => widget.onMentionTap!(seg.username!);
        _recognizers.add(recognizer);
        spans.add(TextSpan(
          text: seg.text,
          style: widget.mentionStyle ?? defaultMentionStyle,
          recognizer: recognizer,
        ));
        continue;
      }
      if (seg.isHashtag && widget.onHashtagTap != null) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () => widget.onHashtagTap!(seg.hashtag!);
        _recognizers.add(recognizer);
        spans.add(TextSpan(
          text: seg.text,
          style: widget.hashtagStyle ?? defaultHashtagStyle,
          recognizer: recognizer,
        ));
        continue;
      }
      spans.addAll(
        _buildTextAndUrlSpans(
          seg.text,
          baseStyle: widget.style,
          linkStyle: defaultLinkStyle,
        ),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow ?? TextOverflow.clip,
    );
  }

  List<InlineSpan> _buildTextAndUrlSpans(
    String text, {
    TextStyle? baseStyle,
    required TextStyle linkStyle,
  }) {
    if (text.isEmpty) return const [];

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in _urlRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start), style: baseStyle));
      }

      final rawUrl = match.group(0)!;
      final cleaned = _trimTrailingPunctuation(rawUrl);
      final trailing = rawUrl.substring(cleaned.length);

      final recognizer = TapGestureRecognizer()
        ..onTap = () => _openUrl(cleaned);
      _recognizers.add(recognizer);

      spans.add(
        TextSpan(
          text: cleaned,
          style: linkStyle,
          recognizer: recognizer,
        ),
      );

      if (trailing.isNotEmpty) {
        spans.add(TextSpan(text: trailing, style: baseStyle));
      }

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
    }

    return spans;
  }

  String _trimTrailingPunctuation(String input) {
    var value = input;
    while (value.isNotEmpty &&
        RegExp(r'[)\].,!?:;]+$').hasMatch(value)) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  Future<void> _openUrl(String rawUrl) async {
    final normalized = rawUrl.toLowerCase().startsWith('http')
        ? rawUrl
        : 'https://$rawUrl';
    final uri = Uri.tryParse(normalized);
    if (uri == null) return;

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Fail silently to avoid breaking text rendering interactions.
    }
  }
}
