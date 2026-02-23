import 'dart:convert';

import '../models/local_post_draft.dart';
import 'storage_service.dart';

class LocalPostDraftService {
  static const String _draftsKey = 'post_drafts_v2';
  static const String _legacyDraftKey = 'post_draft';

  final StorageService _storage;

  LocalPostDraftService({StorageService? storage})
    : _storage = storage ?? StorageService();

  Future<List<LocalPostDraft>> getDrafts() async {
    await _migrateLegacyDraftIfNeeded();
    final raw = _storage.getString(_draftsKey);
    if (raw == null || raw.trim().isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final drafts = decoded
          .whereType<Map>()
          .map((e) => LocalPostDraft.fromJson(Map<String, dynamic>.from(e)))
          .where((d) => d.id.isNotEmpty && d.hasContent)
          .toList();
      drafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return drafts;
    } catch (_) {
      return [];
    }
  }

  Future<LocalPostDraft?> getDraft(String id) async {
    final drafts = await getDrafts();
    for (final d in drafts) {
      if (d.id == id) return d;
    }
    return null;
  }

  Future<LocalPostDraft> upsertDraft(LocalPostDraft draft) async {
    final drafts = await getDrafts();
    final now = DateTime.now();
    final normalized = draft.copyWith(
      createdAt: draft.createdAt,
      updatedAt: now,
    );
    final index = drafts.indexWhere((d) => d.id == normalized.id);
    if (index >= 0) {
      drafts[index] = normalized;
    } else {
      drafts.add(normalized);
    }
    await _writeDrafts(drafts);
    return normalized;
  }

  Future<void> deleteDraft(String id) async {
    final drafts = await getDrafts();
    drafts.removeWhere((d) => d.id == id);
    await _writeDrafts(drafts);
  }

  Future<void> deleteAllDrafts() async {
    await _storage.remove(_draftsKey);
  }

  Future<void> _writeDrafts(List<LocalPostDraft> drafts) async {
    final payload = jsonEncode(drafts.map((d) => d.toJson()).toList());
    await _storage.setString(_draftsKey, payload);
  }

  Future<void> _migrateLegacyDraftIfNeeded() async {
    final legacy = _storage.getString(_legacyDraftKey);
    if (legacy == null || legacy.isEmpty) return;
    final current = _storage.getString(_draftsKey);
    if (current != null && current.trim().isNotEmpty) {
      await _storage.remove(_legacyDraftKey);
      return;
    }

    try {
      final parts = legacy.split('|||');
      if (parts.length < 4) {
        await _storage.remove(_legacyDraftKey);
        return;
      }
      final now = DateTime.now();
      final migrated = LocalPostDraft(
        id: 'draft_${now.microsecondsSinceEpoch}',
        title: '',
        content: parts[0],
        postType: parts[1].isEmpty ? 'Text' : parts[1],
        tags: parts[2].isNotEmpty ? parts[2].split(',') : const [],
        location: parts[3].isNotEmpty ? parts[3] : null,
        taggedPeople: const [],
        mediaPaths: const [],
        mediaTypes: const [],
        certifyHumanGenerated: false,
        createdAt: now,
        updatedAt: now,
      );
      await _writeDrafts([migrated]);
    } finally {
      await _storage.remove(_legacyDraftKey);
    }
  }
}
