import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/app_language.dart';
import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../models/place_candidate.dart';
import '../../models/photo_metadata.dart';
import '../../services/exif_metadata_reader.dart';
import '../../services/naver_static_map_service.dart';
import '../../services/original_media_picker.dart';
import '../../services/place_candidate_service.dart';
import '../route_search/data/route_repository_provider.dart';
import '../route_search/domain/route_place.dart';
import '../route_search/domain/travel_route.dart';
import '../route_search/presentation/widgets/route_stop_edit_tile.dart';
import '../route_search/presentation/region_picker_screen.dart';
import '../trip_planning/data/travel_plan_repository_provider.dart';
import '../trip_planning/domain/travel_plan.dart';
import 'consecutive_grouping.dart';
import 'naver_dynamic_map.dart';

class PhotoLocationPage extends StatefulWidget {
  const PhotoLocationPage({super.key, this.plannedRoute, this.planDay});

  final PlannedRoute? plannedRoute;
  final TravelPlanDay? planDay;

  @override
  State<PhotoLocationPage> createState() => _PhotoLocationPageState();
}

class _PhotoLocationPageState extends State<PhotoLocationPage> {
  final _picker = ImagePicker();
  final _originalMediaPicker = const OriginalMediaPicker();
  final _metadataReader = ExifMetadataReader();
  final _placeCandidateService = const PlaceCandidateService();
  final _routeRepository = routeRepository;

  List<_PhotoEntry> _entries = const [];
  String? _selectedDateKey;
  bool _isReading = false;
  bool _isSavingRoute = false;
  String? _errorMessage;

  List<_PhotoDateGroup> get _dateGroups {
    final groupsByKey = <String, List<_PhotoEntry>>{};
    for (final entry in _entries) {
      groupsByKey.putIfAbsent(entry.dateKey, () => []).add(entry);
    }

    final groups = groupsByKey.entries.map((entry) {
      final photos = [...entry.value]..sort(_compareEntriesByTime);
      return _PhotoDateGroup(
        key: entry.key,
        label: photos.first.dateLabel,
        photos: photos,
      );
    }).toList();

    groups.sort((a, b) {
      if (a.key == _unknownDateKey) return 1;
      if (b.key == _unknownDateKey) return -1;
      return a.key.compareTo(b.key);
    });
    return groups;
  }

  _PhotoDateGroup? get _selectedGroup {
    final groups = _dateGroups;
    if (groups.isEmpty) {
      return null;
    }

    for (final group in groups) {
      if (group.key == _selectedDateKey) {
        return group;
      }
    }

    return groups.first;
  }

  Future<void> _pickPhotos() async {
    setState(() {
      _isReading = true;
      _errorMessage = null;
    });

    try {
      var photos = await _originalMediaPicker.pickImages();
      if (photos.isEmpty) {
        photos = await _picker.pickMultiImage(requestFullMetadata: true);
      }
      if (photos.isEmpty) {
        setState(() {
          _isReading = false;
        });
        return;
      }

      final entries = <_PhotoEntry>[];
      for (final photo in photos) {
        final metadata = await _metadataReader.read(photo);
        entries.add(_PhotoEntry(photo: photo, metadata: metadata));
      }
      entries.sort(_compareEntriesByTime);

      final firstGroupKey = entries.isEmpty ? null : entries.first.dateKey;
      setState(() {
        _entries = entries;
        _selectedDateKey = firstGroupKey;
        _isReading = false;
      });
    } catch (error) {
      setState(() {
        _isReading = false;
        _errorMessage = context.strings.photoReadFailed(error);
      });
    }
  }

  void _selectDate(String key) {
    setState(() {
      _selectedDateKey = key;
    });
  }

  void _showDetails(_PhotoEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.94,
          builder: (context, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                _PhotoDetailsSheet(
                  entry: entry,
                  placeCandidateService: _placeCandidateService,
                  onPlaceSelected: _selectPlace,
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _selectPlace(String entryId, PlaceCandidate candidate) {
    setState(() {
      _entries = [
        for (final entry in _entries)
          if (entry.id == entryId)
            entry.copyWith(selectedPlace: candidate)
          else
            entry,
      ];
    });
  }

  Future<void> _saveSelectedGroupAsRoute(_RouteDraftResult draft) async {
    if (draft.entries.isEmpty ||
        draft.entries.any((entry) => entry.selectedPlace == null)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.selectAllPlacesBeforeSave)),
        );
      }
      return;
    }

