import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class RegionChipWrap extends StatelessWidget {
  const RegionChipWrap({
    super.key,
    required this.regions,
    this.foregroundColor = AppColors.primaryBlue,
    this.backgroundColor = AppColors.sky,
    this.borderColor,
    this.compact = false,
  });

  final List<String> regions;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color? borderColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final visibleRegions = regions
        .map((region) => region.trim())
        .where((region) => region.isNotEmpty)
        .toSet();
    if (visibleRegions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final region in visibleRegions)
          Container(
            key: ValueKey('region-chip-$region'),
            constraints: const BoxConstraints(maxWidth: 260),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10,
              vertical: compact ? 5 : 6,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border.all(
                color: borderColor ?? foregroundColor.withValues(alpha: 0.16),
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: compact ? 13 : 15,
                  color: foregroundColor,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    compactRegionLabel(region),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String compactRegionLabel(String region) {
  const provinceLabels = {
    '서울특별시': '서울',
    '부산광역시': '부산',
    '대구광역시': '대구',
    '인천광역시': '인천',
    '광주광역시': '광주',
    '대전광역시': '대전',
    '울산광역시': '울산',
    '세종특별자치시': '세종',
    '경기도': '경기',
    '강원특별자치도': '강원',
    '충청북도': '충북',
    '충청남도': '충남',
    '전북특별자치도': '전북',
    '전라북도': '전북',
    '전라남도': '전남',
    '전남광주통합특별시': '광주·전남',
    '경상북도': '경북',
    '경상남도': '경남',
    '제주특별자치도': '제주',
  };
  final parts = region
      .split(RegExp(r'\s*>\s*'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return region.trim();
  parts[0] = provinceLabels[parts[0]] ?? parts[0];
  return parts.join(' ');
}
