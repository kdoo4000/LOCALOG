import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../photo_location/photo_location_page.dart';
import '../../route_search/presentation/route_detail_screen.dart';
import '../../route_search/presentation/route_search_screen.dart';
import '../data/travel_plan_repository_provider.dart';
import '../domain/travel_plan.dart';
import 'planned_route_edit_screen.dart';

class TravelPlanDetailScreen extends StatefulWidget {
  const TravelPlanDetailScreen({super.key, required this.planId});

  final String planId;

  @override
  State<TravelPlanDetailScreen> createState() => _TravelPlanDetailScreenState();
}

class _TravelPlanDetailScreenState extends State<TravelPlanDetailScreen> {
  final _repository = travelPlanRepository;
  late Future<TravelPlan?> _planFuture;
  StreamSubscription<void>? _subscription;
  int _selectedDayIndex = 0;

  @override
  void initState() {
    super.initState();
    _planFuture = _repository.getPlanById(widget.planId);
    _subscription = _repository.plansChanged.listen((_) {
      if (mounted) _reload();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _reload() =>
      setState(() => _planFuture = _repository.getPlanById(widget.planId));

  Future<void> _deletePlan(TravelPlan plan) async {
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
    await _repository.deletePlan(plan.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _editRoute(PlannedRoute route) async {
    await Navigator.of(context).push<PlannedRoute>(
      MaterialPageRoute(builder: (_) => PlannedRouteEditScreen(route: route)),
    );
    if (mounted) _reload();
  }

  Future<void> _removeRoute(PlannedRoute route) async {
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
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TravelPlan?>(
      future: _planFuture,
      builder: (context, snapshot) {
        final plan = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(plan?.title ?? '여행 계획'),
            actions: [
              if (plan != null)
                IconButton(
                  tooltip: '계획 삭제',
                  onPressed: () => _deletePlan(plan),
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          body: !snapshot.hasData
              ? snapshot.connectionState == ConnectionState.done
                    ? const Center(child: Text('여행 계획을 찾을 수 없습니다.'))
                    : const Center(child: CircularProgressIndicator())
              : _buildPlan(context, plan!),
        );
      },
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
            '${plan.regionName} · ${plan.nightCount}박 ${plan.dayCount}일',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.gray500,
              fontWeight: FontWeight.w700,
            ),
          ),
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
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const RouteSearchScreen()),
                );
                if (mounted) _reload();
              },
            )
          else
            _PlannedRouteCard(
              day: day,
              route: day.plannedRoute!,
              onEdit: () => _editRoute(day.plannedRoute!),
              onRemove: () => _removeRoute(day.plannedRoute!),
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
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => PhotoLocationPage(
                      plannedRoute: day.plannedRoute,
                      planDay: day,
                    ),
                  ),
                );
                if (mounted) _reload();
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
  const _EmptyDay({required this.onFindLog});

  final VoidCallback onFindLog;

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
            '공개 로그에서 마음에 드는 루트를 찾아 계획에 가져오세요.',
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
            '${route.city} · ${route.places.length}곳',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.gray500),
          ),
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
          for (var index = 0; index < route.places.length; index++) ...[
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
                        route.places[index].name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (route.places[index].address != null)
                        Text(
                          route.places[index].address!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.gray500),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (index != route.places.length - 1) const SizedBox(height: 12),
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