    setState(() {
      _isSavingRoute = true;
    });

    try {
      final route = _buildRouteFromPhotos(
        draft.title,
        draft.description,
        draft.regions,
        draft.tags,
        draft.visibility,
        draft.coverImagePath,
        draft.entries,
      );
      final savedRoute = await _routeRepository.saveCreatedRoute(route);
      final planDay = widget.planDay;
      if (planDay != null) {
        await travelPlanRepository.linkCompletedLog(
          planDayId: planDay.id,
          logId: savedRoute.id,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isSavingRoute = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.savedPhotoRouteToProfile)),
      );
      await Navigator.of(
        context,
      ).pushNamed(RouteNames.routeDetail, arguments: savedRoute.id);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSavingRoute = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.saveRouteFailed(error))),
      );
    }
  }

  TravelRoute _buildRouteFromPhotos(
    String title,
    String description,
    List<String> regions,
    List<String> tags,
    RouteVisibility visibility,
    String coverImagePath,
    List<_PhotoEntry> routeEntries,
  ) {
    final routeId = 'photo-route-${DateTime.now().microsecondsSinceEpoch}';
    final entryGroups = _groupConsecutiveEntriesByPlace(routeEntries);
    final places = <RoutePlace>[
      for (var index = 0; index < entryGroups.length; index += 1)
        _buildPlaceFromPhotos(entryGroups[index], index),
    ];

    return TravelRoute(
      id: routeId,
      title: title,
      description: description,
      city: regions.first,
      regions: regions,
      authorName: context.strings.me,
      places: places,
      tags: tags,
      upvoteRatio: 0,
      downloadCount: 0,
      estimatedDurationMinutes: entryGroups.length * 45,
      coverImageUrl: coverImagePath.isEmpty ? null : coverImagePath,
      isDownloaded: true,
      isCreatedByCurrentUser: true,
      visibility: visibility,
      publishedAt: visibility == RouteVisibility.public ? DateTime.now() : null,
      travelDate: widget.planDay?.date,
      sourcePlannedRouteId: widget.plannedRoute?.id,
    );
  }

  RoutePlace _buildPlaceFromPhotos(List<_PhotoEntry> entries, int index) {
    final entry = entries.first;
    final selectedPlace = entry.selectedPlace;
    final metadata = entry.metadata;
    final category = selectedPlace?.category;
    final photoPaths = entries
        .map((entry) => entry.photo.path)
        .where((path) => path.isNotEmpty)
        .toList(growable: false);

    return RoutePlace(
      id: 'photo-place-${DateTime.now().microsecondsSinceEpoch}-$index',
      placeProvider: selectedPlace?.source,
      externalPlaceId: selectedPlace?.id,
      name: selectedPlace?.displayName ?? context.strings.photoStop(index),
      category: category == null || category.isEmpty
          ? context.strings.photoSpot
          : category,
      orderIndex: index,
      address: _nullIfEmpty(selectedPlace?.address),
      visitedAt: metadata.takenAt,
      memo: null,
      // Photo GPS is the capture point, not the canonical place position.
      latitude: selectedPlace?.latitude,
      longitude: selectedPlace?.longitude,
      photoUrls: photoPaths,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final selectedGroup = _selectedGroup;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            Text(
              strings.photoTitle,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              strings.photoSubtitle,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isReading ? null : _pickPhotos,
              icon: _isReading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_library_outlined),
              label: Text(
                _isReading ? strings.readingPhotos : strings.choosePhotos,
              ),
            ),
            const SizedBox(height: 20),
            if (_errorMessage != null) _MessagePanel(message: _errorMessage!),
            if (_entries.isEmpty)
              const _EmptyState()
            else ...[
              _SummaryPanel(entries: _entries),
              const SizedBox(height: 16),
              _DateSelector(
                groups: _dateGroups,
                selectedKey: selectedGroup?.key,
                onSelected: _selectDate,
              ),
              const SizedBox(height: 12),
              _SaveRoutePanel(
                group: selectedGroup,
                isSaving: _isSavingRoute,
                placeCandidateService: _placeCandidateService,
                onPlaceSelected: _selectPlace,
                onSaveDraft: _isSavingRoute ? null : _saveSelectedGroupAsRoute,
                plannedRoute: widget.plannedRoute,
              ),
              const SizedBox(height: 16),
              if (selectedGroup != null) ...[
                _MultiMapPanel(group: selectedGroup),
                const SizedBox(height: 16),
                _PhotoGrid(group: selectedGroup, onPhotoTap: _showDetails),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.entries});

  final List<_PhotoEntry> entries;

  @override
  Widget build(BuildContext context) {
    final locatedCount = entries
        .where((entry) => entry.metadata.hasLocation)
        .length;
    return _Panel(
      title: context.strings.selectedPhotos,
      children: [
        _InfoRow(label: context.strings.photos, value: '${entries.length}'),
        _InfoRow(label: context.strings.withGps, value: '$locatedCount'),
        _InfoRow(
          label: context.strings.withoutGps,
          value: '${entries.length - locatedCount}',
        ),
      ],
    );
  }
}

