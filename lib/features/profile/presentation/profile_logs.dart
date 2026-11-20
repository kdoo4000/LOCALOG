import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../route_search/domain/travel_route.dart';
import '../../route_search/presentation/widgets/route_card.dart';

class ProfileLogs extends StatefulWidget {
  const ProfileLogs({
    super.key,
    required this.routes,
    required this.onOpen,
    this.title = '공개 로그',
    this.emptyMessage = '아직 공개한 로그가 없어요.',
    this.showVisibility = false,
  });

  final List<TravelRoute> routes;
  final ValueChanged<TravelRoute> onOpen;
  final String title;
  final String emptyMessage;
  final bool showVisibility;

  @override
  State<ProfileLogs> createState() => _ProfileLogsState();
}

class _ProfileLogsState extends State<ProfileLogs> {
  bool _grid = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              widget.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: '사진 카드로 보기',
            isSelected: !_grid,
            selectedIcon: const Icon(Icons.view_agenda),
            icon: const Icon(Icons.view_agenda_outlined),
            onPressed: () => setState(() => _grid = false),
          ),
          IconButton(
            tooltip: '3열 사진으로 보기',
            isSelected: _grid,
            selectedIcon: const Icon(Icons.grid_on),
            icon: const Icon(Icons.grid_view_outlined),
            onPressed: () => setState(() => _grid = true),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (widget.routes.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            widget.emptyMessage,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        )
      else if (_grid)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 3,
            mainAxisSpacing: 3,
          ),
          itemCount: widget.routes.length,
          itemBuilder: (context, index) {
            final route = widget.routes[index];
            return Semantics(
              button: true,
              label: '${route.title}, ${route.city}',
              child: Material(
                color: AppColors.primaryBlueSoft,
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.circular(4),
                child: InkWell(
                  onTap: () => widget.onOpen(route),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RouteCoverImage(
                        path: route.coverImageUrl,
                        fallbackInitial: route.city.isEmpty
                            ? '?'
                            : route.city.substring(0, 1),
                      ),
                      if (widget.showVisibility && !route.isPublic)
                        const Positioned(
                          top: 6,
                          right: 6,
                          child: Icon(
                            Icons.lock,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          color: Colors.black54,
                          padding: const EdgeInsets.all(6),
                          child: Text(
                            route.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        )
      else
        for (final route in widget.routes)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.showVisibility)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      route.isPublic ? '전체 공개' : '나만 보기',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                RouteCard(route: route, onTap: () => widget.onOpen(route)),
              ],
            ),
          ),
    ],
  );
}
