import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../data/route_repository.dart';
import '../data/route_repository_provider.dart';
import '../domain/route_place.dart';
import 'widgets/route_card.dart';

class PlaceDetailArguments {
  const PlaceDetailArguments(this.place);
  final RoutePlace place;
}

class PlaceDetailScreen extends StatefulWidget {
  const PlaceDetailScreen({super.key, required this.place});
  final RoutePlace place;

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  late Future<PlaceDetail> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = routeRepository.getPlaceDetail(widget.place);
  void _retry() => setState(_load);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: FutureBuilder<PlaceDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _PlaceLoadState(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 40,
                    color: AppColors.gray500,
                  ),
                  const SizedBox(height: 16),
                  const Text('장소 정보를 불러오지 못했습니다.'),
                  const SizedBox(height: 16),
                  OutlinedButton(onPressed: _retry, child: const Text('다시 시도')),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return const _PlaceLoadState(child: CircularProgressIndicator());
          }

          final detail = snapshot.data!;
          final place = detail.place;
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 330,
                backgroundColor: AppColors.surfaceElevated,
                foregroundColor: AppColors.ink,
                surfaceTintColor: Colors.transparent,
                title: Text(place.name),
                flexibleSpace: FlexibleSpaceBar(
                  background: _PlaceHero(
                    place: place,
                    imageUrl: detail.tourInfo?.imageUrl,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final gutter = constraints.maxWidth >= 700 ? 40.0 : 20.0;
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            gutter,
                            24,
                            gutter,
                            24 + MediaQuery.paddingOf(context).bottom,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _PlaceMetaStrip(
                                logCount: detail.routes.length,
                                hasTourInfo: detail.tourInfo != null,
                              ),
                              if (detail.tourInfo != null) ...[
                                const SizedBox(height: 20),
                                _TourSummary(
                                  place: place,
                                  info: detail.tourInfo!,
                                ),
                              ],
                              const SizedBox(height: 32),
                              _SectionHeading(
                                title: '이 장소가 포함된 로그',
                                count: detail.routes.length,
                              ),
                              const SizedBox(height: 16),
                              if (detail.routes.isEmpty)
                                const _EmptyLogsCard()
                              else
                                for (final route in detail.routes) ...[
                                  RouteCard(
                                    route: route,
                                    onTap: () =>
                                        Navigator.of(context).pushNamed(
                                          RouteNames.routeDetail,
                                          arguments: route.id,
                                        ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlaceHero extends StatelessWidget {
  const _PlaceHero({required this.place, required this.imageUrl});
  final RoutePlace place;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return Semantics(
      image: true,
      label: '${place.name} 대표 이미지',
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null && url.isNotEmpty)
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const _PlaceHeroFallback(),
            )
          else
            const _PlaceHeroFallback(),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x12000000), Color(0xD9000000)],
                stops: [0.35, 1],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (place.displayCategory.isNotEmpty) ...[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.accentLime,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        place.displayCategory,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  place.name,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (place.address?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          place.address!.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFFE8EAF0),
                                height: 1.35,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceHeroFallback extends StatelessWidget {
  const _PlaceHeroFallback();
  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.primaryBlue,
      child: Center(
        child: Icon(
          Icons.place_outlined,
          size: 76,
          color: AppColors.primaryBlueSoft,
        ),
      ),
    );
  }
}

class _PlaceLoadState extends StatelessWidget {
  const _PlaceLoadState({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            left: 8,
            top: 4,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: '뒤로 가기',
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          Center(child: child),
        ],
      ),
    );
  }
}

class _PlaceMetaStrip extends StatelessWidget {
  const _PlaceMetaStrip({required this.logCount, required this.hasTourInfo});
  final int logCount;
  final bool hasTourInfo;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MetaChip(icon: Icons.route_outlined, label: '포함 로그 $logCount개'),
        if (hasTourInfo)
          const _MetaChip(
            icon: Icons.verified_outlined,
            label: '관광공사 정보',
            emphasized: true,
          ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.emphasized = false,
  });
  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final color = emphasized ? AppColors.primaryBlue : AppColors.gray500;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: emphasized ? AppColors.primaryBlueSoft : AppColors.surface,
        border: Border.all(
          color: emphasized ? AppColors.primaryBlueSoft : AppColors.gray200,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.count});
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$count',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _EmptyLogsCard extends StatelessWidget {
  const _EmptyLogsCard();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            Icon(Icons.route_outlined, size: 34, color: AppColors.gray400),
            SizedBox(height: 12),
            Text('아직 공개된 로그가 없습니다.'),
          ],
        ),
      ),
    );
  }
}

