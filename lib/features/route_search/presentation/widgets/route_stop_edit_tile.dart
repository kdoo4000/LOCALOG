import 'package:flutter/material.dart';

import '../../../../core/l10n/app_language.dart';
import '../../../../core/widgets/app_card.dart';

class RouteStopEditTile extends StatelessWidget {
  const RouteStopEditTile({
    super.key,
    required this.index,
    required this.title,
    required this.subtitle,
    this.onRemove,
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
  final bool placeSelected;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(10),
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
