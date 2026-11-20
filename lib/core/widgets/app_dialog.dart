import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Shared spacing for confirmation and input dialogs.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    this.title,
    this.content,
    this.actions = const [],
  });

  final Widget? title;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actionStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
    );
    return Theme(
      data: theme.copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: actionStyle.merge(theme.filledButtonTheme.style),
        ),
        textButtonTheme: TextButtonThemeData(
          style: actionStyle.copyWith(
            backgroundColor: const WidgetStatePropertyAll(
              AppColors.surfaceMuted,
            ),
            foregroundColor: const WidgetStatePropertyAll(
              AppColors.textPrimary,
            ),
          ),
        ),
      ),
      child: AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.feature),
        ),
        constraints: BoxConstraints(
          minWidth: (MediaQuery.sizeOf(context).width - 48).clamp(0.0, 440.0),
          maxWidth: 440,
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        title: title,
        content: content,
        scrollable: true,
        actions: actions.isEmpty
            ? null
            : [
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth / actions.length <
                        120 * MediaQuery.textScalerOf(context).scale(1)) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < actions.length; i++) ...[
                            if (i > 0) const SizedBox(height: 12),
                            actions[i],
                          ],
                        ],
                      );
                    }
                    return Row(
                      children: [
                        for (var i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(width: 12),
                          Expanded(child: actions[i]),
                        ],
                      ],
                    );
                  },
                ),
              ],
      ),
    );
  }
}