class _DateSelector extends StatelessWidget {
  const _DateSelector({
    required this.groups,
    required this.selectedKey,
    required this.onSelected,
  });

  final List<_PhotoDateGroup> groups;
  final String? selectedKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: groups.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final group = groups[index];
          return ChoiceChip(
            label: Text(
              '${_displayGroupLabel(context, group)} (${group.photos.length})',
            ),
            selected: group.key == selectedKey,
            onSelected: (_) => onSelected(group.key),
          );
        },
      ),
    );
  }
}

class _SaveRoutePanel extends StatelessWidget {
  const _SaveRoutePanel({
    required this.group,
    required this.isSaving,
    required this.placeCandidateService,
    required this.onPlaceSelected,
    required this.onSaveDraft,
    this.plannedRoute,
  });

  final _PhotoDateGroup? group;
  final bool isSaving;
  final PlaceCandidateService placeCandidateService;
  final void Function(String entryId, PlaceCandidate candidate) onPlaceSelected;
  final ValueChanged<_RouteDraftResult>? onSaveDraft;
  final PlannedRoute? plannedRoute;

  @override
  Widget build(BuildContext context) {
    final group = this.group;
    final photoCount = group?.photos.length ?? 0;
    final groupFingerprint = group == null
        ? ''
        : group.photos.map((entry) => entry.id).join('-');

    return _Panel(
      title: context.strings.createRoute,
      children: [
        Text(
          group == null
              ? context.strings.selectPhotoDateToCreateRoute
              : context.strings.reviewPhotoStops(photoCount),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.black54),
        ),
        if (group != null) ...[
          const SizedBox(height: 14),
          _RouteDraftInlineEditor(
            key: ValueKey('route-draft-editor-${group.key}-$groupFingerprint'),
            initialTitle:
                plannedRoute?.title ??
                context.strings.photoRouteTitle(
                  _displayGroupLabel(context, group),
                ),
            initialDescription: '',
            initialRegions: plannedRoute?.city.isNotEmpty == true
                ? [plannedRoute!.city]
                : const [],
            initialTags: [context.strings.photoTag, context.strings.localTag],
            entries: group.photos,
            isSaving: isSaving,
            placeCandidateService: placeCandidateService,
            onPlaceSelected: onPlaceSelected,
            onSave: onSaveDraft,
          ),
        ],
      ],
    );
  }
}

class _RouteDraftResult {
  const _RouteDraftResult({
    required this.title,
    required this.description,
    required this.regions,
    required this.tags,
    required this.visibility,
    required this.coverImagePath,
    required this.entries,
  });

  final String title;
  final String description;
  final List<String> regions;
  final List<String> tags;
  final RouteVisibility visibility;
  final String coverImagePath;
  final List<_PhotoEntry> entries;
}

