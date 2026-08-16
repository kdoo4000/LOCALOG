import 'package:flutter/material.dart';

import '../../../../core/l10n/app_language.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/region_chip_wrap.dart';
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

    return Semantics(
      button: onTap != null,
      label: '${route.title}, ${route.city}, ${route.places.length}개 장소',
      child: AppCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Container(
              width: double.infinity,
              height: 184,
              alignment: Alignment.center,
              color: AppColors.accentLime,
              child: _RouteCoverImage(
                path: route.coverImageUrl,
                fallbackInitial: cityInitial,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  route.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.16,
                  ),
                ),
                const SizedBox(height: 8),
                RegionChipWrap(regions: route.effectiveRegions, compact: true),
                const SizedBox(height: 10),
                Text(
                  '추천 $upvote · ${route.places.length}곳 · $duration',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.gray500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (route.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in route.tags.take(2))
                        _RouteTagChip(label: tag),
                    ],
                  ),
                ],
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }
}

class _RouteCoverImage extends StatelessWidget {
  const _RouteCoverImage({required this.path, required this.fallbackInitial});

  final String? path;
  final String fallbackInitial;

  @override
  Widget build(BuildContext context) {
    final imagePath = path;
    if (imagePath == null || imagePath.isEmpty) {
      return _CityInitial(initial: fallbackInitial);
    }

    if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        width: double.infinity,
        height: 184,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _CityInitial(initial: fallbackInitial),
      );
    }

    final uri = Uri.tryParse(imagePath);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return Image.network(
        imagePath,
        width: double.infinity,
        height: 184,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _CityInitial(initial: fallbackInitial),
      );
    }

    return _CityInitial(initial: fallbackInitial);
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
          fontWeight: FontWeight.w700,
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
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ),
    );
  }
}
