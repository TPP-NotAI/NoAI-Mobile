/// Lightweight input payload for creating a story item.
class StoryMediaInput {
  final String url;
  /// Either `image` or `video`.
  final String mediaType;

  const StoryMediaInput({
    required this.url,
    required this.mediaType,
  });
}
