import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/premium_ui.dart';
import '../../../core/widgets/region_chip_wrap.dart';
import '../../route_search/data/route_repository_provider.dart';
import '../../route_search/domain/travel_route.dart';
import '../../route_search/presentation/route_detail_screen.dart';
import '../../route_search/presentation/widgets/route_card.dart';
import '../../receipt_settlement/presentation/receipt_settlement_screen.dart';
import '../../trip_planning/data/travel_plan_repository_provider.dart';
import '../../trip_planning/domain/travel_plan.dart';
import '../../trip_planning/presentation/travel_plan_create_screen.dart';
import '../../trip_planning/presentation/travel_plan_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.isGuest = false,
    this.user,
    this.onProfileTap,
    this.onLoginTap,
    this.onSearchTap,
    this.onUploadTap,
  });

  final bool isGuest;
  final HomeUserSummary? user;
  final VoidCallback? onProfileTap;
  final VoidCallback? onLoginTap;
  final ValueChanged<String?>? onSearchTap;
  final VoidCallback? onUploadTap;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repository = routeRepository;
  final _planRepository = travelPlanRepository;
  late Future<List<TravelRoute>> _routesFuture;
  StreamSubscription<void>? _routesSubscription;
  StreamSubscription<void>? _plansSubscription;
  TravelPlan? _nextPlan;
  bool _loadingPlan = true;
  int _planLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _routesFuture = _repository.getRecommendedRoutes();
    _routesSubscription = _repository.routesChanged.listen((_) {
      if (mounted) _reloadRoutes();
    });
    unawaited(_reloadNextPlan());
    _plansSubscription = _planRepository.plansChanged.listen((_) {
      unawaited(_reloadNextPlan());
    });
  }

  @override
  void dispose() {
    _routesSubscription?.cancel();
    _plansSubscription?.cancel();
    super.dispose();
  }

  void _reloadRoutes() {
    setState(() => _routesFuture = _repository.getRecommendedRoutes());
  }

  void _openRoute(TravelRoute route) {
    Navigator.of(context).pushNamed(
      RouteNames.routeDetail,
      arguments: RouteDetailArguments(routeId: route.id, showSourceRoute: true),
    );
  }

  Future<void> _reloadNextPlan() async {
    final generation = ++_planLoadGeneration;
    try {
      final plans = await _planRepository.getPlans();
      if (!mounted || generation != _planLoadGeneration) return;
      final nextPlan = featuredTravelPlan(plans, DateTime.now());
      setState(() {
        _nextPlan = nextPlan;
        _loadingPlan = false;
      });
    } catch (_) {
      if (!mounted || generation != _planLoadGeneration) return;
      setState(() {
        _nextPlan = null;
        _loadingPlan = false;
      });
    }
  }

  Future<void> _openNextPlan() async {
    final plan = _nextPlan;
    if (plan == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TravelPlanDetailScreen(
          planId: plan.id,
          initialPlan: plan,
          initialDayIndex: currentTravelPlanDayIndex(plan, DateTime.now()),
        ),
      ),
    );
    if (mounted) await _reloadNextPlan();
  }

  Future<void> _openSettlement() async {
    final plan = _nextPlan;
    if (plan == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ReceiptSettlementScreen(travelTitle: plan.title),
      ),
    );
  }

  Future<void> _createPlan() async {
    if (widget.isGuest) {
      widget.onLoginTap?.call();
      return;
    }
    final plan = await Navigator.of(context).push<TravelPlan>(
      MaterialPageRoute(builder: (_) => const TravelPlanCreateScreen()),
    );
    if (plan == null || !mounted) return;
    _planLoadGeneration += 1;
    setState(() {
      _nextPlan = featuredTravelPlan([plan, ?_nextPlan], DateTime.now());
      _loadingPlan = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.contentWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
              children: [
                _HomeHeader(
                  isGuest: widget.isGuest,
                  user: widget.user,
                  nextPlan: _nextPlan,
                  loadingPlan: _loadingPlan,
                  onOpenPlan: _openNextPlan,
                  onSettlement: _openSettlement,
                  onCreatePlan: _createPlan,
                  onProfileTap: widget.onProfileTap,
                  onLoginTap: widget.onLoginTap,
                ),
                const SizedBox(height: 20),
                _ShortcutGrid(
                  onRouteSearchTap: () => widget.onSearchTap?.call(null),
                  onUploadTap: widget.onUploadTap,
                ),
                const SizedBox(height: 28),
                Text(
                  strings.monthlyRecommend,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<TravelRoute>>(
                  future: _routesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _LoadError(onRetry: _reloadRoutes);
                    }
                    if (!snapshot.hasData) {
                      return const _RouteCardSkeleton();
                    }

                    final routes = snapshot.data!;
                    if (routes.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.sky,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text('아직 공개된 로그가 없습니다.'),
                      );
                    }
                    final featured = routes.first;
                    return RouteCard(
                      route: featured,
                      onTap: () => _openRoute(featured),
                    );
                  },
                ),
                const SizedBox(height: 28),
                _PopularPlacesPanel(
                  onPlaceTap: (place) => widget.onSearchTap?.call(place),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('추천 로그를 불러오지 못했습니다.'),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.isGuest,
    required this.user,
    required this.onProfileTap,
    required this.onLoginTap,
    required this.nextPlan,
    required this.loadingPlan,
    required this.onOpenPlan,
    required this.onSettlement,
    required this.onCreatePlan,
  });

  final bool isGuest;
  final HomeUserSummary? user;
  final VoidCallback? onProfileTap;
  final VoidCallback? onLoginTap;
  final TravelPlan? nextPlan;
  final bool loadingPlan;
  final VoidCallback onOpenPlan;
  final VoidCallback onSettlement;
  final VoidCallback onCreatePlan;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'LOCALOG',
              style: TextStyle(
                color: AppColors.primaryBlue,
                fontFamily: 'Pretendard',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            if (isGuest)
              OutlinedButton(
                key: const ValueKey('home-login-button'),
                onPressed: onLoginTap,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  foregroundColor: AppColors.primaryBlue,
                  side: const BorderSide(color: AppColors.primaryBlue),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                child: const Text(
                  '로그인',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              )
            else
              Semantics(
                button: true,
                label: '프로필 열기',
                child: InkWell(
                  key: const ValueKey('home-profile-button'),
                  customBorder: const CircleBorder(),
                  onTap: onProfileTap,
                  child: CircleAvatar(
                    key: const ValueKey('home-profile-avatar'),
                    radius: 21,
                    backgroundColor: AppColors.sky,
                    foregroundImage: user?.avatarUrl == null
                        ? null
                        : NetworkImage(user!.avatarUrl!),
                    onForegroundImageError: user?.avatarUrl == null
                        ? null
                        : (_, _) {},
                    child: Text(
                      user?.initial ?? 'L',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppHeroCard(
          child: _NextTravelContent(
            plan: nextPlan,
            loading: loadingPlan,
            onOpenPlan: onOpenPlan,
            onSettlement: onSettlement,
            onCreatePlan: onCreatePlan,
          ),
        ),
      ],
    );
  }
}

class _NextTravelContent extends StatelessWidget {
  const _NextTravelContent({
    required this.plan,
    required this.loading,
    required this.onOpenPlan,
    required this.onSettlement,
    required this.onCreatePlan,
  });

  final TravelPlan? plan;
  final bool loading;
  final VoidCallback onOpenPlan;
  final VoidCallback onSettlement;
  final VoidCallback onCreatePlan;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 150,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.accentLime),
        ),
      );
    }

    final plan = this.plan;
    if (plan == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TravelBadge(label: 'NEXT JOURNEY'),
          const SizedBox(height: 16),
          Text(
            '여행을 떠나볼까요?',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '날짜와 지역을 정하고 하루치 루트를 계획해 보세요.',
            style: TextStyle(color: AppColors.white, height: 1.4),
          ),
          const SizedBox(height: 20),
          _HeroActionButton(
            key: const ValueKey('home-create-plan-button'),
            label: '새 여행 계획 만들기',
            icon: Icons.add_rounded,
            onPressed: onCreatePlan,
          ),
        ],
      );
    }

    final status = travelPlanHomeStatus(plan, DateTime.now());
    final showSettlement = status != TravelPlanHomeStatus.upcoming;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TravelBadge(label: travelPlanDdayLabel(plan, DateTime.now())),
        const SizedBox(height: 16),
        Text(
          plan.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w700,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_compactDate(plan.startDate)} ~ ${_compactDate(plan.endDate)}',
          style: const TextStyle(color: AppColors.white, height: 1.4),
        ),
        const SizedBox(height: 10),
        RegionChipWrap(
          regions: plan.effectiveRegions,
          foregroundColor: AppColors.white,
          backgroundColor: AppColors.white.withValues(alpha: 0.14),
          borderColor: AppColors.white.withValues(alpha: 0.3),
          compact: true,
        ),
        const SizedBox(height: 20),
        if (showSettlement)
          Row(
            children: [
              Expanded(
                child: _HeroActionButton(
                  key: const ValueKey('home-open-plan-button'),
                  label: status == TravelPlanHomeStatus.ongoing
                      ? '오늘 일정'
                      : '여행 기록',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: onOpenPlan,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroActionButton(
                  key: const ValueKey('home-settlement-button'),
                  label: '정산',
                  icon: Icons.receipt_long_outlined,
                  onPressed: onSettlement,
                  backgroundColor: AppColors.accentLime,
                  foregroundColor: AppColors.ink,
                ),
              ),
            ],
          )
        else
          _HeroActionButton(
            key: const ValueKey('home-open-plan-button'),
            label: travelPlanHomeActionLabel(plan, DateTime.now()),
            icon: Icons.arrow_forward_rounded,
            onPressed: onOpenPlan,
          ),
      ],
    );
  }
}