class _RouteDraftInlineEditor extends StatefulWidget {
  const _RouteDraftInlineEditor({
    super.key,
    required this.initialTitle,
    required this.initialDescription,
    required this.initialRegions,
    required this.initialTags,
    required this.entries,
    required this.isSaving,
    required this.placeCandidateService,
    required this.onPlaceSelected,
    required this.onSave,
  });

  final String initialTitle;
  final String initialDescription;
  final List<String> initialRegions;
  final List<String> initialTags;
  final List<_PhotoEntry> entries;
  final bool isSaving;
  final PlaceCandidateService placeCandidateService;
  final void Function(String entryId, PlaceCandidate candidate) onPlaceSelected;
  final ValueChanged<_RouteDraftResult>? onSave;

  @override
  State<_RouteDraftInlineEditor> createState() =>
      _RouteDraftInlineEditorState();
}

class _RouteDraftInlineEditorState extends State<_RouteDraftInlineEditor> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _tagsController;
  late List<_PhotoEntry> _entries;
  late List<String> _tags;
  late List<String> _regions;
  RouteVisibility _visibility = RouteVisibility.public;
  bool _regionSelectedManually = false;
  String? _selectedCoverEntryId;
  String? _editingEntryId;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descriptionController = TextEditingController(
      text: widget.initialDescription,
    );
    _tagsController = TextEditingController();
    _tags = [...widget.initialTags];
    _regions = [...widget.initialRegions];
    _entries = [...widget.entries];
    _selectedCoverEntryId = _entries.firstOrNull?.id;
    _applySuggestedRegion();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _RouteDraftInlineEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    final latestEntriesById = {
      for (final entry in widget.entries) entry.id: entry,
    };
    _entries = [
      for (final entry in _entries)
        if (latestEntriesById.containsKey(entry.id))
          entry.copyWith(
            selectedPlace: latestEntriesById[entry.id]!.selectedPlace,
          ),
    ];
  }

  void _reorderEntries(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }

      final entry = _entries.removeAt(oldIndex);
      _entries.insert(newIndex, entry);
    });
  }

  void _removeEntry(_PhotoEntry entry) {
    if (_entries.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.atLeastOneStopRequired)),
      );
      return;
    }

    setState(() {
      _entries = _entries.where((item) => item.id != entry.id).toList();
      if (_selectedCoverEntryId == entry.id) {
        _selectedCoverEntryId = _entries.firstOrNull?.id;
      }
      if (_editingEntryId == entry.id) {
        _editingEntryId = null;
      }
      _applySuggestedRegion();
    });
  }

  void _save() {
    final onSave = widget.onSave;
    if (onSave == null) {
      return;
    }
    if (_entries.any((entry) => entry.selectedPlace == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.selectAllPlacesBeforeSave)),
      );
      return;
    }

    final title = _titleController.text.trim().isEmpty
        ? widget.initialTitle
        : _titleController.text.trim();
    final description = _descriptionController.text.trim().isEmpty
        ? widget.initialDescription
        : _descriptionController.text.trim();
    if (_regions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('지역을 하나 이상 선택해 주세요.')));
      return;
    }
    _addTag();
    onSave(
      _RouteDraftResult(
        title: title,
        description: description,
        regions: _regions,
        tags: _tags,
        visibility: _visibility,
        coverImagePath:
            _entries
                .where((entry) => entry.id == _selectedCoverEntryId)
                .firstOrNull
                ?.photo
                .path ??
            '',
        entries: _entries,
      ),
    );
  }

  void _selectPlace(String entryId, PlaceCandidate candidate) {
    setState(() {
      _entries = [
        for (final entry in _entries)
          if (entry.id == entryId)
            entry.copyWith(selectedPlace: candidate)
          else
            entry,
      ];
      _editingEntryId = entryId;
      _applySuggestedRegion();
    });
    widget.onPlaceSelected(entryId, candidate);
  }

  void _editPlace(_PhotoEntry entry) {
    setState(() {
      _editingEntryId = _editingEntryId == entry.id ? null : entry.id;
    });
  }

  void _addTag() {
    final tag = _tagsController.text.trim().replaceFirst(RegExp(r'^#'), '');
    if (tag.isEmpty || _tags.contains(tag)) {
      _tagsController.clear();
      return;
    }
    if (_tags.length >= 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('태그는 최대 5개까지 추가할 수 있어요.')));
      return;
    }
    setState(() {
      _tags = [..._tags, tag];
      _tagsController.clear();
    });
  }

  Future<void> _selectRegion() async {
    final regions = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => RegionPickerScreen(initialRegions: _regions),
      ),
    );
    if (regions != null && mounted) {
      setState(() {
        _regionSelectedManually = true;
        _regions = regions;
      });
    }
  }

  void _applySuggestedRegion() {
    if (_regionSelectedManually) return;
    final regions = inferRegionsFromAddresses(
      _entries
          .map((entry) => entry.selectedPlace?.address ?? '')
          .where((address) => address.isNotEmpty),
    );
    if (regions.isNotEmpty) {
      _regions = regions;
    }
  }

  @override
  Widget build(BuildContext context) {
    final missingPlaceCount = _entries
        .where((entry) => entry.selectedPlace == null)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '대표 이미지',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _entries.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final entry = _entries[index];
              final selected = entry.id == _selectedCoverEntryId;
              return GestureDetector(
                onTap: () => setState(() => _selectedCoverEntryId = entry.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 84,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primaryBlue
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: _PhotoImage(photo: entry.photo, cacheWidth: 240),
                      ),
                      if (selected)
                        const Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: EdgeInsets.all(5),
                            child: CircleAvatar(
                              radius: 10,
                              backgroundColor: AppColors.accentLime,
                              child: Icon(
                                Icons.check,
                                size: 14,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: context.strings.routeTitleLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: context.strings.routeDescriptionLabel,
            border: const OutlineInputBorder(),
          ),
          minLines: 2,
          maxLines: 4,
        ),
        const SizedBox(height: 12),
        RegionSelectionField(
          regions: _regions,
          onTap: _selectRegion,
          emptyText: '시·도와 시·군·구 선택',
          helperText: '사진 속 장소가 속한 모든 지역을 자동 선택해요.',
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _tagsController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addTag(),
                decoration: InputDecoration(
                  labelText: '태그',
                  hintText: '태그 입력',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: '태그 추가',
                    onPressed: _tags.length >= 5 ? null : _addTag,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<RouteVisibility>(
                initialValue: _visibility,
                decoration: const InputDecoration(
                  labelText: '공개 범위',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: RouteVisibility.public,
                    child: Text('전체 공개'),
                  ),
                  DropdownMenuItem(
                    value: RouteVisibility.private,
                    child: Text('나만 보기'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _visibility = value);
                },
              ),
            ),
          ],
        ),
        if (_tags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in _tags)
                InputChip(
                  label: Text('#$tag'),
                  onDeleted: () => setState(
                    () => _tags = _tags.where((item) => item != tag).toList(),
                  ),
                ),
            ],
          ),
        ],
        if (missingPlaceCount > 0) ...[
          const SizedBox(height: 14),
          _MessagePanel(
            message: context.strings.missingPlaceWarning(missingPlaceCount),
          ),
        ],
        const SizedBox(height: 18),
        Text(
          context.strings.includedStops,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        ReorderableListView.builder(
          shrinkWrap: true,
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _entries.length,
          onReorder: _reorderEntries,
          itemBuilder: (context, index) {
            final entry = _entries[index];

            return Padding(
              key: ValueKey('route-draft-${entry.id}'),
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  RouteStopEditTile(
                    index: index,
                    title:
                        entry.selectedPlace?.displayName ??
                        context.strings.photoStop(index),
                    subtitle:
                        '${entry.timeLabel} · ${entry.selectedPlace?.displayDetail ?? context.strings.notSelected}',
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: _PhotoImage(photo: entry.photo),
                      ),
                    ),
                    onRemove: () => _removeEntry(entry),
                    onChoosePlace: () => _editPlace(entry),
                    placeSelected: entry.selectedPlace != null,
                  ),
                  if (_editingEntryId == entry.id) ...[
                    const SizedBox(height: 10),
                    _RouteDraftPlaceEditor(
                      entry: entry,
                      placeCandidateService: widget.placeCandidateService,
                      onPlaceSelected: _selectPlace,
                      onClose: () {
                        setState(() {
                          _editingEntryId = null;
                        });
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 2),
        FilledButton.icon(
          onPressed: widget.isSaving || missingPlaceCount > 0 ? null : _save,
          icon: widget.isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(
            widget.isSaving
                ? context.strings.savingRoute
                : context.strings.saveRoute,
          ),
        ),
      ],
    );
  }
}