class _TourSummary extends StatelessWidget {
  const _TourSummary({required this.place, required this.info});
  final RoutePlace place;
  final TourPlaceInfo info;

  @override
  Widget build(BuildContext context) {
    final guideItems = <(IconData, String, String?)>[
      (Icons.schedule_outlined, '이용 시간', info.openingHours),
      (Icons.event_busy_outlined, '쉬는 날', info.restDay),
      (Icons.local_parking_outlined, '주차', info.parking),
    ].where((item) => item.$3 != null && item.$3!.isNotEmpty).toList();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '장소 소개',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '한국관광공사 제공',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppColors.gray500),
              ),
            ],
          ),
          if (info.overview != null && info.overview!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              info.overview!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.55),
            ),
          ],
          if (guideItems.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Divider(height: 1, color: AppColors.gray200),
            const SizedBox(height: 18),
            Text(
              '이용 안내',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            for (final item in guideItems) ...[
              _CompactGuideRow(icon: item.$1, label: item.$2, text: item.$3!),
              if (item != guideItems.last) const SizedBox(height: 12),
            ],
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _TourDetailScreen(place: place, info: info),
                ),
              ),
              icon: const Icon(Icons.arrow_forward, size: 18),
              iconAlignment: IconAlignment.end,
              label: const Text('상세정보 보기'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactGuideRow extends StatelessWidget {
  const _CompactGuideRow({
    required this.icon,
    required this.label,
    required this.text,
  });
  final IconData icon;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label, ${_formatTourText(text)}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.primaryBlueSoft,
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(icon, size: 18, color: AppColors.primaryBlue),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatTourText(text),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.gray500,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TourDetailScreen extends StatelessWidget {
  const _TourDetailScreen({required this.place, required this.info});
  final RoutePlace place;
  final TourPlaceInfo info;

  @override
  Widget build(BuildContext context) {
    final details = <(IconData, String, String?)>[
      (Icons.schedule_outlined, '이용 시간', info.openingHours),
      (Icons.event_busy_outlined, '쉬는 날', info.restDay),
      (Icons.local_parking_outlined, '주차', info.parking),
      (Icons.payments_outlined, '이용 요금', info.fee),
      (Icons.call_outlined, '문의', info.telephone),
      (Icons.language_outlined, '홈페이지', info.homepage),
    ].where((item) => item.$3 != null && item.$3!.isNotEmpty).toList();
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(title: const Text('상세정보')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text(
            place.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '한국관광공사 제공',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppColors.gray500),
          ),
          if (info.overview != null && info.overview!.isNotEmpty) ...[
            const SizedBox(height: 20),
            AppCard(
              child: Text(
                info.overview!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.65),
              ),
            ),
          ],
          if (details.isNotEmpty) ...[
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '이용 안내',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  for (final item in details) ...[
                    const SizedBox(height: 18),
                    _LabeledInfoRow(
                      icon: item.$1,
                      label: item.$2,
                      text: item.$3!,
                      onTap: item.$2 == '홈페이지'
                          ? () => _openHomepage(context, item.$3!)
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LabeledInfoRow extends StatelessWidget {
  const _LabeledInfoRow({
    required this.icon,
    required this.label,
    required this.text,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: AppColors.primaryBlue),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Semantics(
                link: onTap != null,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      _formatTourText(text),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: onTap == null
                            ? AppColors.gray500
                            : AppColors.primaryBlue,
                        height: 1.55,
                        decoration: onTap == null
                            ? null
                            : TextDecoration.underline,
                        decorationColor: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _formatTourText(String value) {
  final withSeasonLines = value.replaceAllMapped(
    RegExp(r'\s*(\[[^\]]+\])\s*'),
    (match) => '${match.start == 0 ? '' : '\n'}${match.group(1)} ',
  );
  return withSeasonLines
      .replaceAllMapped(RegExp(r'\s*※\s*'), (_) => '\n※ ')
      .trim();
}

Future<void> _openHomepage(BuildContext context, String value) async {
  final raw = value.trim();
  final parsed = Uri.tryParse(raw);
  final uri = parsed != null && parsed.hasScheme
      ? parsed
      : Uri.tryParse('https://$raw');
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    _showLinkError(context);
    return;
  }
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) _showLinkError(context);
}

void _showLinkError(BuildContext context) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('홈페이지를 열 수 없습니다.')));
}
