import 'package:flutter/material.dart';

import '../../../../core/l10n/app_language.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/travel_route.dart';

class RouteCard extends StatelessWidget {
  const RouteCard({super.key, required this.route, this.onTap});

  final TravelRoute route;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final upvote = '${(route.upvoteRatio * 100).round()}%';
    final duration = context.strings.durationLabel(
      route.estimatedDurationMinutes,
    );
    final cityInitial = route.city.isEmpty ? '?' : route.city.substring(0, 1);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
              color: AppColors.accentLime,
              child: route.coverImageUrl?.startsWith('assets/') == true
                  ? Image.asset(
                      route.coverImageUrl!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _CityInitial(
                        initial: cityInitial,
                      ),
                    )
                  : _CityInitial(initial: cityInitial),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  route.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '추천 $upvote · ${route.places.length}곳 · $duration',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.gray500,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (route.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in route.tags.take(4))
                        _RouteTagChip(label: tag),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CityInitial extends StatelessWidget {
  const _CityInitial({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: AppColors.primaryBlue,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RouteTagChip extends StatelessWidget {
  const _RouteTagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.gray50,
        border: Border.all(color: AppColors.gray200),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          '#$label',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }
}
