import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/premium_ui.dart';
import '../../../core/widgets/region_chip_wrap.dart';
import '../data/travel_plan_repository_provider.dart';
import '../domain/travel_plan.dart';
import 'travel_plan_create_screen.dart';
import 'travel_plan_detail_screen.dart';

class TravelPlanScreen extends StatefulWidget {
  const TravelPlanScreen({super.key});

  @override
  State<TravelPlanScreen> createState() => _TravelPlanScreenState();
}

class _TravelPlanScreenState extends State<TravelPlanScreen> {
  final _repository = travelPlanRepository;
  StreamSubscription<void>? _subscription;
  List<TravelPlan> _plans = const [];
  Object? _loadError;
  bool _loading = true;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshPlans());
    _subscription = _repository.plansChanged.listen((_) {
      unawaited(_refreshPlans());
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
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
    if (plan == null || !mounted) return;
    _showPlanImmediately(plan);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            TravelPlanDetailScreen(planId: plan.id, initialPlan: plan),
      ),
    );
    if (mounted) await _refreshPlans();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final ongoing = _plans
        .where((plan) => _tripStatus(plan, today) == _TripStatus.ongoing)
        .toList();
    final upcoming = _plans
        .where((plan) => _tripStatus(plan, today) == _TripStatus.upcoming)
        .toList();
    final completed =
        _plans
            .where((plan) => _tripStatus(plan, today) == _TripStatus.completed)
            .toList()
          ..sort((a, b) => b.endDate.compareTo(a.endDate));
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.readingWidth),
            child: RefreshIndicator(
              onRefresh: () async {
                await _refreshPlans();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '내 여행',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '계획부터 정산, 여행 로그까지 한곳에서 관리해요.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.gray500),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filled(
                        tooltip: '새 여행',
                        onPressed: _createPlan,
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_plans.isNotEmpty) ...[
                    AppMetricStrip(
                      items: [
                        (label: '여행 중', value: '${ongoing.length}'),
                        (label: '예정', value: '${upcoming.length}'),
                        (label: '완료', value: '${completed.length}'),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (_loading && _plans.isEmpty)
                    const _PlanSkeleton()
                  else if (_loadError != null && _plans.isEmpty)
                    _PlanMessage(
                      message: '내 여행을 불러오지 못했습니다.',
                      actionLabel: '다시 시도',
                      onAction: () => unawaited(_refreshPlans()),
                    )
                  else if (_plans.isEmpty)
                    _PlanMessage(
                      message: '아직 등록된 여행이 없어요.\n지역과 날짜부터 정해볼까요?',
                      actionLabel: '첫 여행 만들기',
                      onAction: _createPlan,
                    )
                  else
                    _TripSections(
                      ongoing: ongoing,
                      upcoming: upcoming,
                      completed: completed,
                      onOpen: (plan) async {
                        await Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => TravelPlanDetailScreen(
                              planId: plan.id,
                              initialPlan: plan,
                            ),
                          ),
                        );
                        if (mounted) await _refreshPlans();
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _TripStatus { ongoing, upcoming, completed }

_TripStatus _tripStatus(TravelPlan plan, DateTime today) {
  final start = DateUtils.dateOnly(plan.startDate);
  final end = DateUtils.dateOnly(plan.endDate);
  if (today.isBefore(start)) return _TripStatus.upcoming;
  if (today.isAfter(end)) return _TripStatus.completed;
  return _TripStatus.ongoing;
}

class _TripSections extends StatelessWidget {
  const _TripSections({
    required this.ongoing,
    required this.upcoming,
    required this.completed,
    required this.onOpen,
  });

  final List<TravelPlan> ongoing;
  final List<TravelPlan> upcoming;
  final List<TravelPlan> completed;
  final ValueChanged<TravelPlan> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ongoing.isNotEmpty)
          _TripGroup(title: '진행 중인 여행', plans: ongoing, onOpen: onOpen),
        if (upcoming.isNotEmpty) ...[
          if (ongoing.isNotEmpty) const SizedBox(height: 28),
          _TripGroup(title: '예정된 여행', plans: upcoming, onOpen: onOpen),
        ],
        if (completed.isNotEmpty) ...[
          if (ongoing.isNotEmpty || upcoming.isNotEmpty)
            const SizedBox(height: 28),
          _TripGroup(title: '지난 여행', plans: completed, onOpen: onOpen),
        ],
      ],
    );
  }
}

class _TripGroup extends StatelessWidget {
  const _TripGroup({
    required this.title,
    required this.plans,
    required this.onOpen,
  });

  final String title;
  final List<TravelPlan> plans;
  final ValueChanged<TravelPlan> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        for (final plan in plans) ...[
          _TravelPlanCard(plan: plan, onTap: () => onOpen(plan)),
          if (plan != plans.last) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _TravelPlanCard extends StatelessWidget {
  const _TravelPlanCard({required this.plan, required this.onTap});

  final TravelPlan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _tripStatus(plan, DateUtils.dateOnly(DateTime.now()));
    final routedDays = plan.days
        .where((day) => day.plannedRoute != null)
        .length;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusLabel(status: status),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  plan.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${_dateLabel(plan.startDate)} ~ ${_dateLabel(plan.endDate)} · '
            '${plan.nightCount}박 ${plan.dayCount}일',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Text(
            switch (status) {
              _TripStatus.ongoing => '지금, 여행의 한가운데를 지나고 있어요.',
              _TripStatus.upcoming => '함께 떠날 날을 천천히 그려가는 중이에요.',
              _TripStatus.completed => '지나온 순간을 하나의 이야기로 남겨보세요.',
            },
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.gray500),
          ),
          const SizedBox(height: 9),
          RegionChipWrap(regions: plan.effectiveRegions, compact: true),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: plan.days.isEmpty ? 0 : routedDays / plan.days.length,
              minHeight: 7,
              backgroundColor: AppColors.gray200,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '$routedDays/${plan.days.length}일의 루트 준비 완료',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.gray500,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});

  final _TripStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = switch (status) {
      _TripStatus.ongoing => ('여행 중', AppColors.mint, AppColors.success),
      _TripStatus.upcoming => ('예정', AppColors.sky, AppColors.primaryBlue),
      _TripStatus.completed => ('완료', AppColors.gray100, AppColors.gray500),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PlanSkeleton extends StatelessWidget {
  const _PlanSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '여행 계획을 불러오는 중',
      child: ExcludeSemantics(
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
        ),
      ),
    );
  }
}

class _PlanMessage extends StatelessWidget {
  const _PlanMessage({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const Icon(
            Icons.map_outlined,
            size: 42,
            color: AppColors.primaryBlue,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

String _dateLabel(DateTime value) => '${value.month}.${value.day}';
