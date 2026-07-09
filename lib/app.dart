import 'package:flutter/material.dart';

import 'core/l10n/app_language.dart';
import 'core/router/app_router.dart';
import 'core/router/route_names.dart';
import 'core/theme/app_theme.dart';

class LikeLocalApp extends StatefulWidget {
  const LikeLocalApp({super.key});

  @override
  State<LikeLocalApp> createState() => _LikeLocalAppState();
}

class _LikeLocalAppState extends State<LikeLocalApp> {
  final _languageController = AppLanguageController();

  @override
  void dispose() {
    _languageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppLanguageScope(
      controller: _languageController,
      child: AnimatedBuilder(
        animation: _languageController,
        builder: (context, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Like Local',
            locale: Locale(_languageController.language.name),
            theme: AppTheme.light,
            initialRoute: RouteNames.splash,
            onGenerateRoute: AppRouter.onGenerateRoute,
          );
        },
      ),
    );
  }
}