class _RouteDraftPlaceEditor extends StatelessWidget {
  const _RouteDraftPlaceEditor({
    required this.entry,
    required this.placeCandidateService,
    required this.onPlaceSelected,
    required this.onClose,
  });

  final _PhotoEntry entry;
  final PlaceCandidateService placeCandidateService;
  final void Function(String entryId, PlaceCandidate candidate) onPlaceSelected;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x0F000000),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.selectedPlace == null
                        ? context.strings.choosePlace
                        : context.strings.changePlace,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  tooltip: context.strings.close,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            _PhotoDetailsSheet(
              key: ValueKey(entry.id),
              entry: entry,
              placeCandidateService: placeCandidateService,
              onPlaceSelected: onPlaceSelected,
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.group, required this.onPhotoTap});

  final _PhotoDateGroup group;
  final ValueChanged<_PhotoEntry> onPhotoTap;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title:
          '${_displayGroupLabel(context, group)} ${context.strings.timelineSuffix}',
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: group.photos.length,
          itemBuilder: (context, index) {
            final entry = group.photos[index];
            return _PhotoTile(entry: entry, onTap: () => onPhotoTap(entry));
          },
        ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.entry, required this.onTap});

  final _PhotoEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black12,
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _PhotoImage(photo: entry.photo, cacheWidth: 320),
            if (entry.selectedPlace != null)
              Positioned(
                left: 4,
                right: 4,
                top: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xC6000000),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Text(
                      entry.selectedPlace!.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 4,
              right: 4,
              bottom: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x8F000000),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Text(
                    entry.timeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            if (!entry.metadata.hasLocation)
              const Positioned(
                top: 4,
                right: 4,
                child: Icon(Icons.location_off, color: Colors.white, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhotoImage extends StatelessWidget {
  const _PhotoImage({
    required this.photo,
    this.height,
    this.width,
    this.cacheWidth = 640,
  });

  final XFile photo;
  final double? height;
  final double? width;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _PhotoBytesCache.load(photo),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            height: height,
            width: width,
            child: const ColoredBox(
              color: Colors.black12,
              child: Center(
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          );
        }

        return Image.memory(
          snapshot.data!,
          height: height,
          width: width,
          fit: BoxFit.cover,
          cacheWidth: cacheWidth,
          filterQuality: FilterQuality.low,
          gaplessPlayback: true,
        );
      },
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.photo, this.height = 220});

  final XFile photo;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: _PhotoImage(
        photo: photo,
        height: height,
        width: double.infinity,
        cacheWidth: 900,
      ),
    );
  }
}

