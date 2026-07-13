import 'package:flutter/material.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/home/presentation/main_shell_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/route_search/presentation/route_detail_screen.dart';
import '../../features/route_search/presentation/route_download_edit_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import 'route_names.dart';

abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) {
        return switch (settings.name) {
          RouteNames.splash => const SplashScreen(),
          RouteNames.onboarding => const OnboardingScreen(),
          RouteNames.login => const LoginScreen(),
          RouteNames.main => const MainShellScreen(),
          RouteNames.routeDetail => _routeDetailScreen(settings.arguments),
          RouteNames.routeDownloadEdit =>
            _routeDownloadEditScreen(settings.arguments),
          _ => const SplashScreen(),
        };
      },
    );
  }

  static Widget _routeDetailScreen(Object? arguments) {
    if (arguments is RouteDetailArguments) {
      return RouteDetailScreen(
        routeId: arguments.routeId,
        showSourceRoute: arguments.showSourceRoute,
      );
    }

    return RouteDetailScreen(routeId: arguments as String);
  }

  static Widget _routeDownloadEditScreen(Object? arguments) {
    if (arguments is RouteDownloadEditArguments) {
      return RouteDownloadEditScreen(
        routeId: arguments.routeId,
        createNewCopy: arguments.createNewCopy,
      );
    }

    return RouteDownloadEditScreen(routeId: arguments as String);
  }
}