class _TravelBadge extends StatelessWidget {
  const _TravelBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accentLime,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: .3,
        ),
      ),
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.backgroundColor = AppColors.white,
    this.foregroundColor = AppColors.primaryBlue,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
      ),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

TravelPlan? nearestActiveTravelPlan(Iterable<TravelPlan> plans, DateTime now) {
  final today = _dateOnly(now);
  final active =
      plans.where((plan) => !_dateOnly(plan.endDate).isBefore(today)).toList()
        ..sort((a, b) => a.startDate.compareTo(b.startDate));
  return active.firstOrNull;
}

class _RouteCardSkeleton extends StatelessWidget {
  const _RouteCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '추천 로그를 불러오는 중',
      child: ExcludeSemantics(
        child: Container(
          height: 286,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 176,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppRadii.card),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 210, height: 18, color: AppColors.gray200),
                    const SizedBox(height: 12),
                    Container(width: 150, height: 13, color: AppColors.gray200),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum TravelPlanHomeStatus { upcoming, ongoing, completed }

TravelPlanHomeStatus travelPlanHomeStatus(TravelPlan plan, DateTime now) {
  final today = _dateOnly(now);
  if (_dateOnly(plan.startDate).isAfter(today)) {
    return TravelPlanHomeStatus.upcoming;
  }
  if (_dateOnly(plan.endDate).isBefore(today)) {
    return TravelPlanHomeStatus.completed;
  }
  return TravelPlanHomeStatus.ongoing;
}

TravelPlan? featuredTravelPlan(Iterable<TravelPlan> plans, DateTime now) {
  final allPlans = plans.toList();
  if (allPlans.isEmpty) return null;

  final ongoing =
      allPlans
          .where(
            (plan) =>
                travelPlanHomeStatus(plan, now) == TravelPlanHomeStatus.ongoing,
          )
          .toList()
        ..sort((a, b) => b.startDate.compareTo(a.startDate));
  if (ongoing.isNotEmpty) return ongoing.first;

  final upcoming =
      allPlans
          .where(
            (plan) =>
                travelPlanHomeStatus(plan, now) ==
                TravelPlanHomeStatus.upcoming,
          )
          .toList()
        ..sort((a, b) => a.startDate.compareTo(b.startDate));
  if (upcoming.isNotEmpty) return upcoming.first;

  final completed =
      allPlans
          .where(
            (plan) =>
                travelPlanHomeStatus(plan, now) ==
                TravelPlanHomeStatus.completed,
          )
          .toList()
        ..sort((a, b) => b.endDate.compareTo(a.endDate));
  return completed.first;
}

String travelPlanDdayLabel(TravelPlan plan, DateTime now) {
  final status = travelPlanHomeStatus(plan, now);
  if (status == TravelPlanHomeStatus.completed) return '여행 완료';
  final days = _dateOnly(plan.startDate).difference(_dateOnly(now)).inDays;
  if (days > 0) return 'D-$days';
  return '여행 ${days.abs() + 1}일차';
}

String travelPlanHomeActionLabel(TravelPlan plan, DateTime now) {
  return switch (travelPlanHomeStatus(plan, now)) {
    TravelPlanHomeStatus.upcoming => '여행 계획 보기',
    TravelPlanHomeStatus.ongoing => '오늘의 일정 보기',
    TravelPlanHomeStatus.completed => '여행 기록 완성하기',
  };
}

int currentTravelPlanDayIndex(TravelPlan plan, DateTime now) {
  final index = _dateOnly(now).difference(_dateOnly(plan.startDate)).inDays;
  if (index <= 0) return 0;
  final lastIndex = plan.dayCount - 1;
  return index > lastIndex ? lastIndex : index;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _compactDate(DateTime value) => '${value.month}.${value.day}';

class HomeUserSummary {
  const HomeUserSummary({required this.displayName, this.avatarUrl});

  final String displayName;
  final String? avatarUrl;

  String get initial {
    final name = displayName.trim();
    return name.isEmpty ? 'L' : name.characters.first.toUpperCase();
  }
}

class _ShortcutGrid extends StatelessWidget {
  const _ShortcutGrid({
    required this.onRouteSearchTap,
    required this.onUploadTap,
  });

  final VoidCallback? onRouteSearchTap;
  final VoidCallback? onUploadTap;

  @override
  Widget build(BuildContext context) {
    final items =
        <
          ({
            IconData icon,
            String label,
            Color color,
            VoidCallback? action,
            String key,
          })
        >[
          (
            icon: Icons.route_outlined,
            label: '로그 찾기',
            color: AppColors.sky,
            action: onRouteSearchTap,
            key: 'home-shortcut-search',
          ),
          (
            icon: Icons.add_photo_alternate_outlined,
            label: '로그 만들기',
            color: AppColors.mint,
            action: onUploadTap,
            key: 'home-shortcut-upload',
          ),
        ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        Widget tile(
          ({
            IconData icon,
            String label,
            Color color,
            VoidCallback? action,
            String key,
          })
          item,
          double height,
        ) => SizedBox(
          key: ValueKey(item.key),
          height: height,
          child: Semantics(
            button: true,
            enabled: item.action != null,
            label: item.label,
            hint: item.action == null ? '준비 중' : null,
            child: Opacity(
              opacity: item.action == null ? .58 : 1,
              child: Material(
                color: item.action == null
                    ? AppColors.disabledSurface
                    : item.color,
                borderRadius: BorderRadius.circular(AppRadii.card),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  onTap: item.action,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Icon(item.icon, color: AppColors.primaryBlue, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        if (item.action == null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(
                                AppRadii.pill,
                              ),
                            ),
                            child: const Text(
                              '준비 중',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.disabledContent,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        if (textScale >= 1.3 || constraints.maxWidth < 360) {
          return Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                tile(items[index], 72),
                if (index != items.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: tile(items[0], 88)),
            const SizedBox(width: 12),
            Expanded(child: tile(items[1], 88)),
          ],
        );
      },
    );
  }
}

class _PopularPlacesPanel extends StatelessWidget {
  const _PopularPlacesPanel({required this.onPlaceTap});

  final ValueChanged<String> onPlaceTap;

  @override
  Widget build(BuildContext context) {
    final places = [
      ('성수 카페거리', '방문자 추천 88%'),
      ('경주 황리단길', '방문자 추천 91%'),
      ('제주 동문시장', '방문자 추천 94%'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('최근 인기 관광지', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          SizedBox(
            height: 124,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: places.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final place = places[index];
                return SizedBox(
                  width: 220,
                  child: AppCard(
                    onTap: () => onPlaceTap(place.$1),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(
                          Icons.near_me_outlined,
                          color: index == 0
                              ? AppColors.primaryBlue
                              : AppColors.textSecondary,
                        ),
                        Text(
                          place.$1,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          place.$2,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: AppColors.gray500),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
