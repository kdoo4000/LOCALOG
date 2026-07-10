import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../route_search/data/mock_route_repository.dart';
import '../../route_search/domain/travel_route.dart';
import '../../route_search/presentation/widgets/route_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _repository = const MockRouteRepository();
  StreamSubscription<void>? _downloadedRoutesSubscription;

  @override
  void initState() {
    super.initState();
    _downloadedRoutesSubscription = _repository.downloadedRoutesChanged.listen((
      _,
    ) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _downloadedRoutesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _openRoute(TravelRoute route) async {
    await Navigator.of(
      context,
    ).pushNamed(RouteNames.routeDetail, arguments: route.id);
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _deleteRoute(TravelRoute route) async {
    final strings = context.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dialogStrings = context.strings;

        return AlertDialog(
          title: Text(dialogStrings.deleteRouteTitle),
          content: Text(dialogStrings.deleteRouteMessage(route.title)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(dialogStrings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(dialogStrings.delete),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _repository.deleteDownloadedRoute(route.id);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(strings.routeDeleted)));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<TravelRoute>>(
          future: _repository.getDownloadedRoutes(),
          builder: (context, snapshot) {
            final routes = snapshot.data ?? const <TravelRoute>[];
            final uploadedRoutes = routes
                .where((route) => route.sourceRouteId == null)
                .toList();
            final downloadedRoutes = routes
                .where((route) => route.sourceRouteId != null)
                .toList();

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {});
                await _repository.getDownloadedRoutes();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 34, 28, 28),
                children: [
                  Text(
                    strings.profileTitle,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 20),
                  const _ProfileHeader(),
                  const SizedBox(height: 24),
                  const _LanguageSelector(),
                  const SizedBox(height: 24),
                  Text(
                    strings.myRouteList,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (!snapshot.hasData)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (routes.isEmpty)
                    const _EmptyDownloadedRoutes()
                  else ...[
                    if (uploadedRoutes.isNotEmpty) ...[
                      _RouteSectionTitle(title: strings.uploadedRoutes),
                      const SizedBox(height: 10),
                      for (final route in uploadedRoutes) ...[
                        _DownloadedRouteTile(
                          route: route,
                          onOpen: () => _openRoute(route),
                          onDelete: () => _deleteRoute(route),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                    if (downloadedRoutes.isNotEmpty) ...[
                      if (uploadedRoutes.isNotEmpty) const SizedBox(height: 10),
                      _RouteSectionTitle(title: strings.downloadedRoutes),
                      const SizedBox(height: 10),
                      for (final route in downloadedRoutes) ...[
                        _DownloadedRouteTile(
                          route: route,
                          onOpen: () => _openRoute(route),
                          onDelete: () => _deleteRoute(route),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RouteSectionTitle extends StatelessWidget {
  const _RouteSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.gray500,
            fontWeight: FontWeight.w900,
          ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const CircleAvatar(
              radius: 37,
              backgroundColor: AppColors.sky,
              child: Text(
                'P',
                style: TextStyle(
                  color: AppColors.primaryBlue,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Username',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Change profile',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.gray500,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        AppCard(
          child: Row(
            children: const [
              Expanded(
                child: _ProfileStat(label: '누적 좋아요', value: '12,430'),
              ),
              Expanded(
                child: _ProfileStat(label: '다운로드', value: '327'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.gray500,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector();

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final controller = context.languageController;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.language,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          SegmentedButton<AppLanguage>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: AppLanguage.ko, label: Text(strings.korean)),
              ButtonSegment(value: AppLanguage.en, label: Text(strings.english)),
            ],
            selected: {controller.language},
            onSelectionChanged: (selection) {
              controller.setLanguage(selection.first);
            },
          ),
        ],
      ),
    );
  }
}

class _DownloadedRouteTile extends StatelessWidget {
  const _DownloadedRouteTile({
    required this.route,
    required this.onOpen,
    required this.onDelete,
  });

  final TravelRoute route;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final isUploadedRoute = route.sourceRouteId == null;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
            child: Row(
              children: [
                Icon(
                  isUploadedRoute
                      ? Icons.add_photo_alternate_outlined
                      : Icons.bookmark_added,
                  color: AppColors.primaryBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isUploadedRoute
                        ? strings.uploadedRouteLabel
                        : strings.downloadedRouteLabel,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: strings.delete,
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
          RouteCard(route: route, onTap: onOpen),
        ],
      ),
    );
  }
}

class _EmptyDownloadedRoutes extends StatelessWidget {
  const _EmptyDownloadedRoutes();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(context.strings.emptyDownloadedRoutes),
    );
  }
}
