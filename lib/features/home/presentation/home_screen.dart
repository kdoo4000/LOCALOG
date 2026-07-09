import 'package:flutter/material.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../route_search/data/mock_route_repository.dart';
import '../../route_search/domain/travel_route.dart';
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
    Navigator.of(
      context,
    ).pushNamed(RouteNames.routeDetail, arguments: route.id);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _HomeHero(
              onDestinationTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(strings.destinationComing)),
                );
              },
            ),
            const SizedBox(height: 18),
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
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
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

                return Column(
                  children: [
                    for (final route in snapshot.data!) ...[
                      RouteCard(route: route, onTap: () => _openRoute(route)),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({required this.onDestinationTap});

  final VoidCallback onDestinationTap;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LIKE LOCAL',
            style: TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            strings.homeHeroTitle,
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.w900,
              fontSize: 34,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 18),
          InkWell(
            onTap: onDestinationTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.place_outlined, color: AppColors.accentYellow),
                const SizedBox(width: 6),
                Text(
                  strings.homeLocation,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down, color: AppColors.white),
              ],
            ),
          ),
        ],
      ),
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
      (Icons.search, strings.shortcutRouteSearch),
      (Icons.receipt_long_outlined, strings.shortcutScanReceipt),
      (Icons.add_photo_alternate_outlined, strings.shortcutUploadRoute),
      (Icons.download_outlined, strings.shortcutDownload),
      (Icons.map_outlined, strings.shortcutMapView),
      (Icons.notifications_none, strings.shortcutNotifications),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.96,
      children: [
        for (final item in items)
          AppCard(
            padding: const EdgeInsets.all(12),
            onTap: () => onShortcutTap(item.$2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.$1, color: AppColors.primaryBlue),
                const SizedBox(height: 8),
                Text(
                  item.$2,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
