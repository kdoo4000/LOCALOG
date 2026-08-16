import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.readingWidth),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
              const SizedBox(height: AppSpacing.xl),
              Container(
                height: 220,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.secondaryLavender,
                  borderRadius: BorderRadius.circular(AppRadii.feature),
                ),
                child: Center(
                  child: SizedBox(
                    width: 280,
                    height: 158,
                    child: SvgPicture.asset(
                      'assets/localog_text.svg',
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      semanticsLabel: 'LOCALOG',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                '사진만 올리면 로컬 로그가 됩니다',
                style: Theme.of(context).textTheme.headlineSmall,
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
                  Navigator.of(context).pushReplacementNamed(RouteNames.login);
                },
                child: const Text('시작하기'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed(RouteNames.main);
                },
                child: const Text('게스트로 둘러보기'),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
