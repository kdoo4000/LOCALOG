import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../data/travel_plan_repository_provider.dart';
import '../domain/travel_plan.dart';
import 'travel_plan_create_screen.dart';

class PlanRouteImportScreen extends StatefulWidget {
  const PlanRouteImportScreen({super.key, required this.logId});

  final String logId;

  @override
  State<PlanRouteImportScreen> createState() => _PlanRouteImportScreenState();
}

class _PlanRouteImportScreenState extends State<PlanRouteImportScreen> {
  final _repository = travelPlanRepository;
  List<TravelPlan> _plans = const [];
  Object? _loadError;
  bool _loading = true;
  int _loadGeneration = 0;
  String? _savingDayId;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshPlans());
  }

  Future<void> _refreshPlans() async {
    final generation = ++_loadGeneration;
    try {
      final plans = await _repository.getPlans();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _plans = plans;
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

  void _showPlanImmediately(TravelPlan plan) {
    _loadGeneration += 1;
    final plans = [
      plan,
      for (final existing in _plans)
        if (existing.id != plan.id) existing,
    ]..sort((a, b) => a.startDate.compareTo(b.startDate));
    setState(() {
      _plans = plans;
      _loadError = null;
      _loading = false;
    });
  }

  Future<void> _createPlan() async {
    final plan = await Navigator.of(context).push<TravelPlan>(
      MaterialPageRoute(builder: (_) => const TravelPlanCreateScreen()),
    );
    if (plan != null && mounted) _showPlanImmediately(plan);
  }

  Future<void> _selectDay(TravelPlanDay day) async {
    if (day.plannedRoute != null) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('루트 교체'),
          content: const Text('이 날짜에 이미 루트가 있습니다. 새 루트로 교체할까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('교체'),
            ),
          ],
        ),
      );
      if (replace != true) return;
    }
    setState(() => _savingDayId = day.id);
    try {
      final updatedPlan = await _repository.copyLogRouteToDay(
        logId: widget.logId,
        planDayId: day.id,
      );
      if (mounted) Navigator.of(context).pop(updatedPlan);
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingDayId = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('루트를 계획에 가져오지 못했습니다: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('루트를 여행 계획에 추가')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.readingWidth),
            child: _loading && _plans.isEmpty
            ? const _ImportSkeleton()
            : _loadError != null && _plans.isEmpty
            ? Center(
                child: OutlinedButton(
                  onPressed: () => unawaited(_refreshPlans()),
                  child: const Text('여행 계획 다시 불러오기'),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    '적용할 날짜를 선택하세요',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '사진과 개인 기록은 복사하지 않고 하루치 루트만 가져옵니다.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_plans.isEmpty)
                    FilledButton.icon(
                      onPressed: _createPlan,
                      icon: const Icon(Icons.add),
                      label: const Text('먼저 여행 계획 만들기'),
                    )
                  else ...[
                    for (final plan in _plans) ...[
                      Text(
                        plan.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      for (final day in plan.days)
                        Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text('${day.dayIndex + 1}'),
                            ),
                            title: Text(
                              'DAY ${day.dayIndex + 1} · '
                              '${day.date.month}월 ${day.date.day}일',
                            ),
                            subtitle: Text(
                              day.plannedRoute?.title ?? '아직 루트가 없습니다.',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: _savingDayId == day.id
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    day.plannedRoute == null
                                        ? Icons.add_circle_outline
                                        : Icons.swap_horiz,
                                  ),
                            onTap: _savingDayId == null
                                ? () => _selectDay(day)
                                : null,
                          ),
                        ),
                      const SizedBox(height: 18),
                    ],
                    OutlinedButton.icon(
                      onPressed: _createPlan,
                      icon: const Icon(Icons.add),
                      label: const Text('새 여행 계획 만들기'),
                    ),
                  ],
                ],
              ),
          ),
        ),
      ),
    );
  }
}

class _ImportSkeleton extends StatelessWidget {
  const _ImportSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '여행 계획을 불러오는 중',
      child: ExcludeSemantics(
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: 3,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (_, index) => Container(
            height: index == 0 ? 68 : 84,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
          ),
        ),
      ),
    );
  }
}
