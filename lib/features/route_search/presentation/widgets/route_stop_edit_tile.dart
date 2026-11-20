import 'package:flutter/material.dart';

import '../../../../core/l10n/app_language.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_card.dart';

class RouteStopDismissible extends StatelessWidget {
  const RouteStopDismissible({
    super.key,
    required this.dismissKey,
    required this.child,
    required this.onDismissed,
    this.confirmDismiss,
    this.enabled = true,
  });

  final Key dismissKey;
  final Widget child;
  final VoidCallback onDismissed;
  final Future<bool> Function()? confirmDismiss;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Dismissible(
        key: dismissKey,
        direction: enabled
            ? DismissDirection.endToStart
            : DismissDirection.none,
        dismissThresholds: const {DismissDirection.endToStart: .42},
        movementDuration: AppMotion.emphasized,
        resizeDuration: AppMotion.standard,
        confirmDismiss: confirmDismiss == null
            ? null
            : (_) => confirmDismiss!(),
        onDismissed: (_) => onDismissed(),
        background: ColoredBox(
          color: colors.errorContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  color: colors.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  context.strings.delete,
                  style: TextStyle(
                    color: colors.onErrorContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}

class RouteStopEditTile extends StatelessWidget {
  const RouteStopEditTile({
    super.key,
    required this.index,
    required this.title,
    required this.subtitle,
    this.onRemove,
    this.onTap,
    this.leading,
    this.onChoosePlace,
    this.onEdit,
    this.placeSelected = false,
    this.showDragHandle = true,
  });

  final int index;
  final String title;
  final String subtitle;
  final Widget? leading;
  final VoidCallback? onChoosePlace;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;
  final bool placeSelected;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(10),
      onTap: onTap,
      child: Row(
        children: [
          Stack(
            children: [
              leading ??
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE07A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.place_outlined),
                  ),
              Positioned(
                left: 4,
                top: 4,
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          if (onChoosePlace != null)
            IconButton.filledTonal(
              onPressed: onChoosePlace,
              tooltip: placeSelected
                  ? context.strings.changePlace
                  : context.strings.choosePlace,
              icon: const Icon(Icons.edit_location_alt_outlined),
            ),
          if (onEdit != null)
            IconButton(
              onPressed: onEdit,
              tooltip: context.strings.editPlace,
              color: Colors.black87,
              icon: const Icon(Icons.edit_outlined),
            ),
          if (showDragHandle)
            ReorderableDragStartListener(
              index: index,
              child: Tooltip(
                message: context.strings.dragToReorder,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.drag_handle, color: Colors.black54),
                ),
              ),
            ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              tooltip: context.strings.delete,
              color: Colors.black87,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
    );
  }
}
