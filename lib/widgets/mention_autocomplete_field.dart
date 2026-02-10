import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../repositories/mention_repository.dart';

/// A [TextField] wrapper that shows @mention autocomplete suggestions.
///
/// Drop-in replacement for [TextField] — forwards all standard properties.
/// When the user types `@` followed by characters, an overlay dropdown appears
/// above the field with matching users. Selecting a user inserts `@username `
/// at the cursor position.
class MentionAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextStyle? style;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final TextCapitalization textCapitalization;

  const MentionAutocompleteField({
    super.key,
    required this.controller,
    this.focusNode,
    this.decoration,
    this.style,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.textInputAction,
    this.onSubmitted,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<MentionAutocompleteField> createState() =>
      _MentionAutocompleteFieldState();
}

class _MentionAutocompleteFieldState extends State<MentionAutocompleteField> {
  final MentionRepository _mentionRepository = MentionRepository();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  Timer? _debounce;

  List<Map<String, dynamic>> _suggestions = [];
  int _mentionStartIndex = -1;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    widget.focusNode?.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant MentionAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocusChanged);
      widget.focusNode?.addListener(_onFocusChanged);
    }
  }

  void _onFocusChanged() {
    if (widget.focusNode != null && !widget.focusNode!.hasFocus) {
      // Delay hiding so tap on overlay can register first
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted &&
            widget.focusNode != null &&
            !widget.focusNode!.hasFocus) {
          _hideOverlay();
        }
      });
    }
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      _hideOverlay();
      return;
    }
    final cursorPos = selection.baseOffset;
    if (cursorPos < 0 || cursorPos > text.length) {
      _hideOverlay();
      return;
    }

    final textBeforeCursor = text.substring(0, cursorPos);
    final match = RegExp(r'(?:^|\s)@(\w*)$').firstMatch(textBeforeCursor);

    if (match != null) {
      final query = match.group(1)!;
      // Calculate the position of '@' in the original text
      final matchedStr = match.group(0)!;
      _mentionStartIndex = match.start +
          (matchedStr.startsWith('@') ? 0 : 1); // skip leading whitespace

      _debounce?.cancel();
      if (query.isEmpty) {
        _hideOverlay();
        return;
      }
      _debounce = Timer(const Duration(milliseconds: 300), () {
        _searchUsers(query);
      });
    } else {
      _debounce?.cancel();
      _hideOverlay();
      _mentionStartIndex = -1;
    }
  }

  Future<void> _searchUsers(String query) async {
    if (!mounted) return;

    Set<String> blockedUserIds = {};
    Set<String> blockedByUserIds = {};
    Set<String> mutedUserIds = {};
    try {
      final userProvider = context.read<UserProvider>();
      blockedUserIds = userProvider.blockedUserIds;
      blockedByUserIds = userProvider.blockedByUserIds;
      mutedUserIds = userProvider.mutedUserIds;
    } catch (_) {
      // UserProvider might not be available in all contexts
    }

    final results = await _mentionRepository.searchUsers(
      query,
      limit: 5,
      blockedUserIds: blockedUserIds,
      blockedByUserIds: blockedByUserIds,
      mutedUserIds: mutedUserIds,
    );

    if (!mounted) return;

    _suggestions = results;
    if (results.isNotEmpty) {
      _showOverlay();
    } else {
      _hideOverlay();
    }
  }

  void _selectUser(Map<String, dynamic> user) {
    final username = user['username'] as String;
    final text = widget.controller.text;
    final cursorPos = widget.controller.selection.baseOffset;

    final before = text.substring(0, _mentionStartIndex);
    final after = cursorPos < text.length ? text.substring(cursorPos) : '';
    final newText = '$before@$username $after';

    widget.controller.text = newText;
    final newCursorPos = _mentionStartIndex + username.length + 2; // @username + space
    widget.controller.selection = TextSelection.collapsed(
      offset: newCursorPos.clamp(0, newText.length),
    );

    _hideOverlay();
  }

  void _showOverlay() {
    _hideOverlay();
    _overlayEntry = OverlayEntry(
      builder: (context) => _buildSuggestionsList(),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildSuggestionsList() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Positioned(
      width: 280,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.topLeft,
        followerAnchor: Alignment.bottomLeft,
        offset: const Offset(0, -4),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          color: colors.surface,
          surfaceTintColor: colors.surfaceTint,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final user = _suggestions[index];
                final avatarUrl = user['avatar_url'] as String?;
                final displayName =
                    user['display_name'] as String? ?? user['username'] as String;
                final username = user['username'] as String;

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(
                    index == 0 && index == _suggestions.length - 1
                        ? 12
                        : index == 0
                            ? 12
                            : index == _suggestions.length - 1
                                ? 12
                                : 0,
                  ),
                  onTap: () => _selectUser(user),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: colors.surfaceContainerHighest,
                          backgroundImage: avatarUrl != null
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl == null
                              ? Icon(
                                  Icons.person,
                                  size: 16,
                                  color: colors.onSurfaceVariant,
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                displayName,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colors.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '@$username',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode?.removeListener(_onFocusChanged);
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        decoration: widget.decoration,
        style: widget.style,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        maxLength: widget.maxLength,
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted,
        autofocus: widget.autofocus,
        textCapitalization: widget.textCapitalization,
      ),
    );
  }
}
