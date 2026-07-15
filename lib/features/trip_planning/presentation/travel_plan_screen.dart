import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
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
  late Future<List<TravelPlan>> _plansFuture;
  StreamSubscription<void>? _subscription;

  @override
  void initState() {
    super.initState();
    _plansFuture = _repository.getPlans();
    _subscription = _repository.plansChanged.listen((_) {
      if (mounted) _reload();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _reload() => setState(() => _plansFuture = _repository.getPlans());

  Future<void> _createPlan() async {
    final plan = await Navigator.of(context).push<TravelPlan>(
      MaterialPageRoute(builder: (_) => const TravelPlanCreateScreen()),
    );
    if (plan == null || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TravelPlanDetailScreen(planId: plan.id),
      ),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _plansFuture;
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
                          '여행 계획',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '날짜마다 하루치 루트를 준비해 보세요.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.gray500),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    tooltip: '새 여행 계획',
                    onPressed: _createPlan,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FutureBuilder<List<TravelPlan>>(
                future: _plansFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _PlanMessage(
                      message: '여행 계획을 불러오지 못했습니다.',
                      actionLabel: '다시 시도',
                      onAction: _reload,
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(36),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final plans = snapshot.data!;
                  if (plans.isEmpty) {
                    return _PlanMessage(
                      message: '아직 여행 계획이 없어요.\n지역과 날짜부터 정해볼까요?',
                      actionLabel: '첫 여행 계획 만들기',
                      onAction: _createPlan,
                    );
                  }
                  return Column(
                    children: [
                      for (final plan in plans) ...[
                        _TravelPlanCard(
                          plan: plan,
                          onTap: () async {
                            await Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) =>
                                    TravelPlanDetailScreen(planId: plan.id),
                              ),
                            );
                            if (mounted) _reload();
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TravelPlanCard extends StatelessWidget {
  const _TravelPlanCard({required this.plan, required this.onTap});

  final TravelPlan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
              Expanded(
                child: Text(
                  plan.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
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
          const SizedBox(height: 5),
          Text(
            plan.regionName,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.gray500),
          ),
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
