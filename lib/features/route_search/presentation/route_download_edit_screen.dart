import 'package:flutter/material.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../data/mock_route_repository.dart';
import '../domain/route_place.dart';
import '../domain/travel_route.dart';

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
  TravelRoute? _route;
  List<RoutePlace> _places = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadRouteCopy();
  }

  @override
  void dispose() {
    _titleController.dispose();
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
      places: orderedPlaces,
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

  void _movePlace(int index, int offset) {
    final nextIndex = index + offset;
    if (nextIndex < 0 || nextIndex >= _places.length) {
      return;
    }

    setState(() {
      final item = _places.removeAt(index);
      _places.insert(nextIndex, item);
    });
  }

  Future<void> _showAddPlaceDialog() async {
    final place = await showDialog<RoutePlace>(
      context: context,
      builder: (context) => _AddPlaceDialog(orderIndex: _places.length),
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
                        const SizedBox(height: 18),
                        OutlinedButton.icon(
                          onPressed: _showAddPlaceDialog,
                          icon: const Icon(Icons.add_location_alt_outlined),
                          label: Text(strings.addPlace),
                        ),
                        const SizedBox(height: 14),
                        for (var index = 0; index < _places.length; index += 1)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _EditablePlaceTile(
                              index: index,
                              place: _places[index],
                              canMoveUp: index > 0,
                              canMoveDown: index < _places.length - 1,
                              onMoveUp: () => _movePlace(index, -1),
                              onMoveDown: () => _movePlace(index, 1),
                              onRemove: () => _removePlace(_places[index]),
                            ),
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
                      label: Text(_isSaving ? strings.saving : strings.saveRoute),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _AddPlaceDialog extends StatefulWidget {
  const _AddPlaceDialog({required this.orderIndex});

  final int orderIndex;

  @override
  State<_AddPlaceDialog> createState() => _AddPlaceDialogState();
}

class _AddPlaceDialogState extends State<_AddPlaceDialog> {
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _addressController = TextEditingController();
  final _memoController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _addressController.dispose();
    _memoController.dispose();
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
      RoutePlace(
        id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
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
        orderIndex: widget.orderIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return AlertDialog(
      title: Text(strings.addPlace),
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
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _memoController,
              decoration: InputDecoration(
                labelText: strings.memo,
                hintText: strings.optional,
              ),
              minLines: 1,
              maxLines: 3,
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

class _EditablePlaceTile extends StatelessWidget {
  const _EditablePlaceTile({
    required this.index,
    required this.place,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final int index;
  final RoutePlace place;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.accentYellow,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  place.category,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: strings.moveUp,
            onPressed: canMoveUp ? onMoveUp : null,
            icon: const Icon(Icons.keyboard_arrow_up),
          ),
          IconButton(
            tooltip: strings.moveDown,
            onPressed: canMoveDown ? onMoveDown : null,
            icon: const Icon(Icons.keyboard_arrow_down),
          ),
          IconButton(
            tooltip: strings.delete,
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}
