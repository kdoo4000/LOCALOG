import 'dart:async';

import 'package:flutter/material.dart';

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
    return const Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'LIKE LOCAL',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: 10),
            Text(
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
