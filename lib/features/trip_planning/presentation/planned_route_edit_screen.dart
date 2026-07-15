import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/place_candidate.dart';
import '../../../services/place_candidate_service.dart';
import '../../route_search/domain/route_place.dart';
import '../../route_search/presentation/widgets/route_stop_edit_tile.dart';
import '../data/travel_plan_repository_provider.dart';
import '../domain/travel_plan.dart';

class PlannedRouteEditScreen extends StatefulWidget {
  const PlannedRouteEditScreen({super.key, required this.route});

  final PlannedRoute route;

  @override
  State<PlannedRouteEditScreen> createState() => _PlannedRouteEditScreenState();
}

class _PlannedRouteEditScreenState extends State<PlannedRouteEditScreen> {
  final _repository = travelPlanRepository;
  late final TextEditingController _titleController;
  late final List<RoutePlace> _places = [...widget.route.places];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.route.title);
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
      final saved = await _repository.updatePlannedRoute(
        widget.route.copyWith(
          title: _titleController.text.trim(),
          places: [
            for (var index = 0; index < _places.length; index++)
              _places[index].copyWith(orderIndex: index),
          ],
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
    final candidate = await showDialog<PlaceCandidate>(
      context: context,
      builder: (_) => const _PlannedPlaceSearchDialog(),
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
      appBar: AppBar(
        title: const Text('계획 루트 수정'),
        actions: [
          IconButton(
            tooltip: '장소 추가',
            onPressed: _saving ? null : _addPlace,
            icon: const Icon(Icons.add_location_alt_outlined),
          ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('저장'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '루트 이름',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            if (widget.route.hasSourceLog)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.sky,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '@${widget.route.sourceAuthorName ?? 'LOCALOG 여행자'}의 원본 로그를 참고한 루트예요.',
                ),
              ),
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
                    onDismissed: (_) => setState(() => _places.removeAt(index)),
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

class _PlannedPlaceSearchDialog extends StatefulWidget {
  const _PlannedPlaceSearchDialog();

  @override
  State<_PlannedPlaceSearchDialog> createState() =>
      _PlannedPlaceSearchDialogState();
}

class _PlannedPlaceSearchDialogState extends State<_PlannedPlaceSearchDialog> {
  final _controller = TextEditingController();
  final _service = const PlaceCandidateService();
  Future<PlaceCandidateResult>? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    final query = _controller.text.trim();
    if (query.length < 2) return;
    setState(() => _result = _service.searchByKeyword(query));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('장소 검색'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: '장소 이름을 입력하세요',
                suffixIcon: IconButton(
                  onPressed: _search,
                  icon: const Icon(Icons.search),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _result == null
                  ? const Center(child: Text('검색할 장소를 입력해 주세요.'))
                  : FutureBuilder<PlaceCandidateResult>(
                      future: _result,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final result = snapshot.data!;
                        if (!result.isSuccess) {
                          return Center(
                            child: Text(
                              result.errorMessage ?? '장소를 검색하지 못했습니다.',
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        if (result.candidates.isEmpty) {
                          return const Center(child: Text('검색 결과가 없습니다.'));
                        }
                        return ListView.separated(
                          itemCount: result.candidates.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final candidate = result.candidates[index];
                            return ListTile(
                              title: Text(candidate.displayName),
                              subtitle: Text(candidate.displayDetail),
                              onTap: () => Navigator.of(context).pop(candidate),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
      ],
    );
  }
}
