import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../services/supabase_initializer.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 900), () {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacementNamed(
        hasSupabaseSession ? RouteNames.main : RouteNames.onboarding,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: Center(
        child: TweenAnimationBuilder<double>(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : AppMotion.emphasized,
          curve: AppMotion.curve,
          tween: Tween(begin: .92, end: 1),
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.scale(scale: value, child: child),
          ),
          child: SvgPicture.asset(
            'assets/localog_text_vertical.svg',
            width: 176,
            height: 239,
            fit: BoxFit.contain,
            semanticsLabel: 'LOCALOG',
          ),
        ),
      ),
    );
  }
}