class _PhotoBytesCache {
  static final _cache = LinkedHashMap<String, Future<Uint8List>>();
  static const _maxEntries = 48;

  static Future<Uint8List> load(XFile photo) {
    final key = photo.path.isNotEmpty ? photo.path : photo.name;
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      return cached;
    }

    final future = photo.readAsBytes().catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      _cache.remove(key);
      return Error.throwWithStackTrace(error, stackTrace);
    });
    _cache[key] = future;
    if (_cache.length > _maxEntries) {
      _cache.remove(_cache.keys.first);
    }

    return future;
  }
}

class _PhotoDetailsSheet extends StatefulWidget {
  const _PhotoDetailsSheet({
    super.key,
    required this.entry,
    required this.placeCandidateService,
    required this.onPlaceSelected,
  });

  final _PhotoEntry entry;
  final PlaceCandidateService placeCandidateService;
  final void Function(String entryId, PlaceCandidate candidate) onPlaceSelected;

  @override
  State<_PhotoDetailsSheet> createState() => _PhotoDetailsSheetState();
}

class _PhotoDetailsSheetState extends State<_PhotoDetailsSheet> {
  Future<PlaceCandidateResult>? _candidateFuture;
  Future<PlaceCandidateResult>? _searchFuture;
  PlaceCandidate? _selectedPlace;
  final _searchController = TextEditingController();
  String? _searchQuery;

