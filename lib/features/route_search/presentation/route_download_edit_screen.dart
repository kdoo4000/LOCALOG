import 'package:flutter/material.dart';

import '../../../core/l10n/app_language.dart';
import '../../../models/place_candidate.dart';
import '../../../services/place_candidate_service.dart';
import '../data/route_repository_provider.dart';
import '../domain/route_download_template.dart';
import '../domain/route_place.dart';
import '../domain/travel_route.dart';
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
    final updatedPlace = await showDialog<RoutePlace>(
      context: context,
      builder: (context) => _PlaceDialog(
        title: context.strings.editPlace,
        actionLabel: context.strings.saveRoute,
        orderIndex: place.orderIndex,
        initialPlace: place,
      ),
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

  Future<void> _showAddPlaceDialog() async {
    final place = await showDialog<RoutePlace>(
      context: context,
      builder: (context) => _PlaceDialog(
        title: context.strings.addPlace,
        actionLabel: context.strings.add,
        orderIndex: _places.length,
      ),
    );

    if (place == null || !mounted) {
      return;
    }

    setState(() {
      _places = [..._places, place];
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final route = _route;

    return Scaffold(
      appBar: AppBar(title: Text(strings.editRouteTitle)),
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
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          strings.customizeYourRouteSubtitle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.black54, height: 1.45),
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
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          strings.routeEditGestureHelp,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.black54),
                        ),
                        const SizedBox(height: 10),
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          primary: false,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          itemCount: _places.length,
                          onReorderItem: _reorderPlaces,
                          itemBuilder: (context, index) {
                            final place = _places[index];

                            return Dismissible(
                              key: ValueKey('download-place-${place.id}'),
                              direction: DismissDirection.horizontal,
                              confirmDismiss: (_) => _confirmSwipeRemove(),
                              onDismissed: (_) => _removePlace(place),
                              background: const _SwipeDeleteBackground(
                                alignment: Alignment.centerLeft,
                              ),
                              secondaryBackground: const _SwipeDeleteBackground(
                                alignment: Alignment.centerRight,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: ReorderableDelayedDragStartListener(
                                  index: index,
                                  child: RouteStopEditTile(
                                    index: index,
                                    title: place.name,
                                    subtitle: _placeSubtitle(context, place),
                                    onEdit: () => _showEditPlaceDialog(place),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _isSaving ? strings.saving : strings.saveRoute,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SwipeDeleteBackground extends StatelessWidget {
  const _SwipeDeleteBackground({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == Alignment.centerLeft;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      alignment: alignment,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: isLeft ? TextDirection.ltr : TextDirection.rtl,
        children: [
          Icon(
            Icons.delete_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Text(
            context.strings.delete,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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

class _PlaceDialog extends StatefulWidget {
  const _PlaceDialog({
    required this.title,
    required this.actionLabel,
    required this.orderIndex,
    this.initialPlace,
  });

  final String title;
  final String actionLabel;
  final int orderIndex;
  final RoutePlace? initialPlace;

  @override
  State<_PlaceDialog> createState() => _PlaceDialogState();
}

class _PlaceDialogState extends State<_PlaceDialog> {
  final _placeCandidateService = const PlaceCandidateService();
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _addressController = TextEditingController();
  final _memoController = TextEditingController();
  final _costController = TextEditingController();
  Future<PlaceCandidateResult>? _searchFuture;
  PlaceCandidate? _selectedCandidate;

  bool get _isEditing => widget.initialPlace != null;

  @override
  void initState() {
    super.initState();
    final initialPlace = widget.initialPlace;
    if (initialPlace == null) {
      return;
    }

    _nameController.text = initialPlace.name;
    _categoryController.text = initialPlace.category;
    _addressController.text = initialPlace.address ?? '';
    _memoController.text = initialPlace.memo ?? '';
    _costController.text = initialPlace.estimatedCostWon?.toString() ?? '';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _categoryController.dispose();
    _addressController.dispose();
    _memoController.dispose();
    _costController.dispose();
    super.dispose();
  }

  void _searchPlace() {
    final query = _searchController.text.trim();
    if (query.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.strings.enterPlaceName)));
      return;
    }

    setState(() {
      _selectedCandidate = null;
      _searchFuture = _placeCandidateService.searchByKeyword(query);
    });
  }

  void _selectCandidate(PlaceCandidate candidate) {
    setState(() {
      _selectedCandidate = candidate;
      _nameController.text = candidate.displayName;
      _categoryController.text = candidate.category?.trim() ?? '';
      _addressController.text = candidate.address.trim();
    });
  }

  void _submit() {
    if (!_isEditing && _selectedCandidate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('검색 결과에서 장소를 선택해 주세요.')));
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.strings.enterPlaceName)));
      return;
    }

    final address = _addressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('주소가 확인되는 장소를 선택해 주세요.')));
      return;
    }

    final costText = _costController.text.trim().replaceAll(',', '');
    final estimatedCost = costText.isEmpty ? null : int.tryParse(costText);
    if (costText.isNotEmpty && estimatedCost == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.strings.invalidCost)));
      return;
    }

    final initialPlace = widget.initialPlace;
    Navigator.of(context).pop(
      RoutePlace(
        id:
            initialPlace?.id ??
            'custom-${DateTime.now().microsecondsSinceEpoch}',
        canonicalPlaceId: _selectedCandidate == null
            ? initialPlace?.canonicalPlaceId
            : null,
        placeProvider:
            _selectedCandidate?.source ?? initialPlace?.placeProvider,
        externalPlaceId:
            _selectedCandidate?.id ?? initialPlace?.externalPlaceId,
        name: name,
        category: _categoryController.text.trim().isEmpty
            ? '장소'
            : _categoryController.text.trim(),
        address: address,
        memo: _memoController.text.trim().isEmpty
            ? null
            : _memoController.text.trim(),
        latitude: initialPlace?.latitude ?? _selectedCandidate?.latitude,
        longitude: initialPlace?.longitude ?? _selectedCandidate?.longitude,
        estimatedCostWon: estimatedCost,
        photoUrls: initialPlace?.photoUrls ?? const [],
        photoStoragePaths: initialPlace?.photoStoragePaths ?? const [],
        purchasedItems: initialPlace?.purchasedItems ?? const [],
        orderIndex: widget.orderIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isEditing) ...[
                _LockedPlaceSummary(place: widget.initialPlace!),
                const SizedBox(height: 12),
              ] else ...[
                TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: strings.searchPlace,
                    hintText: strings.exampleCafe,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      onPressed: _searchPlace,
                      tooltip: strings.searchPlace,
                      icon: const Icon(Icons.arrow_forward),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchPlace(),
                ),
                const SizedBox(height: 10),
                _PlaceSearchResults(
                  searchFuture: _searchFuture,
                  selectedCandidate: _selectedCandidate,
                  onSelected: _selectCandidate,
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: _memoController,
                decoration: InputDecoration(
                  labelText: strings.placeDescription,
                  hintText: strings.optional,
                ),
                minLines: 1,
                maxLines: 3,
              ),
              const SizedBox(height: 10),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.actionLabel)),
      ],
    );
  }
}

