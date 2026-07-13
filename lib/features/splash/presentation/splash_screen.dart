import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';

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
      Navigator.of(context).pushReplacementNamed(RouteNames.onboarding);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(32)),
              child: SvgPicture.asset(
                'assets/localog_logo.svg',
                width: 180,
                height: 180,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your best local guide',
              style: TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