  @override
  void initState() {
    super.initState();
    _selectedPlace = widget.entry.selectedPlace;

    final metadata = widget.entry.metadata;
    if (metadata.hasLocation) {
      _candidateFuture = widget.placeCandidateService.findCandidates(
        latitude: metadata.latitude!,
        longitude: metadata.longitude!,
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PhotoPreview(photo: widget.entry.photo, height: 320),
        const SizedBox(height: 14),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: context.strings.searchPlace,
            hintText: context.strings.exampleCafe,
            suffixIcon: IconButton(
              onPressed: _searchPlace,
              tooltip: context.strings.searchPlace,
              icon: const Icon(Icons.search),
            ),
            border: const OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _searchPlace(),
        ),
        const SizedBox(height: 14),
        _PlaceCandidatePanel(
          metadata: widget.entry.metadata,
          selectedPlace: _selectedPlace,
          title: _searchQuery == null
              ? context.strings.suggestedPlaces
              : context.strings.placeSearchResults(_searchQuery!),
          candidateFuture: _searchFuture ?? _candidateFuture,
          onSelected: (candidate) {
            _selectPlace(candidate);
          },
        ),
      ],
    );
  }

  void _searchPlace() {
    final query = _searchController.text.trim();
    if (query.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.strings.enterPlaceName)));
      return;
    }

    final metadata = widget.entry.metadata;
    setState(() {
      _searchQuery = query;
      _searchFuture = widget.placeCandidateService.searchByKeyword(
        query,
        latitude: metadata.hasLocation ? metadata.latitude : null,
        longitude: metadata.hasLocation ? metadata.longitude : null,
      );
    });
  }

  void _selectPlace(PlaceCandidate candidate) {
    setState(() {
      _selectedPlace = candidate;
    });
    widget.onPlaceSelected(widget.entry.id, candidate);
  }
}

class _PlaceCandidatePanel extends StatelessWidget {
  const _PlaceCandidatePanel({
    required this.metadata,
    required this.selectedPlace,
    required this.title,
    required this.candidateFuture,
    required this.onSelected,
  });

  final PhotoMetadata metadata;
  final PlaceCandidate? selectedPlace;
  final String title;
  final Future<PlaceCandidateResult>? candidateFuture;
  final ValueChanged<PlaceCandidate> onSelected;

