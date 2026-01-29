/// Represents one segment of parsed text.
class MentionSegment {
  final String text;
  final bool isMention;
  final String? username;

  const MentionSegment({
    required this.text,
    this.isMention = false,
    this.username,
  });
}

/// Parse [content] into a list of [MentionSegment]s.
///
/// Mention pattern: `@(\w+)` — same regex as
/// `MentionRepository.extractMentions()`.
List<MentionSegment> parseMentions(String content) {
  final regex = RegExp(r'@(\w+)');
  final segments = <MentionSegment>[];
  int lastEnd = 0;

  for (final match in regex.allMatches(content)) {
    // Plain text before this mention
    if (match.start > lastEnd) {
      segments.add(MentionSegment(text: content.substring(lastEnd, match.start)));
    }

    // The mention itself (e.g. "@alice")
    segments.add(MentionSegment(
      text: match.group(0)!,
      isMention: true,
      username: match.group(1)!,
    ));

    lastEnd = match.end;
  }

  // Remaining plain text after the last mention
  if (lastEnd < content.length) {
    segments.add(MentionSegment(text: content.substring(lastEnd)));
  }

  return segments;
}
