import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/app_language.dart';
import '../../core/router/route_names.dart';
import '../../models/place_candidate.dart';
import '../../models/photo_metadata.dart';
import '../../services/exif_metadata_reader.dart';
import '../../services/naver_static_map_service.dart';
import '../../services/place_candidate_service.dart';
import '../route_search/data/mock_route_repository.dart';
import '../route_search/domain/route_place.dart';
import '../route_search/domain/travel_route.dart';
import 'naver_dynamic_map.dart';

class PhotoLocationPage extends StatefulWidget {
  const PhotoLocationPage({super.key});

  @override
  State<PhotoLocationPage> createState() => _PhotoLocationPageState();
}

class _PhotoLocationPageState extends State<PhotoLocationPage> {
  final _picker = ImagePicker();
  final _metadataReader = ExifMetadataReader();
  final _placeCandidateService = const PlaceCandidateService();
  final _routeRepository = const MockRouteRepository();

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
      final photos = await _picker.pickMultiImage(requestFullMetadata: true);
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

  Future<void> _saveSelectedGroupAsRoute() async {
    final group = _selectedGroup;
    if (group == null) {
      return;
    }

    final routeEntries = group.photos
        .where((entry) => entry.metadata.hasLocation || entry.selectedPlace != null)
        .toList();
    if (routeEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.chooseRoutablePhotosFirst)),
      );
      return;
    }

    setState(() {
      _isSavingRoute = true;
    });

    try {
      final route = _buildRouteFromPhotos(group, routeEntries);
      final savedRoute = await _routeRepository.saveCreatedRoute(route);

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.strings.saveRouteFailed(error))));
    }
  }

  TravelRoute _buildRouteFromPhotos(
    _PhotoDateGroup group,
    List<_PhotoEntry> routeEntries,
  ) {
    final routeId = 'photo-route-${DateTime.now().microsecondsSinceEpoch}';
    final places = <RoutePlace>[
      for (var index = 0; index < routeEntries.length; index += 1)
        _buildPlaceFromPhoto(routeEntries[index], index),
    ];

    return TravelRoute(
      id: routeId,
      title: context.strings.photoRouteTitle(_displayGroupLabel(context, group)),
      description: context.strings.photoRouteDescription(routeEntries.length),
      city: context.strings.myTrip,
      authorName: context.strings.me,
      places: places,
      tags: [context.strings.photoTag, context.strings.localTag],
      upvoteRatio: 1,
      downloadCount: 0,
      estimatedDurationMinutes: routeEntries.length * 45,
      isDownloaded: true,
    );
  }

  RoutePlace _buildPlaceFromPhoto(_PhotoEntry entry, int index) {
    final selectedPlace = entry.selectedPlace;
    final metadata = entry.metadata;
    final category = selectedPlace?.category;
    final photoPath = entry.photo.path;

    return RoutePlace(
      id: 'photo-place-${DateTime.now().microsecondsSinceEpoch}-$index',
      name: selectedPlace?.displayName ?? context.strings.photoStop(index),
      category: category == null || category.isEmpty
          ? context.strings.photoSpot
          : category,
      orderIndex: index,
      address: _nullIfEmpty(selectedPlace?.address),
      visitedAt: metadata.takenAt,
      memo: context.strings.takenAtFromFile(entry.timeLabel, metadata.fileName),
      latitude: metadata.latitude,
      longitude: metadata.longitude,
      photoUrls: photoPath.isEmpty ? const [] : [photoPath],
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final selectedGroup = _selectedGroup;

    return Scaffold(
      appBar: AppBar(title: const Text('LIKE LOCAL'), centerTitle: false),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              strings.photoTitle,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
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
              label: Text(_isReading ? strings.readingPhotos : strings.choosePhotos),
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
                onSave: _isSavingRoute
                    ? null
                    : () {
                        _saveSelectedGroupAsRoute();
                      },
              ),
              const SizedBox(height: 16),
              if (selectedGroup != null) ...[
                _MultiMapPanel(group: selectedGroup),
                const SizedBox(height: 16),
                _PhotoPlaceReviewPanel(
                  group: selectedGroup,
                  onPhotoTap: _showDetails,
                ),
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
    required this.onSave,
  });

  final _PhotoDateGroup? group;
  final bool isSaving;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final group = this.group;
    final routableCount =
        group?.photos
            .where(
              (entry) =>
                  entry.metadata.hasLocation || entry.selectedPlace != null,
            )
            .length ??
        0;

    return _Panel(
      title: context.strings.createRoute,
      children: [
        Text(
          group == null
              ? context.strings.selectPhotoDateToCreateRoute
              : context.strings.routablePhotoStops(routableCount),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.black54),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: routableCount == 0 ? null : onSave,
          icon: isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.route_outlined),
          label: Text(
            isSaving
                ? context.strings.savingRoute
                : context.strings.saveSelectedDayAsRoute,
          ),
        ),
      ],
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
      title: '${_displayGroupLabel(context, group)} ${context.strings.timelineSuffix}',
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

