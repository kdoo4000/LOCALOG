import 'package:flutter/material.dart';

import '../../../core/l10n/app_language.dart';
import '../data/mock_route_repository.dart';
import '../domain/route_place.dart';
import '../domain/travel_route.dart';
import 'widgets/route_stop_edit_tile.dart';

class RouteDownloadEditScreen extends StatefulWidget {
  const RouteDownloadEditScreen({super.key, required this.routeId});

  final String routeId;

  @override
  State<RouteDownloadEditScreen> createState() =>
      _RouteDownloadEditScreenState();
}

class _RouteDownloadEditScreenState extends State<RouteDownloadEditScreen> {
  final _repository = const MockRouteRepository();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  TravelRoute? _route;
  List<RoutePlace> _places = [];
  RouteVisibility _visibility = RouteVisibility.public;
  bool _isSaving = false;

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
    final route = await _repository.getRouteById(widget.routeId);
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

    setState(() {
      _route = route;
      _titleController.text = route.title;
      _descriptionController.text = route.description;
      _visibility = route.visibility;
      _places = [...route.places]
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
      description: _descriptionController.text.trim().isEmpty
          ? route.description
          : _descriptionController.text.trim(),
      places: orderedPlaces,
      visibility: _visibility,
      isDownloaded: true,
    );
    await _repository.updateDownloadedRoute(updated);

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });
    Navigator.of(context).pop(true);
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
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }

      final item = _places.removeAt(oldIndex);
      _places.insert(newIndex, item);
    });
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
      body: route == null
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
                        if (route.isCreatedByCurrentUser) ...[
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
                        const SizedBox(height: 10),
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          primary: false,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          itemCount: _places.length,
                          onReorder: _reorderPlaces,
                          itemBuilder: (context, index) {
                            final place = _places[index];

                            return Padding(
                              key: ValueKey('download-place-${place.id}'),
                              padding: const EdgeInsets.only(bottom: 10),
                              child: RouteStopEditTile(
                                index: index,
                                title: place.name,
                                subtitle: _placeSubtitle(context, place),
                                onEdit: () => _showEditPlaceDialog(place),
                                onRemove: () => _removePlace(place),
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
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _addressController = TextEditingController();
  final _memoController = TextEditingController();
  final _costController = TextEditingController();

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
    _nameController.dispose();
    _categoryController.dispose();
    _addressController.dispose();
    _memoController.dispose();
    _costController.dispose();
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
        name: name,
        category: _categoryController.text.trim().isEmpty
            ? 'Custom'
            : _categoryController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        memo: _memoController.text.trim().isEmpty
            ? null
            : _memoController.text.trim(),
        latitude: initialPlace?.latitude,
        longitude: initialPlace?.longitude,
        estimatedCostWon: estimatedCost,
        photoUrls: initialPlace?.photoUrls ?? const [],
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isEditing) ...[
              _LockedPlaceSummary(place: widget.initialPlace!),
              const SizedBox(height: 12),
            ] else ...[
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
                textInputAction: TextInputAction.next,
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
