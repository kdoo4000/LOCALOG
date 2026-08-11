import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/region_chip_wrap.dart';
import '../../../services/naver_static_map_service.dart';
import '../../photo_location/naver_dynamic_map.dart';
import '../../route_search/presentation/route_detail_screen.dart';
import '../../route_search/presentation/route_search_screen.dart';
import '../data/travel_plan_repository_provider.dart';
import '../domain/travel_plan.dart';
import 'planned_route_edit_screen.dart';
import 'planned_route_log_create_screen.dart';
import 'travel_plan_create_screen.dart';

class TravelPlanDetailScreen extends StatefulWidget {
  const TravelPlanDetailScreen({
    super.key,
    required this.planId,
    this.initialPlan,
    this.initialDayIndex = 0,
  });

  final String planId;
  final TravelPlan? initialPlan;
  final int initialDayIndex;

  @override
  State<TravelPlanDetailScreen> createState() => _TravelPlanDetailScreenState();
}

class _TravelPlanDetailScreenState extends State<TravelPlanDetailScreen> {
  final _repository = travelPlanRepository;
  StreamSubscription<void>? _subscription;
  TravelPlan? _plan;
  Object? _loadError;
  bool _loading = false;
  bool _deletingPlan = false;
  int _loadGeneration = 0;
  late int _selectedDayIndex;

