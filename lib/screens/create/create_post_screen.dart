import 'dart:io';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rooverse/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image/image.dart' as img;
import 'package:rooverse/models/moderation_result.dart';
import 'package:rooverse/repositories/post_repository.dart';
import 'package:rooverse/services/ai_detection_service.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../providers/feed_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../repositories/tag_repository.dart';
import '../../repositories/mention_repository.dart';
import '../../widgets/mention_autocomplete_field.dart';
import '../../models/post.dart';
import '../../models/local_post_draft.dart';
import '../../services/supabase_service.dart';
import '../../config/supabase_config.dart';
import '../../services/local_post_draft_service.dart';
import '../../services/storage_service.dart';
import '../../services/kyc_verification_service.dart';
import '../../utils/verification_utils.dart';
import '../../widgets/verification_required_widget.dart';
import '../../config/global_keys.dart';
import '../post_detail_screen.dart';
import '../profile/edit_profile_screen.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
class CreatePostScreen extends StatefulWidget {
  final String? initialPostType;
  final VoidCallback? onPostCreated;

  const CreatePostScreen({super.key, this.initialPostType, this.onPostCreated});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final PostRepository _postRepo = PostRepository();
  final TagRepository _tagRepository = TagRepository();
  final MentionRepository _mentionRepository = MentionRepository();
  final AiDetectionService _aiDetectionService = AiDetectionService();

  // Real-time moderation state
  Timer? _textModerationTimer;
  bool _isModeratingText = false;
  ModerationResult? _textModerationResult;

  late String _postType;
  bool _isPosting = false;
  bool _certifyHumanGenerated = false;

  // Character limit constant
  static const int _maxCharacterLimit = 280;
  double _postCostRoo = 10.0; // Default posting reward in ROO
  bool _isLoadingPostCost = false;
  static const Duration _postCostCacheTtl = Duration(hours: 6);

  // Media state
  final List<File> _selectedMediaFiles = [];
  final List<String> _selectedMediaTypes = []; // 'image' or 'video'
  // Camera-created temp files that should be deleted on dispose
  final List<File> _tempCameraFiles = [];

  // Tags/Topics state
  final List<String> _selectedTags = [];
  final TextEditingController _tagController = TextEditingController();

  // Location state
  String? _selectedLocation;
  bool _isLoadingLocation = false;

  // Mentions state
  final List<Map<String, dynamic>> _taggedPeople = [];
  final TextEditingController _mentionController = TextEditingController();

