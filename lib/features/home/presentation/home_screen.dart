import 'package:flutter/material.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../route_search/data/mock_route_repository.dart';
import '../../route_search/domain/travel_route.dart';
import '../../route_search/presentation/route_detail_screen.dart';
import '../../route_search/presentation/widgets/route_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repository = const MockRouteRepository();
  late final Future<List<TravelRoute>> _routesFuture;

  @override
  void initState() {
    super.initState();
    _routesFuture = _repository.getRecommendedRoutes();
  }

  void _openRoute(TravelRoute route) {
    Navigator.of(context).pushNamed(
      RouteNames.routeDetail,
      arguments: RouteDetailArguments(
        routeId: route.id,
        showSourceRoute: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 18, 28, 28),
          children: [
            _HomeHeader(
              onDestinationTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(strings.destinationComing)),
                );
              },
            ),
            const SizedBox(height: 26),
            _ShortcutGrid(
              onShortcutTap: (label) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(strings.shortcutComing(label))),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              strings.monthlyRecommend,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<TravelRoute>>(
              future: _routesFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final featured = snapshot.data!.first;
                return RouteCard(route: featured, onTap: () => _openRoute(featured));
              },
            ),
            const SizedBox(height: 28),
            const _PopularPlacesPanel(),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onDestinationTap});

  final VoidCallback onDestinationTap;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'LL',
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
            const Spacer(),
            CircleAvatar(
              radius: 21,
              backgroundColor: AppColors.sky,
              child: Text(
                'P',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          strings.homeHeroTitle,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: AppColors.ink,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                height: 1.08,
              ),
        ),
        const SizedBox(height: 18),
        Material(
          color: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.gray200),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onDestinationTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.place_outlined, color: AppColors.primaryBlue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      strings.homeLocation,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Text(
                    '변경',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShortcutGrid extends StatelessWidget {
  const _ShortcutGrid({required this.onShortcutTap});

  final ValueChanged<String> onShortcutTap;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final items = [
      (Icons.route_outlined, strings.shortcutRouteSearch, AppColors.sky),
      (Icons.receipt_long_outlined, strings.shortcutScanReceipt, AppColors.yellow),
      (Icons.add_photo_alternate_outlined, strings.shortcutUploadRoute, AppColors.mint),
      (Icons.map_outlined, strings.shortcutMapView, AppColors.sky),
    ];

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.92,
      children: [
        for (final item in items)
          Material(
            color: item.$3,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onShortcutTap(item.$2),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.$1, color: AppColors.primaryBlue, size: 26),
                    const SizedBox(height: 8),
                    Text(
                      item.$2,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PopularPlacesPanel extends StatelessWidget {
  const _PopularPlacesPanel();

  @override
  Widget build(BuildContext context) {
    final places = [
      ('성수 카페거리', '방문자 추천 88%'),
      ('경주 황리단길', '방문자 추천 91%'),
      ('제주 동문시장', '방문자 추천 94%'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.gray100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '최근 인기 관광지',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 14),
          for (final place in places) ...[
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      place.$1,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Text(
                    place.$2,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.gray500,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
