import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/premium_ui.dart';
import '../../../models/photo_metadata.dart';
import '../../../services/exif_metadata_reader.dart';
import '../../../services/original_media_picker.dart';
import '../../route_search/data/route_repository_provider.dart';
import '../../route_search/domain/route_place.dart';
import '../../route_search/domain/travel_route.dart';
import '../data/travel_plan_repository_provider.dart';
import '../domain/travel_plan.dart';

class PlannedRouteLogCreateScreen extends StatefulWidget {
  const PlannedRouteLogCreateScreen({
    super.key,
    required this.route,
    required this.day,
    required this.regions,
  });

  final PlannedRoute route;
  final TravelPlanDay day;
  final List<String> regions;

  @override
  State<PlannedRouteLogCreateScreen> createState() =>
      _PlannedRouteLogCreateScreenState();
}

class _PlannedRouteLogCreateScreenState
    extends State<PlannedRouteLogCreateScreen> {
  final _picker = ImagePicker();
  final _originalMediaPicker = const OriginalMediaPicker();
  final _metadataReader = ExifMetadataReader();
  final _routeRepository = routeRepository;
  final _planRepository = travelPlanRepository;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final Map<String, List<_NodePhoto>> _photosByPlaceId;
  RouteVisibility _visibility = RouteVisibility.public;
  String? _coverPhotoPath;
  String? _readingPlaceId;
  bool _saving = false;

  List<RoutePlace> get _places =>
      [...widget.route.places]
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.route.title);
    _descriptionController = TextEditingController();
    _photosByPlaceId = {
      for (final place in widget.route.places) place.id: <_NodePhoto>[],
    };
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _addPhotos(RoutePlace place) async {
    setState(() => _readingPlaceId = place.id);
    try {
      var files = await _originalMediaPicker.pickImages();
      if (files.isEmpty) {
        files = await _picker.pickMultiImage(requestFullMetadata: true);
      }
      if (files.isEmpty || !mounted) {
        setState(() => _readingPlaceId = null);
        return;
      }

      final usedPaths = _photosByPlaceId.values
          .expand((photos) => photos)
          .map((photo) => photo.file.path)
          .toSet();
      final added = <_NodePhoto>[];
      for (final file in files) {
        if (usedPaths.contains(file.path)) continue;
        PhotoMetadata metadata;
        try {
          metadata = await _metadataReader.read(file);
        } catch (_) {
          metadata = PhotoMetadata(fileName: file.name);
        }
        added.add(_NodePhoto(file: file, metadata: metadata));
        usedPaths.add(file.path);
      }
      if (!mounted) return;
      setState(() {
        _photosByPlaceId[place.id]!.addAll(added);
        _coverPhotoPath ??= added.firstOrNull?.file.path;
        _readingPlaceId = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _readingPlaceId = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('사진을 불러오지 못했습니다: $error')));
    }
  }

  void _removePhoto(String placeId, _NodePhoto photo) {
    setState(() {
      _photosByPlaceId[placeId]!.remove(photo);
      if (_coverPhotoPath == photo.file.path) {
        _coverPhotoPath = _photosByPlaceId.values
            .expand((photos) => photos)
            .firstOrNull
            ?.file
            .path;
      }
    });
  }

  Future<void> _save() async {
    final missingPlaces = _places
        .where((place) => _photosByPlaceId[place.id]!.isEmpty)
        .toList();
    if (missingPlaces.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('모든 장소에 사진을 추가해 주세요. (${missingPlaces.length}곳 남음)'),
        ),
      );
      return;
    }
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그 제목을 입력해 주세요.')));
      return;
    }

    setState(() => _saving = true);
    try {
      final log = buildLogFromPlannedRoute(
        route: widget.route,
        day: widget.day,
        regions: widget.regions,
        authorName: context.strings.me,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        visibility: _visibility,
        coverPhotoPath: _coverPhotoPath,
        photosByPlaceId: {
          for (final entry in _photosByPlaceId.entries)
            entry.key: [
              for (final photo in entry.value)
                PlannedNodePhoto(
                  path: photo.file.path,
                  takenAt: photo.metadata.takenAt,
                ),
            ],
        },
      );
      final saved = await _routeRepository.saveCreatedRoute(log);
      final updatedPlan = await _planRepository.linkCompletedLog(
        planDayId: widget.day.id,
        logId: saved.id,
      );
      if (!mounted) return;
      await Navigator.of(context).popAndPushNamed(
        RouteNames.routeDetail,
        result: updatedPlan,
        arguments: saved.id,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('로그를 저장하지 못했습니다: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final missingCount = _places
        .where((place) => _photosByPlaceId[place.id]!.isEmpty)
        .length;
    final completedCount = _places.length - missingCount;
    return Scaffold(
      appBar: AppBar(title: const Text('장소별 사진 추가')),
      bottomNavigationBar: AppStickyActionBar(
        child: FilledButton.icon(
          onPressed: _saving || missingCount > 0 ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_stories_outlined),
          label: Text(
            _saving
                ? '로그 저장 중...'
                : missingCount == 0
                ? '로그 만들기'
                : '사진이 필요한 장소 $missingCount곳',
          ),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.readingWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(
                  '계획한 루트에 사진을 채워 로그를 만드세요',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '각 장소에 해당하는 사진을 한 장 이상 추가하면 루트 순서 그대로 로그가 만들어집니다.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: _places.isEmpty
                            ? 0
                            : completedCount / _places.length,
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$completedCount/${_places.length}곳 완료',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '로그 제목',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '로그 설명 (선택)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                for (var index = 0; index < _places.length; index++) ...[
                  _PlacePhotoCard(
                    index: index,
                    place: _places[index],
                    photos: _photosByPlaceId[_places[index].id]!,
                    selectedCoverPath: _coverPhotoPath,
                    isReading: _readingPlaceId == _places[index].id,
                    onAddPhotos: () => _addPhotos(_places[index]),
                    onSelectCover: (photo) =>
                        setState(() => _coverPhotoPath = photo.file.path),
                    onRemovePhoto: (photo) =>
                        _removePhoto(_places[index].id, photo),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
                DropdownButtonFormField<RouteVisibility>(
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
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _visibility = value);
                          }
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlacePhotoCard extends StatelessWidget {
  const _PlacePhotoCard({
    required this.index,
    required this.place,
    required this.photos,
    required this.selectedCoverPath,
    required this.isReading,
    required this.onAddPhotos,
    required this.onSelectCover,
    required this.onRemovePhoto,
  });

  final int index;
  final RoutePlace place;
  final List<_NodePhoto> photos;
  final String? selectedCoverPath;
  final bool isReading;
  final VoidCallback onAddPhotos;
  final ValueChanged<_NodePhoto> onSelectCover;
  final ValueChanged<_NodePhoto> onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: AppColors.white,
                child: Text('${index + 1}'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (place.address != null)
                      Text(
                        place.address!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.gray500,
                        ),
                      ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: isReading ? null : onAddPhotos,
                icon: isReading
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_photo_alternate_outlined),
                label: Text(photos.isEmpty ? '사진 추가' : '더 추가'),
              ),
            ],
          ),
          if (photos.isEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.yellow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('이 장소에서 찍은 사진을 추가해 주세요.'),
            ),
          ] else ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, photoIndex) {
                  final photo = photos[photoIndex];
                  final selected = photo.file.path == selectedCoverPath;
                  return Semantics(
                    button: true,
                    selected: selected,
                    label: '사진 ${photoIndex + 1} 대표 이미지로 선택',
                    child: GestureDetector(
                      onTap: () => onSelectCover(photo),
                      child: Container(
                        width: 92,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primaryBlue
                              : AppColors.gray200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: _XFileImage(file: photo.file),
                            ),
                            if (selected)
                              const Positioned(
                                left: 5,
                                bottom: 5,
                                child: Icon(
                                  Icons.star,
                                  size: 18,
                                  color: AppColors.accentLime,
                                ),
                              ),
                            Positioned(
                              right: 2,
                              top: 2,
                              child: Material(
                                color: const Color(0xB3000000),
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => onRemovePhoto(photo),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.close,
                                      size: 15,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
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
            const SizedBox(height: 6),
            Text(
              '사진 ${photos.length}장 · 사진을 누르면 대표 이미지로 설정',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.gray500),
            ),
          ],
        ],
      ),
    );
  }
}

class _XFileImage extends StatelessWidget {
  const _XFileImage({required this.file});

  final XFile file;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ColoredBox(
            color: AppColors.gray100,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return Image.memory(snapshot.data!, fit: BoxFit.cover);
      },
    );
  }
}