  // Draft and character count state
  bool _hasUnsavedChanges = false;
  bool _isDraftLoaded = false;
  bool _isLoadingDraft = false;
  bool _isInitialLoad = true;
  int _savedDraftCount = 0;
  String? _activeDraftId;
  final StorageService _storageService = StorageService();
  late final LocalPostDraftService _draftService;
  bool _postCostLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _postType = widget.initialPostType ?? 'Text';
    _draftService = LocalPostDraftService(storage: _storageService);
    _loadCachedPostCost();
    _loadPostCost();
    _checkForSavedDraft().then((_) {
      _isInitialLoad = false;
      // Add listener after draft count check to avoid early autosave behavior.
      _contentController.addListener(_onContentChanged);
      _titleController.addListener(_onContentChanged);
    });
  }

  void _loadCachedPostCost() {
    try {
      final cached = _storageService.getString('post_cost_rc');
      final cachedTs = _storageService.getString('post_cost_rc_ts');
      if (cached != null &&
          cached.isNotEmpty &&
          cachedTs != null &&
          cachedTs.isNotEmpty) {
        final value = double.tryParse(cached);
        final ts = int.tryParse(cachedTs);
        if (value != null && value > 0 && ts != null) {
          final age = DateTime.now().difference(
            DateTime.fromMillisecondsSinceEpoch(ts),
          );
          if (age <= _postCostCacheTtl) {
            _postCostRoo = value >= 10 ? value : 10.0;
          }
        }
      }
    } catch (e) {
      debugPrint('CreatePostScreen: Failed to load cached post cost - $e');
    }
  }

  Future<void> _loadPostCost() async {
    if (_isLoadingPostCost) return;
    _isLoadingPostCost = true;
    try {
      final response = await SupabaseService().client
          .from(SupabaseConfig.platformConfigTable)
          .select('default_publish_fee_rc')
          .eq('id', 1)
          .maybeSingle();

      if (response != null) {
        final fee =
            (response['default_publish_fee_rc'] as num?)?.toDouble() ?? 10.0;
        // Post creation reward is at least 10 ROO.
        final effectiveFee = fee >= 10 ? fee : 10.0;
        if (mounted) {
          setState(() {
            _postCostRoo = effectiveFee;
          });
        }
        await _storageService.setString(
          'post_cost_rc',
          effectiveFee.toString(),
        );
        await _storageService.setString(
          'post_cost_rc_ts',
          DateTime.now().millisecondsSinceEpoch.toString(),
        );
      }
    } catch (e) {
      debugPrint('CreatePostScreen: Failed to load post cost - $e');
      if (mounted && !_postCostLoadFailed) {
        _postCostLoadFailed = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not refresh ROO posting fee. Using cached value.'.tr(context),
            ),
          ),
        );
      }
    } finally {
      _isLoadingPostCost = false;
    }
  }

  @override
  void dispose() {
    _contentController.removeListener(_onContentChanged);
    _titleController.removeListener(_onContentChanged);
    _contentController.dispose();
    _titleController.dispose();
    _tagController.dispose();
    _mentionController.dispose();
    for (final file in _tempCameraFiles) {
      file.delete().ignore();
    }
    super.dispose();
  }

  void _onContentChanged() {
    setState(() {
      _hasUnsavedChanges = true;
    });

    // Real-time moderation debouncing
    _textModerationTimer?.cancel();
    _textModerationTimer = Timer(const Duration(milliseconds: 800), () {
      _moderateCurrentText();
    });
  }

  Future<void> _moderateCurrentText() async {
    final text = _contentController.text.trim();
    if (text.isEmpty) {
      if (mounted) setState(() => _textModerationResult = null);
      return;
    }

    if (mounted) setState(() => _isModeratingText = true);

    try {
      final res = await _aiDetectionService.moderateText(text);
      if (mounted) {
        setState(() {
          _textModerationResult = res;
          _isModeratingText = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isModeratingText = false);
    }
  }

  Future<void> _pickMedia({required bool fromCamera}) async {
    try {
      if (!fromCamera) {
        final pickedMedia = await _imagePicker.pickMultipleMedia();
        if (pickedMedia.isNotEmpty) {
          final filesToAdd = <File>[];
          final typesToAdd = <String>[];

          for (final media in pickedMedia) {
            final mediaType = _detectMediaType(media.path);
            if (mediaType == null) continue;
            filesToAdd.add(File(media.path));
            typesToAdd.add(mediaType);
          }

          if (filesToAdd.isNotEmpty && mounted) {
            setState(() {
              _selectedMediaFiles.addAll(filesToAdd);
              _selectedMediaTypes.addAll(typesToAdd);
              _hasUnsavedChanges = true;
            });

            for (var i = 0; i < filesToAdd.length; i++) {
              unawaited(_moderateMedia(filesToAdd[i], typesToAdd[i]));
            }
          }
        }
        return;
      }

      if (_postType == 'Photo') {
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.camera,
        );

        if (image != null) {
          File finalImage = File(image.path);

          // If from camera, copy to a permanent location to ensure file accessibility
          // Camera images are often stored in temporary cache that may be cleared
          try {
            debugPrint(
              'CreatePostScreen: Copying camera image to stable path...',
            );
            final tempDir = Directory.systemTemp;
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final permanentPath = '${tempDir.path}/camera_image_$timestamp.jpg';
            final permanentFile = await finalImage.copy(permanentPath);
            finalImage = permanentFile;
            _tempCameraFiles.add(permanentFile);
            debugPrint(
              'CreatePostScreen: Saved camera image to: $permanentPath',
            );
          } catch (e) {
            debugPrint('CreatePostScreen: Error copying camera image - $e');
          }

          if (mounted) {
            setState(() {
              _selectedMediaFiles.add(finalImage);
              _selectedMediaTypes.add('image');
              _hasUnsavedChanges = true;
            });
          }

          unawaited(_moderateMedia(finalImage, 'image'));
        }
      } else if (_postType == 'Video') {
        final XFile? video = fromCamera
            ? await _imagePicker.pickVideo(source: ImageSource.camera)
            : await _imagePicker.pickVideo(source: ImageSource.gallery);

        if (video != null) {
          File videoFile = File(video.path);

          // If from camera, copy to a permanent location to ensure file accessibility
          if (fromCamera) {
            try {
              debugPrint(
                'CreatePostScreen: Copying camera video to stable path...',
              );
              // Create a permanent file path in the app's temporary directory
              final tempDir = Directory.systemTemp;
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              final permanentPath =
                  '${tempDir.path}/camera_video_$timestamp.mp4';

              // Write to permanent location
              final permanentFile = await videoFile.copy(permanentPath);

              videoFile = permanentFile;
              _tempCameraFiles.add(permanentFile);
              debugPrint(
                'CreatePostScreen: Saved camera video to: $permanentPath',
              );
            } catch (e) {
              debugPrint('CreatePostScreen: Error copying camera video - $e');
              // Continue with original file if copy fails
            }
          }

          if (mounted) {
            setState(() {
              _selectedMediaFiles.add(videoFile);
              _selectedMediaTypes.add('video');
              _hasUnsavedChanges = true;
            });
          }

          unawaited(_moderateMedia(videoFile, 'video'));
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick media: $e'.tr(context))));
    }
  }

  String? _detectMediaType(String path) {
    final lowerPath = path.toLowerCase();
    const videoExtensions = {
      '.mp4',
      '.mov',
      '.avi',
      '.mkv',
      '.webm',
      '.m4v',
      '.3gp',
    };

    for (final ext in videoExtensions) {
      if (lowerPath.endsWith(ext)) return 'video';
    }

    return 'image';
  }

  Future<void> _moderateMedia(File file, String type) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Checking content safety...'.tr(context)),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final res = type == 'image'
          ? await _aiDetectionService.moderateImage(file)
          : await _aiDetectionService.moderateVideo(file);

      if (res != null && res.flagged) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                SizedBox(width: 8),
                Text('Content Warning'.tr(context)),
              ],
            ),
            content: Text('Our AI detected potentially harmful content in your ${type}: ${res.details ?? "violation detected"}.\n\n'
              'If you post this, it may be hidden or your account could be flagged.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('I Understand'.tr(context)),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  final index = _selectedMediaFiles.indexOf(file);
                  if (index >= 0) {
                    _removeMedia(index);
                  }
                },
                child: Text('Remove Media'.tr(context)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Proactive moderation failed: $e');
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _selectedMediaFiles.removeAt(index);
      _selectedMediaTypes.removeAt(index);
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied');
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      // Use reverse geocoding to get human-readable address
      String locationName;
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          // Build a readable location string
          final parts = <String>[];
          if (place.locality != null && place.locality!.isNotEmpty) {
            parts.add(place.locality!);
          } else if (place.subLocality != null &&
              place.subLocality!.isNotEmpty) {
            parts.add(place.subLocality!);
          }
          if (place.administrativeArea != null &&
              place.administrativeArea!.isNotEmpty) {
            parts.add(place.administrativeArea!);
          }
          if (place.country != null && place.country!.isNotEmpty) {
            parts.add(place.country!);
          }
          locationName = parts.isNotEmpty
              ? parts.join(', ')
              : '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        } else {
          locationName =
              '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        }
      } catch (e) {
        // Fallback to coordinates if geocoding fails
        debugPrint('Geocoding failed: $e');
        locationName =
            '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      }

      setState(() {
        _selectedLocation = locationName;
        _hasUnsavedChanges = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to get location: $e'.tr(context))));
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _LocationPickerSheet(
        currentLocation: _selectedLocation,
        isLoading: _isLoadingLocation,
        onGetCurrentLocation: _getCurrentLocation,
        onLocationSelected: (location) {
          setState(() {
            _selectedLocation = location;
            _hasUnsavedChanges = true;
          });
          Navigator.pop(context);
        },
        onClear: () {
          setState(() {
            _selectedLocation = null;
            _hasUnsavedChanges = true;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showTopicsPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _TopicsPickerSheet(
        selectedTags: _selectedTags,
        tagRepository: _tagRepository,
        onTagsChanged: (tags) {
          setState(() {
            _selectedTags.clear();
            _selectedTags.addAll(tags);
            _hasUnsavedChanges = true;
          });
        },
      ),
    );
  }

  void _showTagPeoplePicker() {
    final userProvider = context.read<UserProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _TagPeopleSheet(
        taggedPeople: _taggedPeople,
        mentionRepository: _mentionRepository,
        blockedUserIds: userProvider.blockedUserIds,
        blockedByUserIds: userProvider.blockedByUserIds,
        mutedUserIds: userProvider.mutedUserIds,
        onPeopleChanged: (people) {
          setState(() {
            _taggedPeople.clear();
            _taggedPeople.addAll(people);
            _hasUnsavedChanges = true;
          });
        },
      ),
    );
  }

  // Draft management methods
  Future<void> _checkForSavedDraft() async {
    try {
      final drafts = await _draftService.getDrafts();
      if (!mounted) return;
      setState(() {
        _savedDraftCount = drafts.length;
      });
    } catch (e) {
      debugPrint('Error checking for saved draft: $e');
      if (!mounted) return;
      setState(() => _savedDraftCount = 0);
    }
  }

  String _generateDraftId() => 'draft_${DateTime.now().microsecondsSinceEpoch}';

  LocalPostDraft _buildCurrentDraft({String? id, DateTime? createdAt}) {
    final now = DateTime.now();
    return LocalPostDraft(
      id: id ?? _activeDraftId ?? _generateDraftId(),
      title: _titleController.text.trim(),
      content: _contentController.text,
      postType: _postType,
      tags: List<String>.from(_selectedTags),
      location: _selectedLocation,
      taggedPeople: _taggedPeople
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      mediaPaths: _selectedMediaFiles.map((f) => f.path).toList(),
      mediaTypes: List<String>.from(_selectedMediaTypes),
      certifyHumanGenerated: _certifyHumanGenerated,
      createdAt: createdAt ?? now,
      updatedAt: now,
    );
  }

  Future<void> _loadDraft([String? draftId]) async {
    if (_isLoadingDraft) return;
    _isLoadingDraft = true;
    try {
      final drafts = await _draftService.getDrafts();
      if (drafts.isEmpty) {
        if (!mounted) return;
        setState(() => _savedDraftCount = 0);
        return;
      }

      final LocalPostDraft? selected = draftId == null
          ? drafts.first
          : drafts.cast<LocalPostDraft?>().firstWhere(
              (d) => d?.id == draftId,
              orElse: () => drafts.first,
            );
      if (selected == null || !mounted) return;

      final restoredFiles = <File>[];
      final restoredTypes = <String>[];
      final maxPairs = math.min(
        selected.mediaPaths.length,
        selected.mediaTypes.length,
      );
      for (var i = 0; i < maxPairs; i++) {
        final path = selected.mediaPaths[i];
        final file = File(path);
        if (file.existsSync()) {
          restoredFiles.add(file);
          restoredTypes.add(selected.mediaTypes[i]);
        }
      }

      setState(() {
        _titleController.text = selected.title;
        _contentController.text = selected.content;
        _postType = selected.postType;
        _selectedTags
          ..clear()
          ..addAll(selected.tags);
        _selectedLocation = selected.location;
        _taggedPeople
          ..clear()
          ..addAll(selected.taggedPeople.map((e) => Map<String, dynamic>.from(e)));
        _selectedMediaFiles
          ..clear()
          ..addAll(restoredFiles);
        _selectedMediaTypes
          ..clear()
          ..addAll(restoredTypes);
        _certifyHumanGenerated = selected.certifyHumanGenerated;
        _isDraftLoaded = true;
        _activeDraftId = selected.id;
        _savedDraftCount = drafts.length;
        _hasUnsavedChanges = false;
      });

      final missingCount = selected.mediaPaths.length - restoredFiles.length;
      if (missingCount > 0 && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$missingCount draft media file(s) could not be restored and were skipped.'.tr(context),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error loading draft: $e');
    } finally {
      _isLoadingDraft = false;
      _isInitialLoad = false;
    }
  }

  Future<void> _saveDraft({bool showNotification = true}) async {
    try {
      final contentDraft = _buildCurrentDraft();
      if (!contentDraft.hasContent) return;

      final existing = _activeDraftId == null
          ? null
          : await _draftService.getDraft(_activeDraftId!);
      final saved = await _draftService.upsertDraft(
        contentDraft.copyWith(
          id: existing?.id ?? contentDraft.id,
          createdAt: existing?.createdAt ?? contentDraft.createdAt,
        ),
      );

      final allDrafts = await _draftService.getDrafts();
      if (!mounted) return;
      setState(() {
        _activeDraftId = saved.id;
        _isDraftLoaded = true;
        _savedDraftCount = allDrafts.length;
        _hasUnsavedChanges = false;
      });

      if (showNotification && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              allDrafts.length > 1
                  ? 'Draft saved (${allDrafts.length} drafts available)'
                  : 'Draft saved',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving draft: $e');
    }
  }

  Future<void> _clearDraft({String? draftId}) async {
    try {
      final idToDelete = draftId ?? _activeDraftId;
      if (idToDelete != null && idToDelete.isNotEmpty) {
        await _draftService.deleteDraft(idToDelete);
      }
      final remaining = await _draftService.getDrafts();
      if (!mounted) return;
      setState(() {
        if (draftId == null || draftId == _activeDraftId) {
          _activeDraftId = null;
          _isDraftLoaded = false;
        }
        _savedDraftCount = remaining.length;
      });
    } catch (e) {
      debugPrint('Error clearing draft: $e');
    }
  }

  void _resetComposer() {
    _contentController.clear();
    _titleController.clear();
    _selectedMediaFiles.clear();
    _selectedMediaTypes.clear();
    _selectedTags.clear();
    _taggedPeople.clear();
    _selectedLocation = null;
    _certifyHumanGenerated = false;
    _hasUnsavedChanges = false;
    _isDraftLoaded = false;
    _activeDraftId = null;
  }

  Future<void> _discardDraft() async {
    final hadLoadedDraft = _activeDraftId != null;
    setState(() {
      _resetComposer();
    });
    await _checkForSavedDraft();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            hadLoadedDraft
                ? 'Draft closed. It is still available in your drafts list.'
                : 'Changes discarded',
          ),
        ),
      );
    }
  }

  bool get _hasComposerContent =>
      _titleController.text.trim().isNotEmpty ||
      _contentController.text.trim().isNotEmpty ||
      _selectedMediaFiles.isNotEmpty ||
      _selectedTags.isNotEmpty ||
      _taggedPeople.isNotEmpty ||
      (_selectedLocation?.trim().isNotEmpty ?? false);

  Future<bool> _confirmLoadDifferentDraft() async {
    if (!_hasUnsavedChanges && !_hasComposerContent) return true;
    if (!mounted) return false;

    final shouldLoad = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Load another draft?'.tr(context)),
        content: Text('This will replace your current unsaved changes. Save your current work as a draft first if you want to keep it.'.tr(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'.tr(context)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Load Draft'.tr(context)),
          ),
        ],
      ),
    );

    return shouldLoad == true;
  }

  Future<bool> _onWillPop() async {
    await _handleClose();
    return false;
  }

  Future<void> _showDraftActionsSheet() async {
    if (!mounted) return;
    final hasCurrentDraftContent = _hasComposerContent;
    final canDeleteLoadedDraft = _activeDraftId != null;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Draft Options'.tr(context),
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.save_outlined),
              title: Text('Save Draft'.tr(context)),
              enabled: hasCurrentDraftContent,
              onTap: !hasCurrentDraftContent
                  ? null
                  : () async {
                      Navigator.pop(sheetContext);
                      await _saveDraft(showNotification: true);
                    },
            ),
            ListTile(
              leading: const Icon(Icons.drafts_outlined),
              title: Text(
                _savedDraftCount > 0
                    ? 'Open Drafts ($_savedDraftCount)'
                    : 'Open Drafts',
              ),
              enabled: _savedDraftCount > 0,
              onTap: _savedDraftCount == 0
                  ? null
                  : () async {
                      Navigator.pop(sheetContext);
                      await _showDraftsPicker();
                    },
            ),
            if (canDeleteLoadedDraft)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text('Delete Loaded Draft'.tr(context),
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Delete draft?'.tr(context)),
                      content: Text('This removes the currently loaded draft from your saved drafts list.'.tr(context),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text('Cancel'.tr(context)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text('Delete'.tr(context),
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await _clearDraft();
                    if (!mounted) return;
                    setState(_resetComposer);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Draft deleted'.tr(context))),
                    );
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.clear_all_outlined),
              title: Text('Discard Current Changes'.tr(context)),
              onTap: () async {
                Navigator.pop(sheetContext);
                await _discardDraft();
              },
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _handleClose() async {
    if (_hasUnsavedChanges ||
        (_isDraftLoaded && _hasComposerContent)) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) {
          final colors = Theme.of(context).colorScheme;
          return AlertDialog(
            backgroundColor: colors.surface,
            title: Text('Discard changes?'.tr(context),
              style: TextStyle(color: colors.onSurface),
            ),
            content: Text('You have unsaved changes. Do you want to save as draft, discard, or continue editing?'.tr(context),
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, false), // Continue editing
                child: Text('Continue Editing'.tr(context)),
              ),
              TextButton(
                onPressed: () async {
                  if (context.mounted) {
                    Navigator.pop(context, true); // Discard
                  }
                },
                child: Text('Discard'.tr(context)),
              ),
              FilledButton(
                onPressed: () async {
                  await _saveDraft(showNotification: false);
                  if (context.mounted) {
                    Navigator.pop(context, true); // Save and close
                  }
                },
                child: Text('Save Draft'.tr(context)),
              ),
            ],
          );
        },
      );

      if (result == true && context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } else {
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  void _showPreviewDialog() {
    if (_contentController.text.trim().isEmpty && _selectedMediaFiles.isEmpty) {
      return;
    }

    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.currentUser;
    if (currentUser == null) return;

    // Create a temporary post for preview
    final previewPost = Post(
      id: 'preview',
      author: PostAuthor(
        userId: currentUser.id,
        displayName: currentUser.displayName ?? currentUser.username,
        username: currentUser.username,
        avatar: currentUser.avatar ?? '',
        isVerified: currentUser.isVerified ?? false,
      ),
      content: _contentController.text.trim(),
      timestamp: DateTime.now().toIso8601String(),
      likes: 0,
      comments: 0,
      tips: 0,
      isLiked: false,
      mediaUrl: _selectedMediaFiles.isNotEmpty ? 'preview' : null,
      mediaList: _selectedMediaFiles.isNotEmpty
          ? _selectedMediaFiles.asMap().entries.map((entry) {
              return PostMedia(
                id: 'preview_${entry.key}',
                postId: 'preview',
                storagePath: 'preview',
                mediaType: _selectedMediaTypes[entry.key],
              );
            }).toList()
          : null,
      tags: _selectedTags.isNotEmpty
          ? _selectedTags
                .map((tag) => PostTag(id: 'preview_tag_$tag', name: tag))
                .toList()
          : null,
      location: _selectedLocation,
      mentionedUserIds: _taggedPeople
          .map((p) => p['user_id']?.toString() ?? p['id']?.toString())
          .whereType<String>()
          .toList(),

      aiConfidenceScore: 0.85, // Default for preview
      title: _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : null,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Preview Post'.tr(context)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Preview using a simplified PostCard
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withOpacity(0.6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundImage:
                                  currentUser.avatar?.isNotEmpty == true
                                  ? NetworkImage(currentUser.avatar!)
                                  : null,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surfaceVariant,
                              child: currentUser.avatar?.isEmpty != false
                                  ? Icon(
                                      Icons.person,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    )
                                  : null,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        currentUser.displayName.isNotEmpty
                                            ? currentUser.displayName
                                            : currentUser.username,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (currentUser.isVerified) ...[
                                        SizedBox(width: 4),
                                        Icon(
                                          Icons.verified,
                                          size: 14,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text('Posting to Public Feed'.tr(context),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Content
                      if (previewPost.content.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Text(
                            previewPost.content,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),

                      // Tags
                      if (previewPost.tags != null &&
                          previewPost.tags!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: previewPost.tags!.map((tag) {
                              return Text('#${tag.name}'.tr(context),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                      // Media Preview
                      if (_selectedMediaFiles.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: _buildPreviewMediaGrid(),
                        ),

                      // Actions (simplified)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.verified_outlined,
                              size: 18,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            SizedBox(width: 6),
                            Text('0'.tr(context),
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            SizedBox(width: 16),
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 18,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            SizedBox(width: 6),
                            Text('0'.tr(context),
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Edit'.tr(context)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _createPost();
            },
            child: Text('Post'.tr(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewMediaGrid() {
    if (_selectedMediaFiles.length == 1) {
      return Container(
        height: 200,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: _selectedMediaTypes[0] == 'video'
            ? _VideoPreviewWidget(
                videoFile: _selectedMediaFiles[0],
                showControls: false,
              )
            : Image.file(_selectedMediaFiles[0], fit: BoxFit.cover),
      );
    }

    // For multiple media, show a simple grid
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: _selectedMediaFiles.length,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          child: _selectedMediaTypes[index] == 'video'
              ? _VideoPreviewWidget(
                  videoFile: _selectedMediaFiles[index],
                  showControls: false,
                )
              : Image.file(_selectedMediaFiles[index], fit: BoxFit.cover),
        );
      },
    );
  }

  /// Shows a dialog informing the user their post was detected as an
  /// advertisement and they must pay a ROO fee before it goes live.
  /// Returns true if the fee was successfully charged, false otherwise.
  Future<bool> _showAdFeeDialog(double adConfidence, String? adType) async {
    const double adFeeRoo = 5.0; // flat advertising fee in ROO

    if (!mounted) return false;

    final walletProvider = context.read<WalletProvider>();
    final userId = SupabaseService().currentUser?.id;
    if (userId == null) return false;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.campaign_outlined, color: Color(0xFFFF8C00)),
            SizedBox(width: 8),
            Text('Advertisement Detected'.tr(context)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Our system detected this post as promotional content '
              '(${adConfidence.toStringAsFixed(0)}% confidence'
              '${adType != null ? " · ${adType.replaceAll('_', ' ')}" : ""}).',
            ),
            SizedBox(height: 12),
            Text('To publish it, an advertising fee is required.'.tr(context),
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF8C00).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Ad fee'.tr(context)),
                  Text('${adFeeRoo.toStringAsFixed(0)} ROO'.tr(context),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF8C00),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            Text('If you decline, your post will be held and you can pay later from your profile.'.tr(context),
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Not now'.tr(context)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF8C00),
            ),
            child: Text('Pay ${adFeeRoo.toStringAsFixed(0)} ROO'.tr(context)),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    try {
      final success = await walletProvider.spendRoo(
        userId: userId,
        amount: adFeeRoo,
        activityType: 'AD_FEE',
        metadata: {
          'ad_confidence': adConfidence,
          'ad_type': adType,
        },
      );
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Insufficient ROO balance to pay the advertising fee.'.tr(context)),
            backgroundColor: Colors.red,
          ),
        );
      }
      return success;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: ${e.toString()}'.tr(context)),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _createPost() async {
    if (_contentController.text.trim().isEmpty && _selectedMediaFiles.isEmpty) {
      return;
    }

    // 0. Require full activation (verified + purchased ROO)
    final isActivated = await VerificationUtils.checkActivation(context);
    if (!mounted || !isActivated) return;

    final missingProfileRequirements = _getMissingProfileRequirements();
    if (missingProfileRequirements.isNotEmpty) {
      await _showCompleteProfileRequiredAlert(missingProfileRequirements);
      return;
    }
    // 1. Post creation is now a reward (+10 ROO) processed in PostRepository
    // final paid = await _confirmAndPayPostFee();
    // if (!mounted || !paid) return;

    setState(() => _isPosting = true);

    try {
      final userId = SupabaseService().currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      // Extract hashtags from content
      final rawContentHashtags =
          (await Future.value(
            _tagRepository.extractHashtags(_contentController.text),
          )) ??
          [];
      // Normalize tags to simple lowercase strings without leading '#'
      final normalizedSelectedTags = _selectedTags
          .whereType<String>()
          .map((t) => t.toLowerCase().trim().replaceAll('#', ''))
          .where((t) => t.isNotEmpty);
      final normalizedContentHashtags = rawContentHashtags
          .where((h) => h != null)
          .map((h) => h.toString().toLowerCase().trim().replaceAll('#', ''))
          .where((h) => h.isNotEmpty);
      final allTags = {
        ...normalizedSelectedTags,
        ...normalizedContentHashtags,
      }.toList();

      // Get mentioned user IDs from tag-people picker
      final taggedUserIds = _taggedPeople
          .map((p) {
            if (p['user_id'] != null) return p['user_id'].toString();
            if (p['id'] != null) return p['id'].toString();
            return null;
          })
          .whereType<String>()
          .toList();

      // Also extract inline @mentions from content text
      final inlineMentionUsernames = _mentionRepository.extractMentions(
        _contentController.text,
      );
      final inlineMentionUserIds = inlineMentionUsernames.isNotEmpty
          ? await _mentionRepository.resolveUsernamesToIds(
              inlineMentionUsernames,
            )
          : <String>[];

      // Merge both sources, deduplicate
      final mentionedUserIds = {
        ...taggedUserIds,
        ...inlineMentionUserIds,
      }.toList();

      // Seed mention cache so tagged usernames can render immediately in post cards.
      _mentionRepository.seedMentionUserCache(_taggedPeople);

      // Create the post
      if (!mounted) return;
      final feedProvider = context.read<FeedProvider>();
      final currentUser = context.read<UserProvider>().currentUser;
      final titleText = _titleController.text.trim();
      final contentText = _contentController.text.trim();

      // Capture lists to avoid issues after clearing controllers
      final mediaFiles = _selectedMediaFiles.isNotEmpty
          ? List<File>.from(_selectedMediaFiles)
          : null;
      final mediaTypes = _selectedMediaTypes.isNotEmpty
          ? List<String>.from(_selectedMediaTypes)
          : null;
      final taggedIds = mentionedUserIds.isNotEmpty ? mentionedUserIds : null;
      final loc = _selectedLocation;
      final tagsList = allTags.isNotEmpty ? allTags : null;

      final optimisticAuthor = currentUser == null
          ? null
          : PostAuthor(
              userId: currentUser.id,
              displayName: currentUser.displayName.isNotEmpty
                  ? currentUser.displayName
                  : currentUser.username,
              username: currentUser.username,
              avatar: currentUser.avatar ?? '',
              isVerified: currentUser.verifiedHuman == 'verified',
              postsVisibility: currentUser.postsVisibility,
            );

      final optimisticTags = tagsList == null
          ? null
          : tagsList.map((t) => PostTag(id: 'temp_$t', name: t)).toList();

      // 1. Clear form and draft immediately
      _contentController.clear();
      _titleController.clear();
      _selectedMediaFiles.clear();
      _selectedMediaTypes.clear();
      _selectedTags.clear();
      _taggedPeople.clear();
      _selectedLocation = null;
      _certifyHumanGenerated = false;
      await _clearDraft();

      if (mounted) {
        setState(() {
          _hasUnsavedChanges = false;
          // Keep _isPosting = true until AI check completes for feedback
        });
      }

      // 2. Trigger post creation and WAIT for AI detection
      final createdPost = await feedProvider.createPost(
        contentText,
        title: titleText.isNotEmpty ? titleText : null,
        mediaFiles: mediaFiles,
        mediaTypes: mediaTypes,
        tags: tagsList,
        location: loc,
        mentionedUserIds: taggedIds,
        optimisticAuthor: optimisticAuthor,
        optimisticTags: optimisticTags,
        waitForAi:
            true, // Keep screen active so ad-fee modal can be shown before leaving
        onAdFeeRequired: (adConfidence, adType) =>
            _showAdFeeDialog(adConfidence, adType),
      );

      if (!mounted) return;
      setState(() => _isPosting = false);

      if (createdPost != null) {
        // Refresh wallet/user state so new ROO rewards reflect quickly in UI.
        if (createdPost.status == 'published') {
          unawaited(
            context.read<WalletProvider>().refreshWallet(userId).catchError((
              _,
            ) {
              return null;
            }),
          );
          unawaited(
            context.read<UserProvider>().fetchUser(userId).catchError((_) {
              return null;
            }),
          );
        }

        // 3. Navigate to feed after successful creation
        if (widget.onPostCreated != null) {
          widget.onPostCreated!();
        }
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        String? message;
        Color? backgroundColor;

        if (createdPost.status == 'published') {
          message = 'Post published successfully!';
          backgroundColor = Colors.green;
        } else if (createdPost.status == 'deleted' ||
            createdPost.status == 'hidden') {
          final reason = createdPost.authenticityNotes != null
              ? ': ${createdPost.authenticityNotes}'
              : '';
          message = 'Post rejected$reason';
          backgroundColor = Colors.red;
        } else if (createdPost.status == 'under_review') {
          message = 'Post sent to review. It will show after review.';
          backgroundColor = Colors.amber.shade700;
        } else if (createdPost.status == 'draft' &&
            (createdPost.authenticityNotes ?? '')
                .toLowerCase()
                .contains('awaiting ad fee payment')) {
          message =
              'Advertisement detected. Post is held until you pay the 5 ROO ad fee.';
          backgroundColor = Colors.orange.shade700;
        } else {
          message = null;
          backgroundColor = null;
        }

        if (message != null && backgroundColor != null) {
          rootScaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: backgroundColor,
              duration: const Duration(seconds: 7),
              action: SnackBarAction(
                label: 'VIEW',
                textColor: Colors.white,
                onPressed: () {
                  rootNavigatorKey.currentState?.push(
                    MaterialPageRoute(
                      builder: (_) => PostDetailScreen(post: createdPost),
                    ),
                  );
                },
              ),
            ),
          );
        }
      } else {
        // Keep user on create screen if creation failed.
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Failed to create post. Please try again.'.tr(context)),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 7),
          ),
        );
      }
    } on KycNotVerifiedException catch (e) {
      if (!mounted) return;
      setState(() => _isPosting = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Verify',
              textColor: Colors.white,
              onPressed: () {
                if (context.mounted) {
                  Navigator.pushNamed(context, '/verify');
                }
              },
            ),
          ),
        );
      }
    } on NotActivatedException catch (e) {
      if (!mounted) return;
      setState(() => _isPosting = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Buy ROO',
              textColor: Colors.white,
              onPressed: () {
                if (context.mounted) {
                  Navigator.pushNamed(context, '/wallet');
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating post: $e');
      if (mounted) {
        setState(() => _isPosting = false);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to create post: $e'.tr(context))));
        }
      }
    }
  }

  List<String> _getMissingProfileRequirements() {
    final user = context.read<UserProvider>().currentUser;
    if (user == null) {
      return const ['profile'];
    }

    final missing = <String>[];
    if (user.displayName.trim().isEmpty) {
      missing.add('display name');
    }

    final phone = user.phone?.trim() ?? '';
    if (phone.isEmpty) {
      missing.add('phone number');
    }

    final country = (user.countryOfResidence ?? user.location ?? '').trim();
    if (country.isEmpty) {
      missing.add('country');
    }

    final birthDate = user.birthDate;
    if (birthDate == null) {
      missing.add('date of birth');
    } else if (_calculateAge(birthDate) < 18) {
      missing.add('age must be 18+');
    }

    return missing;
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    final hadBirthdayThisYear =
        now.month > birthDate.month ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hadBirthdayThisYear) age--;
    return age;
  }

  Future<void> _showCompleteProfileRequiredAlert(List<String> missingFields) async {
    if (!mounted) return;

    final missingText = missingFields.join(', ');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Complete Your Profile'.tr(context)),
        content: Text('Finish your profile before creating a post.\n\nRequired: $missingText'.tr(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancel'.tr(context)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (!mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              );
            },
            child: Text('Finish Profile'.tr(context)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = context.watch<UserProvider>().currentUser;

    final hasContent =
        _contentController.text.trim().isNotEmpty ||
        _selectedMediaFiles.isNotEmpty;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        floatingActionButton: null,
        body: SafeArea(
          child: Column(
          children: [
            // App bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  bottom: BorderSide(color: colors.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _handleClose,
                  ),
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text('New Post'.tr(context),
                            style: theme.textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isDraftLoaded) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('Draft'.tr(context),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    tooltip: _savedDraftCount > 0
                        ? 'Open drafts ($_savedDraftCount)'
                        : 'No drafts saved',
                    onPressed:
                        _savedDraftCount > 0 && !_isLoadingDraft
                        ? _showDraftsPicker
                        : null,
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.drafts_outlined),
                        if (_savedDraftCount > 0)
                          Positioned(
                            right: -6,
                            top: -6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(minWidth: 18),
                              child: Text(
                                _savedDraftCount > 99
                                    ? '99+'
                                    : '$_savedDraftCount',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Draft options',
                    onPressed: _showDraftActionsSheet,
                    icon: const Icon(Icons.more_vert),
                  ),
                  SizedBox(width: 4),
                  Builder(
                    builder: (context) {
                      final postButton = FilledButton(
                        onPressed:
                            !hasContent || _isPosting || !_certifyHumanGenerated
                            ? null
                            : _showPreviewDialog,
                        child: _isPosting
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text('Post'.tr(context)),
                      );

                      if (_postCostRoo > 0) {
                        return Tooltip(
                          message:
                              'You’ll earn ${_postCostRoo.toStringAsFixed(_postCostRoo % 1 == 0 ? 0 : 10)} ROO',
                          child: postButton,
                        );
                      }
                      return postButton;
                    },
                  ),
                ],
              ),
            ),

            // Post type tabs
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildPostTypeTab(context, 'Text'),
                  SizedBox(width: 12),
                  _buildPostTypeTab(context, 'Photo'),
                  SizedBox(width: 12),
                  _buildPostTypeTab(context, 'Video'),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author
                    Consumer<UserProvider>(
                      builder: (context, userProvider, _) {
                        final user = userProvider.currentUser;
                        return Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colors.primary,
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: user?.avatar != null
                                    ? Image.network(
                                        user!.avatar!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) {
                                          return Container(
                                            color:
                                                colors.surfaceContainerHighest,
                                            child: Icon(
                                              Icons.person,
                                              color: colors.onSurfaceVariant,
                                            ),
                                          );
                                        },
                                      )
                                    : Container(
                                        color: colors.surfaceContainerHighest,
                                        child: Icon(
                                          Icons.person,
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      user?.displayName ?? 'Unknown',
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text('HUMAN'.tr(context),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text('Posting to Public Feed'.tr(context),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),

                    SizedBox(height: 20),

                    // Optional title
                    TextField(
                      controller: _titleController,
                      textCapitalization: TextCapitalization.sentences,
                      enableSuggestions: true,
                      autocorrect: true,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Add a title (optional)',
                        hintStyle: theme.textTheme.titleMedium?.copyWith(
                          color: colors.onSurfaceVariant.withOpacity(0.5),
                        ),
                        border: InputBorder.none,
                      ),
                    ),

                    // Text input
                    // Text input
                    if (user?.isVerified == true)
                      MentionAutocompleteField(
                        controller: _contentController,
                        maxLines: null,
                        minLines: _postType == 'Text' ? 8 : 5,
                        maxLength: _maxCharacterLimit,
                        style: theme.textTheme.bodyMedium,
                        decoration: InputDecoration(
                          hintText: _postType == 'Text'
                              ? 'Share your thoughts... use #topics'
                              : 'Add a caption... use #topics',
                          hintStyle: theme.textTheme.bodyMedium,
                          border: InputBorder.none,
                          counterText: '', // Hide default counter
                        ),
                      )
                    else
                      VerificationRequiredWidget(
                        message:
                            'You need to be a verified human to create posts.',
                        onVerifyTap: () {
                          if (context.mounted) {
                            Navigator.pushNamed(context, '/verify');
                          }
                        },
                      ),

                    // Real-time moderation warning
                    if (_textModerationResult != null &&
                        _textModerationResult!.flagged)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.red,
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text('Warning: ${_textModerationResult!.details ?? "Content contains potential policy violations."}'.tr(context),
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_isModeratingText)
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Checking content safety...'.tr(context),
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Character count
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text('${_contentController.text.length}/$_maxCharacterLimit'.tr(context),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              _contentController.text.length >
                                  _maxCharacterLimit * 0.9
                              ? Colors.orange
                              : _contentController.text.length >
                                    _maxCharacterLimit
                              ? Colors.red
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Tip: Add hashtags like #travel or #flutter in your post.'.tr(context),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),

                    // Human-generated content certification
                    SizedBox(height: 8),
                    CheckboxListTile(
                      value: _certifyHumanGenerated,
                      onChanged: (value) {
                        setState(() {
                          _certifyHumanGenerated = value ?? false;
                        });
                      },
                      title: Text('I certify this content is human-generated.'.tr(context),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: colors.primary,
                    ),

                    // Media attachment section (only for Photo/Video)
                    if (_postType != 'Text') ...[
                      SizedBox(height: 16),
                      _buildMediaAttachmentSection(context),
                    ],

                    // Media preview
                    if (_selectedMediaFiles.isNotEmpty) ...[
                      SizedBox(height: 16),
                      _buildMediaPreview(context),
                    ],

                    SizedBox(height: 24),

                    // Selected tags preview
                    if (_selectedTags.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedTags.map((tag) {
                          return Chip(
                            label: Text('#$tag'.tr(context)),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setState(() => _selectedTags.remove(tag));
                            },
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 16),
                    ],

                    // Selected location preview
                    if (_selectedLocation != null) ...[
                      Chip(
                        avatar: const Icon(Icons.location_on, size: 16),
                        label: Text(_selectedLocation!),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() => _selectedLocation = null);
                        },
                      ),
                      SizedBox(height: 16),
                    ],

                    // Tagged people preview
                    if (_taggedPeople.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _taggedPeople.map((person) {
                          return Chip(
                            avatar: const Icon(Icons.person, size: 16),
                            label: Text('@${person['username']}'),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setState(() => _taggedPeople.remove(person));
                            },
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 16),
                    ],

                    // Option cards
                    _optionCard(
                      context,
                      icon: Icons.people,
                      title: 'Tag People',
                      subtitle: _taggedPeople.isNotEmpty
                          ? '${_taggedPeople.length} people tagged'
                          : null,
                      onTap: _showTagPeoplePicker,
                    ),
                    SizedBox(height: 16),
                    _optionCard(
                      context,
                      icon: Icons.location_on,
                      title: 'Add Location',
                      subtitle: _selectedLocation,
                      onTap: _showLocationPicker,
                    ),
                    SizedBox(height: 16),
                    _optionCard(
                      context,
                      icon: Icons.tag,
                      title: 'Add #Topics',
                      subtitle: _selectedTags.isNotEmpty
                          ? '${_selectedTags.length} topics added'
                          : 'You can also type #topics in your caption',
                      onTap: _showTopicsPicker,
                    ),
                  ],
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostTypeTab(BuildContext context, String type) {
    final colors = Theme.of(context).colorScheme;
    final bool isSelected = _postType == type;

    return GestureDetector(
      onTap: () => setState(() => _postType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: colors.outlineVariant),
        ),
        child: Text(
          type,
          style: TextStyle(
            color: isSelected ? colors.onPrimary : colors.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _optionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: colors.primary),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaAttachmentSection(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isPhoto = _postType == 'Photo';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.perm_media, color: colors.primary, size: 20),
              SizedBox(width: 8),
              Text('Add Media'.tr(context),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _mediaOptionButton(
                  context,
                  icon: Icons.perm_media_outlined,
                  label: 'Gallery',
                  onTap: () => _pickMedia(fromCamera: false),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _mediaOptionButton(
                  context,
                  icon: isPhoto
                      ? Icons.camera_alt_outlined
                      : Icons.videocam_outlined,
                  label: 'Camera',
                  onTap: () => _pickMedia(fromCamera: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mediaOptionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(icon, color: colors.primary, size: 32),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (_selectedMediaFiles.length == 1) {
      final isImage = _selectedMediaTypes[0] == 'image';
      return Container(
        height: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _selectedMediaTypes[0] == 'video'
                  ? _VideoPreviewWidget(videoFile: _selectedMediaFiles[0])
                  : Image.file(
                      _selectedMediaFiles[0],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
            ),
            // Edit button (only for images)
            if (isImage)
              Positioned(
                top: 12,
                left: 12,
                child: _overlayIcon(Icons.edit, () => _showImageEditor(0)),
              ),
            // Video trim button (only for videos)
            if (_selectedMediaTypes[0] == 'video')
              Positioned(
                top: 12,
                left: 12,
                child: _overlayIcon(
                  Icons.content_cut,
                  () => _showVideoEditor(0),
                ),
              ),
            Positioned(
              top: 12,
              right: 12,
              child: _overlayIcon(Icons.close, () => _removeMedia(0)),
            ),
          ],
        ),
      );
    }

    // Grid for multiple media
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _selectedMediaFiles.length,
      itemBuilder: (context, index) {
        final isImage = _selectedMediaTypes[index] == 'image';
        final isVideo = _selectedMediaTypes[index] == 'video';
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: isVideo
                    ? _VideoPreviewWidget(videoFile: _selectedMediaFiles[index])
                    : Image.file(_selectedMediaFiles[index], fit: BoxFit.cover),
              ),
              // Edit button (only for images)
              if (isImage)
                Positioned(
                  top: 8,
                  left: 8,
                  child: _overlayIcon(
                    Icons.edit,
                    () => _showImageEditor(index),
                  ),
                ),
              // Video trim button (only for videos)
              if (isVideo)
                Positioned(
                  top: 8,
                  left: 8,
                  child: _overlayIcon(
                    Icons.content_cut,
                    () => _showVideoEditor(index),
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: _overlayIcon(Icons.close, () => _removeMedia(index)),
              ),
            ],
          ),
        );
      },
    );
  }


  Future<void> _applyFilterToImage(int index, String filterType) async {
    try {
      final imageFile = _selectedMediaFiles[index];
      final imageBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);

      if (image != null) {
        img.Image filteredImage;

        switch (filterType) {
          case 'grayscale':
            filteredImage = img.grayscale(image);
            break;
          case 'sepia':
            filteredImage = img.sepia(image);
            break;
          case 'invert':
            filteredImage = img.invert(image);
            break;
          case 'brightness':
            filteredImage = img.adjustColor(image, brightness: 0.2);
            break;
          case 'contrast':
            filteredImage = img.adjustColor(image, contrast: 1.2);
            break;
          default:
            filteredImage = image;
        }

        final filteredBytes = img.encodeJpg(filteredImage);
        final tempDir = await Directory.systemTemp.createTemp();
        final filteredFile = File(
          '${tempDir.path}/filtered_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await filteredFile.writeAsBytes(filteredBytes);

        if (mounted) {
          setState(() {
            _selectedMediaFiles[index] = filteredFile;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to apply filter: $e'.tr(context))));
      }
    }
  }

  void _showImageEditor(int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return Container(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit Image'.tr(context),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _filterButton('Grayscale', Icons.filter_b_and_w, () {
                    Navigator.pop(context);
                    _applyFilterToImage(index, 'grayscale');
                  }),
                  _filterButton('Sepia', Icons.filter_vintage, () {
                    Navigator.pop(context);
                    _applyFilterToImage(index, 'sepia');
                  }),
                  _filterButton('Invert', Icons.invert_colors, () {
                    Navigator.pop(context);
                    _applyFilterToImage(index, 'invert');
                  }),
                  _filterButton('Brightness', Icons.brightness_6, () {
                    Navigator.pop(context);
                    _applyFilterToImage(index, 'brightness');
                  }),
                  _filterButton('Contrast', Icons.contrast, () {
                    Navigator.pop(context);
                    _applyFilterToImage(index, 'contrast');
                  }),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filterButton(String label, IconData icon, VoidCallback onTap) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(icon, color: colors.primary, size: 24),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoEditor(int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return Container(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit Video'.tr(context),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _filterButton('Trim', Icons.content_cut, () {
                    Navigator.pop(context);
                    _showVideoTrimDialog(index);
                  }),
                  _filterButton('Mute', Icons.volume_off, () {
                    Navigator.pop(context);
                    _muteVideo(index);
                  }),
                  _filterButton('Rotate', Icons.rotate_right, () {
                    Navigator.pop(context);
                    _rotateVideo(index);
                  }),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showVideoTrimDialog(int index) async {
    final videoFile = _selectedMediaFiles[index];
    VideoPlayerController? controller;

    try {
      controller = VideoPlayerController.file(videoFile);
      await controller.initialize();

      if (!mounted) return;

      double startTrim = 0.0;
      double endTrim = controller.value.duration.inMilliseconds.toDouble();

      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Trim Video'.tr(context)),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: controller!.value.aspectRatio,
                      child: VideoPlayer(controller),
                    ),
                  ),
                  SizedBox(height: 16),
                  // Play/Pause button
                  IconButton(
                    icon: Icon(
                      controller.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                    onPressed: () {
                      setState(() {
                        controller!.value.isPlaying
                            ? controller.pause()
                            : controller.play();
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  // Trim sliders
                  Column(
                    children: [
                      Text('Start: ${(startTrim / 1000).toStringAsFixed(1)}s'.tr(context),
                        style: const TextStyle(fontSize: 12),
                      ),
                      Slider(
                        value: startTrim,
                        min: 0,
                        max: controller.value.duration.inMilliseconds
                            .toDouble(),
                        onChanged: (value) {
                          setState(() {
                            startTrim = value;
                            if (startTrim >= endTrim) {
                              endTrim = math.min(
                                startTrim + 1000,
                                controller!.value.duration.inMilliseconds
                                    .toDouble(),
                              );
                            }
                          });
                        },
                      ),
                      Text('End: ${(endTrim / 1000).toStringAsFixed(1)}s'.tr(context),
                        style: const TextStyle(fontSize: 12),
                      ),
                      Slider(
                        value: endTrim,
                        min: 0,
                        max: controller.value.duration.inMilliseconds
                            .toDouble(),
                        onChanged: (value) {
                          setState(() {
                            endTrim = value;
                            if (endTrim <= startTrim) {
                              startTrim = math.max(0, endTrim - 1000);
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text('Duration: ${((endTrim - startTrim) / 1000).toStringAsFixed(1)}s'.tr(context),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _applyVideoTrim(index, startTrim, endTrim);
                },
                child: Text('Apply Trim'.tr(context)),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load video: $e'.tr(context))));
      }
    } finally {
      controller?.dispose();
    }
  }

  Future<void> _applyVideoTrim(int index, double startMs, double endMs) async {
    // For now, show a message that trimming is simulated
    // In a real implementation, this would use FFmpeg or similar to trim the video
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Video trimming simulation complete! (Full implementation requires FFmpeg)'.tr(context),
        ),
        duration: Duration(seconds: 3),
      ),
    );

    // In a real implementation, you would:
    // 1. Use FFmpeg to trim the video file
    // 2. Save the trimmed video to a new file
    // 3. Replace the original file with the trimmed version
    // 4. Update the UI
  }

  Future<void> _muteVideo(int index) async {
    if (!mounted) return;

    final videoFile = _selectedMediaFiles[index];
    VideoPlayerController? controller;

    try {
      controller = VideoPlayerController.file(videoFile);
      await controller.initialize();

      if (!mounted) return;

      // Track the muted state
      bool isMuted = false;

      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Mute Video'.tr(context)),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: Column(
                children: [
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: controller!.value.aspectRatio,
                      child: VideoPlayer(controller),
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          controller.value.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                        ),
                        onPressed: () {
                          setState(() {
                            controller!.value.isPlaying
                                ? controller.pause()
                                : controller.play();
                          });
                        },
                      ),
                      SizedBox(width: 16),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            isMuted = !isMuted;
                            controller!.setVolume(isMuted ? 0.0 : 1.0);
                          });
                        },
                        icon: Icon(
                          isMuted ? Icons.volume_off : Icons.volume_up,
                        ),
                        label: Text(isMuted ? 'Muted' : 'Audio On'),
                        style: FilledButton.styleFrom(
                          backgroundColor: isMuted ? Colors.red : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (isMuted && mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text('Video will be muted when posted'.tr(context)),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: Text('Apply'.tr(context)),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load video: $e'.tr(context))));
      }
    } finally {
      controller?.dispose();
    }
  }

  Future<void> _rotateVideo(int index) async {
    if (!mounted) return;

    final videoFile = _selectedMediaFiles[index];
    VideoPlayerController? controller;

    try {
      controller = VideoPlayerController.file(videoFile);
      await controller.initialize();

      if (!mounted) return;

      int rotationDegrees = 0;

      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Rotate Video'.tr(context)),
            content: SizedBox(
              width: double.maxFinite,
              height: 350,
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Transform.rotate(
                        angle: rotationDegrees * 3.14159 / 180,
                        child: AspectRatio(
                          aspectRatio: controller!.value.aspectRatio,
                          child: VideoPlayer(controller),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          controller.value.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                        ),
                        onPressed: () {
                          setState(() {
                            controller!.value.isPlaying
                                ? controller.pause()
                                : controller.play();
                          });
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            rotationDegrees = (rotationDegrees - 90) % 360;
                          });
                        },
                        icon: const Icon(Icons.rotate_left),
                        label: Text('Left'.tr(context)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${rotationDegrees % 360}°'.tr(context),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            rotationDegrees = (rotationDegrees + 90) % 360;
                          });
                        },
                        icon: const Icon(Icons.rotate_right),
                        label: Text('Right'.tr(context)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (rotationDegrees != 0 && mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text('Video will be rotated ${rotationDegrees % 360}° when posted'.tr(context),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: Text('Apply'.tr(context)),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load video: $e'.tr(context))));
      }
    } finally {
      controller?.dispose();
    }
  }

  Widget _overlayIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.6),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  String _draftPreview(LocalPostDraft draft) {
    final title = draft.title.trim();
    final content = draft.content.trim();
    if (title.isNotEmpty) return title;
    if (content.isNotEmpty) {
      return content.length > 60 ? '${content.substring(0, 60)}...' : content;
    }
    if (draft.mediaPaths.isNotEmpty) return '[Media Draft]';
    return 'Untitled draft';
  }

  Future<void> _showDraftsPicker() async {
    final drafts = await _draftService.getDrafts();
    if (!mounted) return;
    if (drafts.isEmpty) {
      setState(() => _savedDraftCount = 0);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No saved drafts'.tr(context))));
      return;
    }

    if (drafts.length == 1) {
      if (_activeDraftId != drafts.first.id &&
          !await _confirmLoadDifferentDraft()) {
        return;
      }
      await _loadDraft(drafts.first.id);
      return;
    }

    final selectedId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('My Drafts'.tr(context),
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('${drafts.length} saved drafts'.tr(context)),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.65,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: drafts.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: colors.outlineVariant,
                    ),
                    itemBuilder: (context, index) {
                      final draft = drafts[index];
                      final updated = draft.updatedAt.toLocal();
                      final subtitle =
                          '${updated.year}-${updated.month.toString().padLeft(2, '0')}-${updated.day.toString().padLeft(2, '0')} ${updated.hour.toString().padLeft(2, '0')}:${updated.minute.toString().padLeft(2, '0')}';
                      return ListTile(
                        leading: const Icon(Icons.drafts_outlined),
                        title: Text(
                          _draftPreview(draft),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await _clearDraft(draftId: draft.id);
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            await _showDraftsPicker();
                          },
                        ),
                        onTap: () => Navigator.pop(context, draft.id),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedId != null) {
      if (_activeDraftId != selectedId &&
          !await _confirmLoadDifferentDraft()) {
        return;
      }
      await _loadDraft(selectedId);
    }
  }

}

// Video Preview Widget
class _VideoPreviewWidget extends StatefulWidget {
  final File videoFile;
  final bool showControls;

  const _VideoPreviewWidget({
    required this.videoFile,
    this.showControls = true,
  });

  @override
  State<_VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<_VideoPreviewWidget> {
  VideoPlayerController? _controller;
  ChewieController? _chewieController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.file(widget.videoFile);
    await _controller!.initialize();

    final aspectRatio =
        _controller!.value.aspectRatio.isFinite &&
            _controller!.value.aspectRatio > 0
        ? _controller!.value.aspectRatio
        : 16 / 9;

    _chewieController = ChewieController(
      videoPlayerController: _controller!,
      autoPlay: false,
      looping: false,
      showControls: widget.showControls,
      allowFullScreen: false,
      allowMuting: false,
      allowPlaybackSpeedChanging: false,
      aspectRatio: aspectRatio,
      materialProgressColors: ChewieProgressColors(
        playedColor: Theme.of(context).colorScheme.primary,
        handleColor: Theme.of(context).colorScheme.primary,
        backgroundColor: Colors.grey,
        bufferedColor: Colors.grey.shade300,
      ),
      placeholder: Container(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      ),
      errorBuilder: (context, errorMessage) {
        return Container(
          color: Colors.black,
          child: Center(child: Icon(Icons.error, color: Colors.white)),
        );
      },
    );

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: Colors.black,
      child: Center(child: CircularProgressIndicator()),
    );

    if (!_isInitialized || _chewieController == null) {
      return SizedBox(height: 240, width: double.infinity, child: fallback);
    }

    // Guard against invalid aspect ratios that can throw width.isFinite errors.
    final rawAspect = _controller?.value.aspectRatio ?? 16 / 9;
    final aspectRatio = rawAspect.isFinite && rawAspect > 0
        ? rawAspect
        : 16 / 9;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Chewie(controller: _chewieController!),
    );
  }
}

// Location Picker Sheet
class _LocationPickerSheet extends StatefulWidget {
  final String? currentLocation;
  final bool isLoading;
  final VoidCallback onGetCurrentLocation;
  final Function(String) onLocationSelected;
  final VoidCallback onClear;

  const _LocationPickerSheet({
    this.currentLocation,
    required this.isLoading,
    required this.onGetCurrentLocation,
    required this.onLocationSelected,
    required this.onClear,
  });

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.currentLocation ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add Location'.tr(context),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Enter location...',
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  widget.onLocationSelected(value.trim());
                }
              },
            ),
            SizedBox(height: 16),
            ListTile(
              leading: widget.isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.my_location, color: colors.primary),
              title: Text('Use current location'.tr(context)),
              onTap: widget.isLoading ? null : widget.onGetCurrentLocation,
            ),
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.currentLocation != null)
                  TextButton(
                    onPressed: widget.onClear,
                    child: Text('Clear'.tr(context)),
                  ),
                SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    if (_controller.text.trim().isNotEmpty) {
                      widget.onLocationSelected(_controller.text.trim());
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  child: Text('Done'.tr(context)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Topics Picker Sheet
class _TopicsPickerSheet extends StatefulWidget {
  final List<String> selectedTags;
  final TagRepository tagRepository;
  final Function(List<String>) onTagsChanged;

  const _TopicsPickerSheet({
    required this.selectedTags,
    required this.tagRepository,
    required this.onTagsChanged,
  });

  @override
  State<_TopicsPickerSheet> createState() => _TopicsPickerSheetState();
}

class _TopicsPickerSheetState extends State<_TopicsPickerSheet> {
  final TextEditingController _controller = TextEditingController();
  late List<String> _tags;
  List<PostTag> _suggestions = [];
  bool _isLoading = false;

  // Popular/suggested topics
  final List<String> _popularTopics = [
    'tech',
    'art',
    'music',
    'gaming',
    'sports',
    'news',
    'photography',
    'travel',
    'food',
    'fashion',
    'science',
    'health',
    'business',
    'education',
    'entertainment',
  ];

  @override
  void initState() {
    super.initState();
    _tags = List.from(widget.selectedTags);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _searchTags(String query) async {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    setState(() => _isLoading = true);
    final results = await widget.tagRepository.searchTags(query);
    if (mounted) {
      setState(() {
        _suggestions = results;
        _isLoading = false;
      });
    }
  }

  void _addTag(String tag) {
    final normalizedTag = tag.toLowerCase().trim().replaceAll('#', '');
    if (normalizedTag.isNotEmpty && !_tags.contains(normalizedTag)) {
      setState(() {
        _tags.add(normalizedTag);
        _controller.clear();
        _suggestions = [];
      });
    }
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Topics'.tr(context),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text('Topics help people discover your post'.tr(context),
                style: theme.textTheme.bodySmall,
              ),
              SizedBox(height: 20),
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Search or add topics...',
                  prefixIcon: const Icon(Icons.tag),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => _addTag(_controller.text),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: _searchTags,
                onSubmitted: _addTag,
              ),
              SizedBox(height: 16),

              // Selected tags
              if (_tags.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tags.map((tag) {
                    return Chip(
                      label: Text('#$tag'.tr(context)),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _removeTag(tag),
                      backgroundColor: colors.primaryContainer,
                    );
                  }).toList(),
                ),
                SizedBox(height: 16),
                Divider(),
              ],

              // Suggestions or popular topics
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    if (_isLoading)
                      Center(child: CircularProgressIndicator())
                    else if (_suggestions.isNotEmpty) ...[
                      Text('Suggestions'.tr(context), style: theme.textTheme.titleSmall),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _suggestions.map((suggestion) {
                          final isSelected = _tags.contains(suggestion.name);
                          return ActionChip(
                            label: Text('#${suggestion.name}'.tr(context)),
                            onPressed: isSelected
                                ? null
                                : () => _addTag(suggestion.name),
                            backgroundColor: isSelected
                                ? colors.primaryContainer
                                : null,
                          );
                        }).toList(),
                      ),
                    ] else ...[
                      Text('Popular Topics'.tr(context), style: theme.textTheme.titleSmall),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _popularTopics.map((topic) {
                          final isSelected = _tags.contains(topic);
                          return ActionChip(
                            label: Text('#$topic'.tr(context)),
                            onPressed: isSelected ? null : () => _addTag(topic),
                            backgroundColor: isSelected
                                ? colors.primaryContainer
                                : null,
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(AppLocalizations.of(context)!.cancel),
                  ),
                  SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      widget.onTagsChanged(_tags);
                      Navigator.pop(context);
                    },
                    child: Text('Done'.tr(context)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// Tag People Sheet
class _TagPeopleSheet extends StatefulWidget {
  final List<Map<String, dynamic>> taggedPeople;
  final MentionRepository mentionRepository;
  final Function(List<Map<String, dynamic>>) onPeopleChanged;
  final Set<String> blockedUserIds;
  final Set<String> blockedByUserIds;
  final Set<String> mutedUserIds;

  const _TagPeopleSheet({
    required this.taggedPeople,
    required this.mentionRepository,
    required this.onPeopleChanged,
    this.blockedUserIds = const {},
    this.blockedByUserIds = const {},
    this.mutedUserIds = const {},
  });

  @override
  State<_TagPeopleSheet> createState() => _TagPeopleSheetState();
}

class _TagPeopleSheetState extends State<_TagPeopleSheet> {
  final TextEditingController _controller = TextEditingController();
  late List<Map<String, dynamic>> _people;
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _people = List.from(widget.taggedPeople);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    setState(() => _isLoading = true);
    final results = await widget.mentionRepository.searchUsers(
      query,
      blockedUserIds: widget.blockedUserIds,
      blockedByUserIds: widget.blockedByUserIds,
      mutedUserIds: widget.mutedUserIds,
    );
    if (mounted) {
      setState(() {
        _suggestions = results;
        _isLoading = false;
      });
    }
  }

  void _addPerson(Map<String, dynamic> person) {
    if (!_people.any((p) => p['user_id'] == person['user_id'])) {
      setState(() {
        _people.add(person);
        _controller.clear();
        _suggestions = [];
      });
    }
  }

  void _removePerson(Map<String, dynamic> person) {
    setState(() {
      _people.removeWhere((p) => p['user_id'] == person['user_id']);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tag People'.tr(context),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Search by username...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: _searchUsers,
              ),
              SizedBox(height: 16),

              // Tagged people
              if (_people.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _people.map((person) {
                    return Chip(
                      avatar: CircleAvatar(
                        backgroundImage: person['avatar_url'] != null
                            ? NetworkImage(person['avatar_url'])
                            : null,
                        child: person['avatar_url'] == null
                            ? const Icon(Icons.person, size: 16)
                            : null,
                      ),
                      label: Text('@${person['username']}'),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _removePerson(person),
                      backgroundColor: colors.primaryContainer,
                    );
                  }).toList(),
                ),
                SizedBox(height: 16),
                Divider(),
              ],

              // Search results
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _suggestions.isEmpty
                    ? Center(
                        child: Text(
                          _controller.text.isEmpty
                              ? 'Search for users to tag'
                              : 'No users found',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _suggestions.length,
                        itemBuilder: (context, index) {
                          final user = _suggestions[index];
                          final isSelected = _people.any(
                            (p) => p['user_id'] == user['user_id'],
                          );
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: user['avatar_url'] != null
                                  ? NetworkImage(user['avatar_url'])
                                  : null,
                              child: user['avatar_url'] == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text(
                              user['display_name'] ?? user['username'],
                            ),
                            subtitle: Text('@${user['username']}'),
                            trailing: isSelected
                                ? Icon(Icons.check, color: colors.primary)
                                : null,
                            onTap: isSelected ? null : () => _addPerson(user),
                          );
                        },
                      ),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(AppLocalizations.of(context)!.cancel),
                  ),
                  SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      widget.onPeopleChanged(_people);
                      Navigator.pop(context);
                    },
                    child: Text('Done'.tr(context)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}


