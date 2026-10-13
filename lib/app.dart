import 'package:flutter/material.dart';

import 'core/l10n/app_language.dart';
import 'core/router/app_router.dart';
import 'core/router/route_names.dart';
import 'core/theme/app_theme.dart';
import 'services/supabase_initializer.dart';

class LocalogApp extends StatefulWidget {
  const LocalogApp({super.key});

  @override
  State<LocalogApp> createState() => _LocalogAppState();
}

class _LocalogAppState extends State<LocalogApp> {
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
            title: 'LOCALOG',
            locale: Locale(_languageController.language.name),
            theme: AppTheme.light,
            builder: (context, child) => Column(
              children: [
                if (!isSupabaseConfigured)
                  Material(
                    color: Theme.of(context).colorScheme.surface,
                    child: const SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text('예시 모드 · 공개 로그에 예시 데이터가 포함됩니다.'),
                      ),
                    ),
                  ),
                Expanded(child: child!),
              ],
            ),
            initialRoute: RouteNames.splash,
            onGenerateRoute: AppRouter.onGenerateRoute,
          );
        },
      ),
    );
  }
}
