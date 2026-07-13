import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Container(
                height: 220,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.secondaryLavender,
                  borderRadius: BorderRadius.circular(8),
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
                '사진만 올리면 로컬 루트가 됩니다',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '촬영 시간과 위치를 바탕으로 여행자의 하루를 정리하고, 다른 사람이 바로 다운로드할 수 있는 코스로 만듭니다.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.black54,
                  height: 1.45,
                ),
              ),
              const Spacer(),
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
    );
  }
}
