import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/premium_ui.dart';
import '../../../models/place_candidate.dart';
import '../../route_search/domain/route_place.dart';
import '../../route_search/presentation/widgets/route_stop_edit_tile.dart';
import '../data/travel_plan_repository_provider.dart';
import '../domain/travel_plan.dart';
import 'place_search_map_screen.dart';

class PlannedRouteEditScreen extends StatefulWidget {
  const PlannedRouteEditScreen({super.key, required this.route})
    : planDayId = null,
      initialCity = null;

  const PlannedRouteEditScreen.create({
    super.key,
    required this.planDayId,
    required this.initialCity,
  }) : route = null;

  final PlannedRoute? route;
  final String? planDayId;
  final String? initialCity;

  @override
  State<PlannedRouteEditScreen> createState() => _PlannedRouteEditScreenState();
}

class _PlannedRouteEditScreenState extends State<PlannedRouteEditScreen> {
  final _repository = travelPlanRepository;
  late final TextEditingController _titleController;
  late final List<RoutePlace> _places;
  bool _saving = false;

  bool get _isCreating => widget.route == null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.route?.title ?? '');
    _places = [...?widget.route?.places];
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final place = _places.removeAt(oldIndex);
      _places.insert(newIndex, place);
    });
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty || _places.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('루트 이름과 한 곳 이상의 장소가 필요합니다.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final normalizedPlaces = [
        for (var index = 0; index < _places.length; index++)
          _places[index].copyWith(orderIndex: index),
      ];
      final saved = _isCreating
          ? await _repository.createPlannedRoute(
              planDayId: widget.planDayId!,
              title: _titleController.text.trim(),
              city: widget.initialCity?.trim().isNotEmpty == true
                  ? widget.initialCity!.trim()
                  : _places.first.address ?? '여행 지역',
              estimatedDurationMinutes: _places.length * 45,
              places: normalizedPlaces,
            )
          : await _repository.updatePlannedRoute(
              widget.route!.copyWith(
                title: _titleController.text.trim(),
                places: normalizedPlaces,
              ),
            );
      if (mounted) Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('루트를 저장하지 못했습니다: $error')));
    }
  }

  Future<void> _addPlace() async {
    final candidate = await Navigator.of(context).push<PlaceCandidate>(
      MaterialPageRoute(builder: (_) => const PlaceSearchMapScreen()),
    );
    if (candidate == null || !mounted) return;
    setState(() {
      _places.add(
        RoutePlace(
          id: 'planned-place-${DateTime.now().microsecondsSinceEpoch}',
          placeProvider: candidate.source,
          externalPlaceId: candidate.id,
          name: candidate.displayName,
          category: candidate.category?.trim().isNotEmpty == true
              ? candidate.category!.trim()
              : '장소',
          orderIndex: _places.length,
          address: candidate.address,
          latitude: candidate.latitude,
          longitude: candidate.longitude,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isCreating ? '직접 루트 만들기' : '계획 루트 수정')),
      bottomNavigationBar: AppStickyActionBar(
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? '저장 중' : '루트 저장'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: '루트 이름',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _addPlace,
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('장소 추가'),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.route?.hasSourceLog == true)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.sky,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '@${widget.route?.sourceAuthorName ?? 'LOCALOG 여행자'}의 원본 로그를 참고한 루트예요.',
                ),
              ),
            if (_places.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add_location_alt_outlined,
                          size: 48,
                          color: AppColors.primaryBlue,
                        ),
                        const SizedBox(height: 12),
                        const Text('방문할 장소를 순서대로 추가해 주세요.'),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _addPlace,
                          icon: const Icon(Icons.search),
                          label: const Text('첫 장소 검색'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  buildDefaultDragHandles: false,
                  itemCount: _places.length,
                  onReorderItem: _reorder,
                  itemBuilder: (context, index) {
                    final place = _places[index];
                    return Dismissible(
                      key: ValueKey(place.id),
                      direction: _places.length <= 1
                          ? DismissDirection.none
                          : DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.only(right: 20),
                        alignment: Alignment.centerRight,
                        color: Theme.of(context).colorScheme.error,
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                        ),
                      ),
                      onDismissed: (_) =>
                          setState(() => _places.removeAt(index)),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: RouteStopEditTile(
                          index: index,
                          title: place.name,
                          subtitle: place.address ?? place.category,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
