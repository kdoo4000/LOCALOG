import 'package:flutter/material.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/premium_ui.dart';
import '../../../models/place_candidate.dart';
import '../data/route_repository_provider.dart';
import '../domain/route_download_template.dart';
import '../domain/route_place.dart';
import '../domain/travel_route.dart';
import '../../trip_planning/presentation/place_search_map_screen.dart';
import 'place_detail_screen.dart';
import 'widgets/route_stop_edit_tile.dart';

class RouteDownloadEditScreen extends StatefulWidget {
  const RouteDownloadEditScreen({
    super.key,
    required this.routeId,
    this.createNewCopy = false,
  });

  final String routeId;
  final bool createNewCopy;

  @override
  State<RouteDownloadEditScreen> createState() =>
      _RouteDownloadEditScreenState();
}

class _RouteDownloadEditScreenState extends State<RouteDownloadEditScreen> {
  final _repository = routeRepository;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  TravelRoute? _route;
  List<RoutePlace> _places = [];
  RouteVisibility _visibility = RouteVisibility.public;
  bool _isSaving = false;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _loadRouteCopy();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadRouteCopy() async {
    TravelRoute? route;
    try {
      route = widget.createNewCopy
          ? await _repository.getSourceRouteById(widget.routeId)
          : await _repository.getRouteById(widget.routeId);
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
      return;
    }
    if (!mounted) {
      return;
    }

    if (route == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.strings.routeNotFound)));
      Navigator.of(context).pop(false);
      return;
    }
    final loadedRoute = widget.createNewCopy
        ? withoutCreatorMediaAndPersonalData(route)
        : route;

    setState(() {
      _route = loadedRoute;
      _titleController.text = loadedRoute.title;
      _descriptionController.text = loadedRoute.description;
      _visibility = widget.createNewCopy
          ? RouteVisibility.private
          : loadedRoute.visibility;
      _places = [...loadedRoute.places]
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    });
  }

  Future<void> _save() async {
    final route = _route;
    if (route == null || _places.isEmpty) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final orderedPlaces = [
      for (var index = 0; index < _places.length; index += 1)
        _places[index].copyWith(orderIndex: index),
    ];
    final updated = route.copyWith(
      title: _titleController.text.trim().isEmpty
          ? route.title
          : _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      places: orderedPlaces,
      visibility: widget.createNewCopy || route.isDownloadedCopy
          ? RouteVisibility.private
          : _visibility,
      isDownloaded: true,
    );
    try {
      if (widget.createNewCopy) {
        final copy = await _repository.downloadRoute(route.id);
        final copiedPlaces = [...copy.places]
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
        final copiedIdBySourceId = <String, String>{
          for (
            var index = 0;
            index < route.places.length && index < copiedPlaces.length;
            index++
          )
            route.places[index].id: copiedPlaces[index].id,
        };
        final mergedPlaces = <RoutePlace>[
          for (final place in orderedPlaces)
            place.copyWith(id: copiedIdBySourceId[place.id] ?? place.id),
        ];
        await _repository.updateDownloadedRoute(
          updated.copyWith(
            id: copy.id,
            sourceRouteId: copy.sourceRouteId,
            downloadedCopy: true,
            places: mergedPlaces,
            coverImageUrl: null,
            coverImageStoragePath: null,
          ),
        );
      } else {
        await _repository.updateDownloadedRoute(updated);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('로그 저장에 실패했습니다: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _removePlace(RoutePlace place) {
    if (_places.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.routeNeedsOnePlace)),
      );
      return;
    }

    setState(() {
      _places = _places.where((item) => item.id != place.id).toList();
    });
  }

  void _reorderPlaces(int oldIndex, int newIndex) {
    setState(() {
      final item = _places.removeAt(oldIndex);
      _places.insert(newIndex, item);
    });
  }

  Future<bool> _confirmSwipeRemove() async {
    if (_places.length > 1) {
      return true;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.strings.routeNeedsOnePlace)));
    return false;
  }

  Future<void> _showEditPlaceDialog(RoutePlace place) async {
    final updatedPlace = await Navigator.of(context).push<RoutePlace>(
      MaterialPageRoute(builder: (_) => _PlaceDetailsEditScreen(place: place)),
    );

    if (updatedPlace == null || !mounted) {
      return;
    }

    setState(() {
      _places = [
        for (final item in _places)
          if (item.id == place.id) updatedPlace else item,
      ];
    });
  }

  Future<PlaceCandidate?> _choosePlace() {
    return Navigator.of(context).push<PlaceCandidate>(
      MaterialPageRoute(builder: (_) => const PlaceSearchMapScreen()),
    );
  }

  RoutePlace _routePlaceFromCandidate(
    PlaceCandidate candidate, {
    RoutePlace? existing,
  }) {
    final category = candidate.category?.trim();
    return RoutePlace(
      id: existing?.id ?? 'custom-${DateTime.now().microsecondsSinceEpoch}',
      placeProvider: candidate.source,
      externalPlaceId: candidate.id,
      sourceCategory: candidate.sourceCategory,
      name: candidate.displayName,
      category: category?.isNotEmpty == true ? category! : '장소',
      orderIndex: existing?.orderIndex ?? _places.length,
      address: candidate.address,
      visitedAt: existing?.visitedAt,
      memo: existing?.memo,
      latitude: candidate.latitude,
      longitude: candidate.longitude,
      estimatedCostWon: existing?.estimatedCostWon,
      photoUrls: existing?.photoUrls ?? const [],
      photoStoragePaths: existing?.photoStoragePaths ?? const [],
      purchasedItems: existing?.purchasedItems ?? const [],
    );
  }

  Future<void> _showAddPlaceDialog() async {
    final candidate = await _choosePlace();
    if (candidate == null || !mounted) return;

    final place = _routePlaceFromCandidate(candidate);

    setState(() {
      _places = [..._places, place];
    });
  }

  Future<void> _changePlace(RoutePlace place) async {
    final candidate = await _choosePlace();
    if (candidate == null || !mounted) return;
    final updated = _routePlaceFromCandidate(candidate, existing: place);
    setState(() {
      _places = [
        for (final item in _places)
          if (item.id == place.id) updated else item,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final route = _route;

    return Scaffold(
      appBar: AppBar(title: Text(strings.editRouteTitle)),
      bottomNavigationBar: route == null || _loadError != null
          ? null
          : AppStickyActionBar(
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? strings.saving : strings.saveRoute),
              ),
            ),
      body: _loadError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 40),
                  const SizedBox(height: 12),
                  const Text('로그를 불러오지 못했습니다.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      setState(() => _loadError = null);
                      _loadRouteCopy();
                    },
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            )
          : route == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(
                          strings.customizeYourRoute,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          strings.customizeYourRouteSubtitle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.45,
                              ),
                        ),
                        if (widget.createNewCopy) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.privacy_tip_outlined,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    strings.routeImportPrivacyNotice,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onPrimaryContainer,
                                          height: 1.45,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        TextField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: strings.routeTitleLabel,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            labelText: strings.routeDescriptionLabel,
                            border: const OutlineInputBorder(),
                          ),
                          minLines: 2,
                          maxLines: 4,
                        ),
                        if (route.isCreatedByCurrentUser &&
                            !route.isDownloadedCopy &&
                            !widget.createNewCopy) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<RouteVisibility>(
                            initialValue: _visibility,
                            decoration: const InputDecoration(
                              labelText: '공개 범위',
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
                            onChanged: _isSaving
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setState(() => _visibility = value);
                                    }
                                  },
                          ),
                        ],
                        const SizedBox(height: 18),
                        OutlinedButton.icon(
                          onPressed: _showAddPlaceDialog,
                          icon: const Icon(Icons.add_location_alt_outlined),
                          label: Text(strings.addPlace),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          strings.includedStops,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          strings.routeEditGestureHelp,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          primary: false,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          proxyDecorator: (child, index, animation) => child,
                          itemCount: _places.length,
                          onReorderItem: _reorderPlaces,
                          itemBuilder: (context, index) {
                            final place = _places[index];

                            return Padding(
                              key: ValueKey('download-place-${place.id}'),
                              padding: const EdgeInsets.only(bottom: 10),
                              child: RouteStopDismissible(
                                dismissKey: ValueKey(
                                  'download-dismiss-${place.id}',
                                ),
                                enabled: _places.length > 1,
                                confirmDismiss: _confirmSwipeRemove,
                                onDismissed: () => _removePlace(place),
                                child: ReorderableDelayedDragStartListener(
                                  index: index,
                                  child: RouteStopEditTile(
                                    index: index,
                                    title: place.name,
                                    subtitle: _placeSubtitle(context, place),
                                    onTap: () =>
                                        openPlaceDetail(context, place),
                                    onEdit: () => _showEditPlaceDialog(place),
                                    onChoosePlace: () => _changePlace(place),
                                    placeSelected: true,
                                    showDragHandle: false,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class RouteDownloadEditArguments {
  const RouteDownloadEditArguments({
    required this.routeId,
    this.createNewCopy = false,
  });

  final String routeId;
  final bool createNewCopy;
}

class _PlaceDetailsEditScreen extends StatefulWidget {
  const _PlaceDetailsEditScreen({required this.place});

  final RoutePlace place;

  @override
  State<_PlaceDetailsEditScreen> createState() =>
      _PlaceDetailsEditScreenState();
}

class _PlaceDetailsEditScreenState extends State<_PlaceDetailsEditScreen> {
  final _memoController = TextEditingController();
  final _costController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _memoController.text = widget.place.memo ?? '';
    _costController.text = widget.place.estimatedCostWon?.toString() ?? '';
  }

  @override
  void dispose() {
    _memoController.dispose();
    _costController.dispose();
    super.dispose();
  }

  void _submit() {
    final costText = _costController.text.trim().replaceAll(',', '');
    final estimatedCost = costText.isEmpty ? null : int.tryParse(costText);
    if (costText.isNotEmpty && estimatedCost == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.strings.invalidCost)));
      return;
    }

    Navigator.of(context).pop(
      widget.place.copyWith(
        memo: _memoController.text.trim().isEmpty
            ? null
            : _memoController.text.trim(),
        estimatedCostWon: estimatedCost,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      appBar: AppBar(title: Text(strings.editPlace)),
      bottomNavigationBar: AppStickyActionBar(
        child: FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined),
          label: Text(strings.saveRoute),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            children: [
              _LockedPlaceSummary(place: widget.place),
              const SizedBox(height: 24),
              TextField(
                controller: _memoController,
                decoration: InputDecoration(
                  labelText: strings.placeDescription,
                  hintText: strings.optional,
                ),
                minLines: 1,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _costController,
                decoration: InputDecoration(
                  labelText: strings.estimatedCostWon,
                  hintText: strings.costHint,
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LockedPlaceSummary extends StatelessWidget {
  const _LockedPlaceSummary({required this.place});

  final RoutePlace place;

  @override
  Widget build(BuildContext context) {
    final address = place.address;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              place.name,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              address == null || address.isEmpty
                  ? place.displayCategory
                  : '${place.displayCategory} · $address',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

String _placeSubtitle(BuildContext context, RoutePlace place) {
  final parts = <String>[place.displayCategory];
  if (place.memo != null && place.memo!.isNotEmpty) {
    parts.add(place.memo!);
  }
  if (place.estimatedCostWon != null) {
    parts.add('${context.strings.estimatedCost} ₩${place.estimatedCostWon}');
  }

  return parts.join(' · ');
}