  @override
  Widget build(BuildContext context) {
    if (!metadata.hasLocation) {
      return const _MessagePanel(messageKey: _MessageKey.noGpsForSuggestions);
    }

    final future = candidateFuture;
    if (future == null) {
      return const _MessagePanel(
        messageKey: _MessageKey.placeSuggestionsUnavailable,
      );
    }

    return _Panel(
      title: title,
      children: [
        FutureBuilder<PlaceCandidateResult>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final result = snapshot.data;
            if (result == null) {
              return Text(context.strings.couldNotLoadPlaceSuggestions);
            }

            if (!result.isSuccess) {
              return Text(result.errorMessage!);
            }

            if (result.candidates.isEmpty) {
              return Text(context.strings.noMatchingPlaces);
            }

            return Column(
              children: [
                for (final candidate in result.candidates)
                  Material(
                    color: Colors.transparent,
                    child: RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: candidate.id,
                      groupValue: selectedPlace?.id,
                      onChanged: (_) => onSelected(candidate),
                      title: Text(
                        candidate.displayName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(candidate.displayDetail),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MultiMapPanel extends StatelessWidget {
  const _MultiMapPanel({required this.group});

  final _PhotoDateGroup group;

  @override
  Widget build(BuildContext context) {
    final points = group.photos
        .map((entry) => entry.mapPoint)
        .whereType<MapPoint>()
        .toList();

    if (points.isEmpty) {
      return const _MessagePanel(messageKey: _MessageKey.noGpsForDate);
    }

    return _Panel(
      title:
          '${_displayGroupLabel(context, group)} ${context.strings.dynamicMapSuffix}',
      children: [
        Text(
          context.strings.markerCount(points.length),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.black54),
        ),
        const SizedBox(height: 12),
        NaverDynamicMap(points: points),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.gray200),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({this.message, this.messageKey});

  final String? message;
  final _MessageKey? messageKey;

  @override
  Widget build(BuildContext context) {
    final resolvedMessage =
        message ??
        switch (messageKey) {
          _MessageKey.noGpsForSuggestions =>
            context.strings.noGpsForSuggestions,
          _MessageKey.placeSuggestionsUnavailable =>
            context.strings.placeSuggestionsUnavailable,
          _MessageKey.noGpsForDate => context.strings.noGpsForDate,
          _MessageKey.emptyPhotoState => context.strings.emptyPhotoState,
          null => '',
        };

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        border: Border.all(color: const Color(0xFFFFD54F)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(resolvedMessage),
    );
  }
}

enum _MessageKey {
  noGpsForSuggestions,
  placeSuggestionsUnavailable,
  noGpsForDate,
  emptyPhotoState,
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const _MessagePanel(messageKey: _MessageKey.emptyPhotoState);
  }
}

class _PhotoEntry {
  const _PhotoEntry({
    required this.photo,
    required this.metadata,
    this.selectedPlace,
  });

  final XFile photo;
  final PhotoMetadata metadata;
  final PlaceCandidate? selectedPlace;

  String get id {
    if (photo.path.isNotEmpty) {
      return photo.path;
    }

    return '${metadata.fileName}_${metadata.takenAt?.toIso8601String() ?? ''}';
  }

  MapPoint? get mapPoint {
    final place = selectedPlace;
    if (place != null && place.hasLocation) {
      return MapPoint(latitude: place.latitude!, longitude: place.longitude!);
    }

    if (metadata.hasLocation) {
      return MapPoint(
        latitude: metadata.latitude!,
        longitude: metadata.longitude!,
      );
    }

    return null;
  }

  _PhotoEntry copyWith({PlaceCandidate? selectedPlace}) {
    return _PhotoEntry(
      photo: photo,
      metadata: metadata,
      selectedPlace: selectedPlace ?? this.selectedPlace,
    );
  }

  String get dateKey {
    final takenAt = metadata.takenAt;
    if (takenAt == null) {
      return _unknownDateKey;
    }

    return '${takenAt.year}-${_two(takenAt.month)}-${_two(takenAt.day)}';
  }

  String get dateLabel {
    final takenAt = metadata.takenAt;
    if (takenAt == null) {
      return 'Unknown date';
    }

    return '${takenAt.year}.${_two(takenAt.month)}.${_two(takenAt.day)}';
  }

  String get timeLabel {
    final takenAt = metadata.takenAt;
    if (takenAt == null) {
      return '--:--';
    }

    return '${_two(takenAt.hour)}:${_two(takenAt.minute)}';
  }
}

List<List<_PhotoEntry>> _groupConsecutiveEntriesByPlace(
  List<_PhotoEntry> entries,
) {
  return groupConsecutiveByKey(entries, (entry) {
    final place = entry.selectedPlace;
    if (place == null) return null;

    final id = place.id.trim();
    if (id.isNotEmpty) return '${place.source}\u0000$id';
    return '${place.displayName.trim()}\u0000${place.address.trim()}';
  });
}

class _PhotoDateGroup {
  const _PhotoDateGroup({
    required this.key,
    required this.label,
    required this.photos,
  });

  final String key;
  final String label;
  final List<_PhotoEntry> photos;
}

const _unknownDateKey = 'unknown';

int _compareEntriesByTime(_PhotoEntry a, _PhotoEntry b) {
  final aTime = a.metadata.takenAt;
  final bTime = b.metadata.takenAt;
  if (aTime == null && bTime == null) {
    return a.metadata.fileName.compareTo(b.metadata.fileName);
  }
  if (aTime == null) return 1;
  if (bTime == null) return -1;
  return aTime.compareTo(bTime);
}

String _two(int value) => value.toString().padLeft(2, '0');

String _displayGroupLabel(BuildContext context, _PhotoDateGroup group) {
  if (group.key == _unknownDateKey) {
    return context.strings.unknownDate;
  }

  return group.label;
}

String? _nullIfEmpty(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }

  return value;
}