class _PlaceSearchResults extends StatelessWidget {
  const _PlaceSearchResults({
    required this.searchFuture,
    required this.selectedCandidate,
    required this.onSelected,
  });

  final Future<PlaceCandidateResult>? searchFuture;
  final PlaceCandidate? selectedCandidate;
  final ValueChanged<PlaceCandidate> onSelected;

  @override
  Widget build(BuildContext context) {
    final future = searchFuture;
    if (future == null) {
      return Text(
        '장소명을 검색한 뒤 결과에서 장소를 선택하세요. 카테고리와 주소는 자동으로 입력됩니다.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Colors.black54, height: 1.4),
      );
    }

    return FutureBuilder<PlaceCandidateResult>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final result = snapshot.data;
        if (result == null || !result.isSuccess) {
          return _SearchMessage(
            icon: Icons.error_outline,
            message: result?.errorMessage ?? '장소 검색 결과를 불러오지 못했어요.',
          );
        }
        if (result.candidates.isEmpty) {
          return _SearchMessage(
            icon: Icons.location_off_outlined,
            message: context.strings.noMatchingPlaces,
          );
        }

        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: result.candidates.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final candidate = result.candidates[index];
              final selected = selectedCandidate?.id == candidate.id;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                selected: selected,
                selectedTileColor: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.45),
                leading: Icon(
                  selected ? Icons.check_circle : Icons.location_on_outlined,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.black45,
                ),
                title: Text(
                  candidate.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  candidate.displayDetail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => onSelected(candidate),
              );
            },
          ),
        );
      },
    );
  }
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.black45),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ),
        ],
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
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              address == null || address.isEmpty
                  ? place.category
                  : '${place.category} · $address',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

String _placeSubtitle(BuildContext context, RoutePlace place) {
  final parts = <String>[place.category];
  if (place.memo != null && place.memo!.isNotEmpty) {
    parts.add(place.memo!);
  }
  if (place.estimatedCostWon != null) {
    parts.add('${context.strings.estimatedCost} ₩${place.estimatedCostWon}');
  }

  return parts.join(' · ');
}