class _PhotoPlaceReviewPanel extends StatelessWidget {
  const _PhotoPlaceReviewPanel({
    required this.group,
    required this.onPhotoTap,
  });

  final _PhotoDateGroup group;
  final ValueChanged<_PhotoEntry> onPhotoTap;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: context.strings.assignPlaces,
      children: [
        Text(
          context.strings.assignPlacesHelp,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.black54),
        ),
        const SizedBox(height: 12),
        for (final entry in group.photos) ...[
          _PhotoPlaceReviewTile(
            entry: entry,
            onTap: () => onPhotoTap(entry),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _PhotoPlaceReviewTile extends StatelessWidget {
  const _PhotoPlaceReviewTile({required this.entry, required this.onTap});

  final _PhotoEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final placeName = entry.selectedPlace?.displayName;

    return Material(
      color: const Color(0x08000000),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: _PhotoImage(photo: entry.photo),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.timeLabel,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      placeName ?? context.strings.notSelected,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: placeName == null
                            ? Colors.black54
                            : Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!entry.metadata.hasLocation) ...[
                      const SizedBox(height: 4),
                      Text(
                        context.strings.noGpsForSuggestions,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: onTap,
                tooltip: placeName == null
                    ? context.strings.choosePlace
                    : context.strings.changePlace,
                icon: const Icon(Icons.edit_location_alt_outlined),
              ),
            ],
          ),
        ),
      ),
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
            FutureBuilder(
              future: entry.photo.readAsBytes(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }

                return Image.memory(snapshot.data!, fit: BoxFit.cover);
              },
            ),
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
  const _PhotoImage({required this.photo});

  final XFile photo;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: photo.readAsBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ColoredBox(
            color: Colors.black12,
            child: Center(
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        return Image.memory(snapshot.data!, fit: BoxFit.cover);
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
    return FutureBuilder(
      future: photo.readAsBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const CircularProgressIndicator(),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            snapshot.data!,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }
}

class _PhotoDetailsSheet extends StatefulWidget {
  const _PhotoDetailsSheet({
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
  PlaceCandidate? _selectedPlace;

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
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PhotoPreview(photo: widget.entry.photo, height: 320),
        const SizedBox(height: 16),
        _MetadataPanel(
          metadata: widget.entry.metadata,
          selectedPlace: _selectedPlace,
        ),
        const SizedBox(height: 16),
        _PlaceCandidatePanel(
          metadata: widget.entry.metadata,
          selectedPlace: _selectedPlace,
          candidateFuture: _candidateFuture,
          onSelected: (candidate) {
            _selectPlace(candidate);
          },
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _showManualPlaceDialog,
          icon: const Icon(Icons.edit_location_alt_outlined),
          label: Text(context.strings.enterPlaceManually),
        ),
      ],
    );
  }

  void _selectPlace(PlaceCandidate candidate) {
    setState(() {
      _selectedPlace = candidate;
    });
    widget.onPlaceSelected(widget.entry.id, candidate);
  }

  Future<void> _showManualPlaceDialog() async {
    final candidate = await showDialog<PlaceCandidate>(
      context: context,
      builder: (context) => const _ManualPlaceDialog(),
    );
    if (candidate == null) {
      return;
    }

    _selectPlace(candidate);
  }
}