  @override
  void initState() {
    super.initState();
    _selectedDayIndex = widget.initialDayIndex;
    _plan = widget.initialPlan;
    _loading = _plan == null;
    if (_plan == null) {
      unawaited(_refreshPlan());
    }
    _listenForPlanChanges();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshPlan() async {
    final generation = ++_loadGeneration;
    try {
      final plan = await _repository.getPlanById(widget.planId);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _plan = plan;
        _loadError = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  void _showPlan(TravelPlan plan) {
    if (!mounted) return;
    _loadGeneration += 1;
    setState(() {
      _plan = plan;
      _loadError = null;
      _loading = false;
    });
  }

  void _listenForPlanChanges() {
    _subscription ??= _repository.plansChanged.listen((_) {
      if (!_deletingPlan) unawaited(_refreshPlan());
    });
  }

  TravelPlan _replaceDayRoute(
    TravelPlan plan,
    String dayId,
    PlannedRoute? route,
  ) {
    return plan.copyWith(
      days: [
        for (final day in plan.days)
          if (day.id == dayId) day.copyWith(plannedRoute: route) else day,
      ],
    );
  }

  Future<void> _deletePlan(TravelPlan plan) async {
    if (_deletingPlan) return;
    final detailRoute = ModalRoute.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('여행 계획 삭제'),
        content: Text('“${plan.title}” 계획을 삭제할까요? 만들어진 로그는 삭제되지 않습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deletingPlan = true);
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    try {
      await _repository.deletePlan(plan.id);
      if (!mounted) return;
      final navigator = Navigator.of(context);
      if (detailRoute != null && !detailRoute.isFirst) {
        navigator.removeRoute(detailRoute, true);
      } else {
        setState(() {
          _plan = null;
          _loading = false;
          _loadError = null;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _deletingPlan = false);
      _listenForPlanChanges();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('여행 계획을 삭제하지 못했습니다: $error')));
    }
  }

  Future<void> _editPlan(TravelPlan plan) async {
    final updated = await Navigator.of(context).push<TravelPlan>(
      MaterialPageRoute(builder: (_) => TravelPlanCreateScreen(plan: plan)),
    );
    if (updated != null) _showPlan(updated);
  }

  Future<void> _editRoute(
    TravelPlan plan,
    TravelPlanDay day,
    PlannedRoute route,
  ) async {
    final updated = await Navigator.of(context).push<PlannedRoute>(
      MaterialPageRoute(builder: (_) => PlannedRouteEditScreen(route: route)),
    );
    if (updated != null) {
      _showPlan(_replaceDayRoute(plan, day.id, updated));
    }
  }

  Future<void> _removeRoute(
    TravelPlan plan,
    TravelPlanDay day,
    PlannedRoute route,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('계획에서 루트 제거'),
        content: const Text('복사한 루트만 제거되며 원본 로그에는 영향을 주지 않습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('제거'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.removePlannedRoute(route.id);
    _showPlan(_replaceDayRoute(plan, day.id, null));
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return Scaffold(
      appBar: AppBar(
        title: Text(plan?.title ?? '여행 계획'),
        actions: [
          if (plan != null)
            IconButton(
              tooltip: '계획 수정',
              onPressed: _deletingPlan ? null : () => _editPlan(plan),
              icon: const Icon(Icons.edit_outlined),
            ),
          if (plan != null)
            IconButton(
              tooltip: '계획 삭제',
              onPressed: _deletingPlan ? null : () => _deletePlan(plan),
              icon: _deletingPlan
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: plan != null
          ? _buildPlan(context, plan)
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: OutlinedButton(
                onPressed: () {
                  setState(() => _loading = true);
                  unawaited(_refreshPlan());
                },
                child: const Text('여행 계획 다시 불러오기'),
              ),
            )
          : const Center(child: Text('여행 계획을 찾을 수 없습니다.')),
    );
  }

  Widget _buildPlan(BuildContext context, TravelPlan plan) {
    if (_selectedDayIndex >= plan.days.length) _selectedDayIndex = 0;
    final day = plan.days[_selectedDayIndex];
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            '${plan.nightCount}박 ${plan.dayCount}일',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.gray500,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          RegionChipWrap(regions: plan.effectiveRegions),
          const SizedBox(height: 18),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: plan.days.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = plan.days[index];
                return ChoiceChip(
                  selected: index == _selectedDayIndex,
                  label: Text(
                    'DAY ${index + 1} · ${item.date.month}/${item.date.day}',
                  ),
                  onSelected: (_) => setState(() => _selectedDayIndex = index),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'DAY ${day.dayIndex + 1} · ${day.date.month}월 ${day.date.day}일',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          if (day.plannedRoute == null)
            _EmptyDay(
              onFindLog: () async {
                final updatedPlan = await Navigator.of(context)
                    .push<TravelPlan>(
                      MaterialPageRoute(
                        builder: (_) =>
                            RouteSearchScreen(
                              targetPlanDayId: day.id,
                              initialKeyword: plan.effectiveRegions.first,
                            ),
                      ),
                    );
                if (updatedPlan != null) _showPlan(updatedPlan);
              },
              onCreateRoute: () async {
                final created = await Navigator.of(context).push<PlannedRoute>(
                  MaterialPageRoute(
                    builder: (_) => PlannedRouteEditScreen.create(
                      planDayId: day.id,
                      initialCity: plan.effectiveRegions.first,
                    ),
                  ),
                );
                if (created != null) {
                  _showPlan(_replaceDayRoute(plan, day.id, created));
                }
              },
            )
          else
            _PlannedRouteCard(
              day: day,
              route: day.plannedRoute!,
              onEdit: () => _editRoute(plan, day, day.plannedRoute!),
              onRemove: () => _removeRoute(plan, day, day.plannedRoute!),
              onOpenSource: day.plannedRoute!.sourceLogId == null
                  ? null
                  : () => Navigator.of(context).pushNamed(
                      RouteNames.routeDetail,
                      arguments: RouteDetailArguments(
                        routeId: day.plannedRoute!.sourceLogId!,
                        showSourceRoute: true,
                      ),
                    ),
              onCreateLog: () async {
                final updatedPlan = await Navigator.of(context)
                    .push<TravelPlan>(
                      MaterialPageRoute(
                        builder: (_) => PlannedRouteLogCreateScreen(
                          route: day.plannedRoute!,
                          day: day,
                          regions: plan.effectiveRegions,
                        ),
                      ),
                    );
                if (updatedPlan != null) _showPlan(updatedPlan);
              },
              onOpenCompletedLog: day.completedLogId == null
                  ? null
                  : () => Navigator.of(context).pushNamed(
                      RouteNames.routeDetail,
                      arguments: day.completedLogId,
                    ),
            ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.onFindLog, required this.onCreateRoute});

  final VoidCallback onFindLog;
  final VoidCallback onCreateRoute;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const Icon(
            Icons.route_outlined,
            size: 44,
            color: AppColors.primaryBlue,
          ),
          const SizedBox(height: 12),
          const Text('아직 이 날의 루트가 없어요.'),
          const SizedBox(height: 6),
          Text(
            '다른 로그의 루트를 참고하거나 방문할 장소를 직접 구성할 수 있어요.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.gray500),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onFindLog,
            icon: const Icon(Icons.search),
            label: const Text('로그에서 루트 찾기'),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCreateRoute,
              icon: const Icon(Icons.edit_road_outlined),
              label: const Text('직접 루트 만들기'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlannedRouteCard extends StatelessWidget {
  const _PlannedRouteCard({
    required this.day,
    required this.route,
    required this.onEdit,
    required this.onRemove,
    required this.onCreateLog,
    this.onOpenSource,
    this.onOpenCompletedLog,
  });

  final TravelPlanDay day;
  final PlannedRoute route;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback onCreateLog;
  final VoidCallback? onOpenSource;
  final VoidCallback? onOpenCompletedLog;

  @override
  Widget build(BuildContext context) {
    final sortedPlaces = [...route.places]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final mapPoints = [
      for (final place in sortedPlaces)
        if (place.latitude != null && place.longitude != null)
          MapPoint(latitude: place.latitude!, longitude: place.longitude!),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  route.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                tooltip: '루트 수정',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: '계획에서 제거',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          Text(
            '${compactRegionLabel(route.city)} · ${sortedPlaces.length}곳',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.gray500),
          ),
          if (mapPoints.isNotEmpty) ...[
            const SizedBox(height: 18),
            NaverDynamicMap(points: mapPoints, height: 260),
          ],
          if (route.sourceAuthorName != null) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: onOpenSource,
              child: Row(
                children: [
                  const Icon(
                    Icons.link,
                    size: 18,
                    color: AppColors.primaryBlue,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '@${route.sourceAuthorName}의 원본 로그를 참고했어요',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (onOpenSource != null) const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          for (var index = 0; index < sortedPlaces.length; index++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: AppColors.sky,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: AppColors.primaryBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sortedPlaces[index].name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (sortedPlaces[index].address != null)
                        Text(
                          sortedPlaces[index].address!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.gray500),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (index != sortedPlaces.length - 1) const SizedBox(height: 12),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: onOpenCompletedLog == null
                ? FilledButton.icon(
                    onPressed: onCreateLog,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text('사진을 추가해 로그 만들기'),
                  )
                : FilledButton.icon(
                    onPressed: onOpenCompletedLog,
                    icon: const Icon(Icons.auto_stories_outlined),
                    label: const Text('완성된 로그 보기'),
                  ),
          ),
        ],
      ),
    );
  }
}