class _NodePhoto {
  const _NodePhoto({required this.file, required this.metadata});

  final XFile file;
  final PhotoMetadata metadata;
}

class PlannedNodePhoto {
  const PlannedNodePhoto({required this.path, this.takenAt});

  final String path;
  final DateTime? takenAt;
}

TravelRoute buildLogFromPlannedRoute({
  required PlannedRoute route,
  required TravelPlanDay day,
  required List<String> regions,
  required String authorName,
  required String title,
  required String description,
  required RouteVisibility visibility,
  required String? coverPhotoPath,
  required Map<String, List<PlannedNodePhoto>> photosByPlaceId,
}) {
  final effectiveRegions = regions
      .map((region) => region.trim())
      .where((region) => region.isNotEmpty)
      .toList();
  final sortedPlaces = [...route.places]
    ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  return TravelRoute(
    id: 'planned-log-${DateTime.now().microsecondsSinceEpoch}',
    title: title,
    description: description,
    city: effectiveRegions.firstOrNull ?? route.city,
    regions: effectiveRegions.isEmpty ? [route.city] : effectiveRegions,
    authorName: authorName,
    places: [
      for (var index = 0; index < sortedPlaces.length; index++)
        sortedPlaces[index].copyWith(
          id: 'planned-log-place-$index',
          orderIndex: index,
          visitedAt: _earliestTakenAt(
            photosByPlaceId[sortedPlaces[index].id] ?? const [],
          ),
          memo: null,
          photoUrls: [
            for (final photo
                in photosByPlaceId[sortedPlaces[index].id] ?? const [])
              photo.path,
          ],
          photoStoragePaths: const [],
          estimatedCostWon: null,
          purchasedItems: const [],
        ),
    ],
    tags: const ['여행기록'],
    upvoteRatio: 0,
    downloadCount: 0,
    estimatedDurationMinutes: route.estimatedDurationMinutes,
    coverImageUrl: coverPhotoPath,
    isDownloaded: true,
    isCreatedByCurrentUser: true,
    visibility: visibility,
    publishedAt: visibility == RouteVisibility.public ? DateTime.now() : null,
    travelDate: day.date,
    sourcePlannedRouteId: route.id,
  );
}

DateTime? _earliestTakenAt(List<PlannedNodePhoto> photos) {
  final dates =
      photos.map((photo) => photo.takenAt).whereType<DateTime>().toList()
        ..sort();
  return dates.firstOrNull;
}
