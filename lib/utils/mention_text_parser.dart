/// Represents one segment of parsed text.
class MentionSegment {
  final String text;
  final bool isMention;
  final bool isHashtag;
  final String? username;
  final String? hashtag;

  const MentionSegment({
    required this.text,
    this.isMention = false,
    this.isHashtag = false,
    this.username,
    this.hashtag,
  });
}

/// Parse [content] into a list of [MentionSegment]s.
///
/// Supports both mentions (`@user`) and hashtags (`#topic`).
List<MentionSegment> parseMentions(String content) {
  final regex = RegExp(r'([@#])([A-Za-z0-9_]+)');
  final segments = <MentionSegment>[];
  int lastEnd = 0;

  for (final match in regex.allMatches(content)) {
    if (match.start > lastEnd) {
      segments.add(MentionSegment(text: content.substring(lastEnd, match.start)));
    }

    final symbol = match.group(1);
    final value = match.group(2);

    if (symbol == '@' && value != null) {
      segments.add(
        MentionSegment(
          text: match.group(0)!,
          isMention: true,
          username: value,
        ),
      );
    } else if (symbol == '#' && value != null) {
      segments.add(
        MentionSegment(
          text: match.group(0)!,
          isHashtag: true,
          hashtag: value,
        ),
      );
    }

    lastEnd = match.end;
  }

  if (lastEnd < content.length) {
    segments.add(MentionSegment(text: content.substring(lastEnd)));
  }

  return segments;
}