class _ManualPlaceDialog extends StatefulWidget {
  const _ManualPlaceDialog();

  @override
  State<_ManualPlaceDialog> createState() => _ManualPlaceDialogState();
}

class _ManualPlaceDialogState extends State<_ManualPlaceDialog> {
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.strings.enterPlaceName)));
      return;
    }

    Navigator.of(context).pop(
      PlaceCandidate(
        id: 'manual-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        address: _addressController.text.trim(),
        source: 'manual',
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return AlertDialog(
      title: Text(strings.enterPlaceManually),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: strings.placeName,
                hintText: strings.exampleCafe,
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _categoryController,
              decoration: InputDecoration(
                labelText: strings.category,
                hintText: strings.categoryHint,
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: strings.address,
                hintText: strings.optional,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(strings.add)),
      ],
    );
  }
}

class _MetadataPanel extends StatelessWidget {
  const _MetadataPanel({required this.metadata, required this.selectedPlace});

  final PhotoMetadata metadata;
  final PlaceCandidate? selectedPlace;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: context.strings.photoDetails,
      children: [
        _InfoRow(label: context.strings.file, value: metadata.fileName),
        _InfoRow(
          label: context.strings.takenAt,
          value: metadata.hasTakenAt
              ? _formatDate(metadata.takenAt!)
              : context.strings.none,
        ),
        _InfoRow(
          label: context.strings.latitude,
          value: metadata.latitude?.toStringAsFixed(6) ?? context.strings.none,
        ),
        _InfoRow(
          label: context.strings.longitude,
          value: metadata.longitude?.toStringAsFixed(6) ?? context.strings.none,
        ),
        _InfoRow(
          label: context.strings.camera,
          value: [metadata.cameraMake, metadata.cameraModel]
              .whereType<String>()
              .where((value) => value.isNotEmpty)
              .join(' ')
              .ifEmpty(context.strings.none),
        ),
        _InfoRow(
          label: context.strings.place,
          value: selectedPlace?.displayName ?? context.strings.notSelected,
        ),
      ],
    );
  }
}

class _PlaceCandidatePanel extends StatelessWidget {
  const _PlaceCandidatePanel({
    required this.metadata,
    required this.selectedPlace,
    required this.candidateFuture,
    required this.onSelected,
  });

  final PhotoMetadata metadata;
  final PlaceCandidate? selectedPlace;
  final Future<PlaceCandidateResult>? candidateFuture;
  final ValueChanged<PlaceCandidate> onSelected;

  @override
  Widget build(BuildContext context) {
    if (!metadata.hasLocation) {
      return const _MessagePanel(
        messageKey: _MessageKey.noGpsForSuggestions,
      );
    }

    final future = candidateFuture;
    if (future == null) {
      return const _MessagePanel(
        messageKey: _MessageKey.placeSuggestionsUnavailable,
      );
    }

    return _Panel(
      title: context.strings.suggestedPlaces,
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
        .where((entry) => entry.metadata.hasLocation)
        .map(
          (entry) => MapPoint(
            latitude: entry.metadata.latitude!,
            longitude: entry.metadata.longitude!,
          ),
        )
        .toList();

    if (points.isEmpty) {
      return const _MessagePanel(
        messageKey: _MessageKey.noGpsForDate,
      );
    }

    return _Panel(
      title: '${_displayGroupLabel(context, group)} ${context.strings.dynamicMapSuffix}',
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
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
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
    final resolvedMessage = message ?? switch (messageKey) {
      _MessageKey.noGpsForSuggestions => context.strings.noGpsForSuggestions,
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
    return const _MessagePanel(
      messageKey: _MessageKey.emptyPhotoState,
    );
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

String _formatDate(DateTime date) {
  return '${date.year}.${_two(date.month)}.${_two(date.day)} '
      '${_two(date.hour)}:${_two(date.minute)}';
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

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
