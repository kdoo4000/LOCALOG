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
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.secondaryLavender,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  route.city.substring(0, 1),
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w900,
                    fontSize: 28,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${route.authorName} - ${route.city}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      route.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in route.tags)
                Chip(
                  label: Text(tag),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                  backgroundColor: AppColors.gray100,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Metric(
                icon: Icons.thumb_up_alt_outlined,
                label: '${(route.upvoteRatio * 100).round()}%',
              ),
              const SizedBox(width: 14),
              _Metric(
                icon: Icons.download_outlined,
                label: '${route.downloadCount}',
              ),
              const SizedBox(width: 14),
              _Metric(
                icon: Icons.schedule,
                label: context.strings.durationLabel(
                  route.estimatedDurationMinutes,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.primaryBlue),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
