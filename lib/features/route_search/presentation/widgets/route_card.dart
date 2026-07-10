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
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.sky,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              cityInitial,
              style: const TextStyle(
                color: AppColors.primaryBlue,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
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
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.chevron_right, color: AppColors.gray400),
        ],
      ),
    );
  }
}
