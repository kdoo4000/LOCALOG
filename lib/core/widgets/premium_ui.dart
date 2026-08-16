import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

enum AppHeroVisual { journey, profile, photos, settlement, calendar }

class AppHeroCard extends StatelessWidget {
  const AppHeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(22, 24, 22, 26),
    this.visual = AppHeroVisual.journey,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final AppHeroVisual visual;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryBlue, AppColors.primaryBlueDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.feature),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          ..._decorations(),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }

  List<Widget> _decorations() {
    return switch (visual) {
      AppHeroVisual.journey => [
        const _HeroOrb(right: -54, top: -72, size: 190),
        const _HeroRing(right: 22, bottom: -70, size: 130),
      ],
      AppHeroVisual.profile => [
        const _HeroOrb(left: -70, bottom: -90, size: 200),
        const _HeroRing(right: -20, top: -42, size: 118),
      ],
      AppHeroVisual.photos => [
        const _HeroFrame(right: -18, top: 24, angle: .09),
        const _HeroFrame(right: 34, top: -36, angle: -.08),
      ],
      AppHeroVisual.settlement => [
        const _HeroReceiptLines(),
        const _HeroOrb(right: -76, bottom: -94, size: 210),
      ],
      AppHeroVisual.calendar => [
        const _HeroCalendarMark(),
        const _HeroOrb(left: -82, bottom: -104, size: 210),
      ],
    };
  }
}

class _HeroOrb extends StatelessWidget {
  const _HeroOrb({this.left, this.right, this.top, this.bottom, required this.size});

  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
  final double size;

  @override
  Widget build(BuildContext context) => Positioned(
    left: left,
    right: right,
    top: top,
    bottom: bottom,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.white.withValues(alpha: .08),
      ),
    ),
  );
}

class _HeroRing extends StatelessWidget {
  const _HeroRing({this.right, this.top, this.bottom, required this.size});

  final double? right;
  final double? top;
  final double? bottom;
  final double size;

  @override
  Widget build(BuildContext context) => Positioned(
    right: right,
    top: top,
    bottom: bottom,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.accentLime.withValues(alpha: .35),
          width: 24,
        ),
      ),
    ),
  );
}

class _HeroFrame extends StatelessWidget {
  const _HeroFrame({required this.right, required this.top, required this.angle});

  final double right;
  final double top;
  final double angle;

  @override
  Widget build(BuildContext context) => Positioned(
    right: right,
    top: top,
    child: Transform.rotate(
      angle: angle,
      child: Container(
        width: 92,
        height: 112,
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: .05),
          border: Border.all(color: AppColors.white.withValues(alpha: .14)),
          borderRadius: BorderRadius.circular(AppRadii.image),
        ),
      ),
    ),
  );
}

class _HeroReceiptLines extends StatelessWidget {
  const _HeroReceiptLines();

  @override
  Widget build(BuildContext context) => Positioned(
    right: 18,
    top: 22,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final width in [92.0, 66.0, 80.0]) ...[
          Container(
            width: width,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    ),
  );
}

class _HeroCalendarMark extends StatelessWidget {
  const _HeroCalendarMark();

  @override
  Widget build(BuildContext context) => Positioned(
    right: 18,
    top: 18,
    child: Container(
      width: 96,
      height: 84,
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: .08),
        border: Border.all(color: AppColors.white.withValues(alpha: .14)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(
        Icons.calendar_month_outlined,
        color: Color(0x38FFFFFF),
        size: 44,
      ),
    ),
  );
}

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.description,
    this.eyebrow,
    this.trailing,
  });

  final String title;
  final String? description;
  final String? eyebrow;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .5,
                  ),
                ),
                const SizedBox(height: 5),
              ],
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (description != null) ...[
                const SizedBox(height: 5),
                Text(
                  description!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

class AppStepIndicator extends StatelessWidget {
  const AppStepIndicator({
    super.key,
    required this.steps,
    required this.currentIndex,
  });

  final List<String> steps;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < steps.length; index++) ...[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: AppMotion.standard,
                  height: 4,
                  decoration: BoxDecoration(
                    color: index <= currentIndex
                        ? AppColors.primaryBlue
                        : AppColors.gray200,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  steps[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: index <= currentIndex
                        ? AppColors.ink
                        : AppColors.gray500,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (index != steps.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class AppMetricStrip extends StatelessWidget {
  const AppMetricStrip({super.key, required this.items});

  final List<({String label, String value})> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    items[index].label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    items[index].value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            if (index != items.length - 1)
              const SizedBox(
                height: 34,
                child: VerticalDivider(color: AppColors.borderSubtle),
              ),
          ],
        ],
      ),
    );
  }
}

class AppStickyActionBar extends StatelessWidget {
  const AppStickyActionBar({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: padding,
        decoration: const BoxDecoration(
          color: AppColors.surfaceElevated,
          border: Border(top: BorderSide(color: AppColors.borderSubtle)),
          boxShadow: [
            BoxShadow(
              color: Color(0x102457F5),
              blurRadius: 20,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
