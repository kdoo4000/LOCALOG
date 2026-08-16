import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/premium_ui.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.warmBackground, AppColors.primaryBlueSoft],
            begin: Alignment.topCenter,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.readingWidth,
              ),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  AppHeroCard(
                    visual: AppHeroVisual.journey,
                    padding: EdgeInsets.zero,
                    child: SizedBox(
                      height: 220,
                      child: Stack(
                        children: [
                          const Positioned(
                            right: 24,
                            top: 22,
                            child: Icon(
                              Icons.location_on_rounded,
                              color: AppColors.accentLime,
                              size: 34,
                            ),
                          ),
                          Center(
                            child: SizedBox(
                              width: 280,
                              height: 158,
                              child: SvgPicture.asset(
                                'assets/localog_text.svg',
                                fit: BoxFit.contain,
                                alignment: Alignment.center,
                                colorFilter: const ColorFilter.mode(
                                  AppColors.white,
                                  BlendMode.srcIn,
                                ),
                                semanticsLabel: 'LOCALOG',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    '사진만 올리면 로컬 로그가 됩니다',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  const Column(
                    children: [
                      _OnboardingFeature(
                        index: '01',
                        icon: Icons.photo_library_outlined,
                        label: '사진을 선택하고',
                      ),
                      SizedBox(height: 10),
                      _OnboardingFeature(
                        index: '02',
                        icon: Icons.route_outlined,
                        label: '하루의 루트를 확인하고',
                      ),
                      SizedBox(height: 10),
                      _OnboardingFeature(
                        index: '03',
                        icon: Icons.bookmark_add_outlined,
                        label: '여행 로그로 저장하세요',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '촬영 시간과 위치를 바탕으로 하루의 루트와 기록을 정리하고, 다른 사람이 여행 계획에 참고할 수 있게 합니다.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 48),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pushReplacementNamed(RouteNames.login);
                    },
                    child: const Text('시작하기'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pushReplacementNamed(RouteNames.main);
                    },
                    child: const Text('게스트로 둘러보기'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingFeature extends StatelessWidget {
  const _OnboardingFeature({
    required this.index,
    required this.icon,
    required this.label,
  });

  final String index;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: .86),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Text(
            index,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.primaryBlueSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primaryBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
        ],
      ),
    );
  }
}
