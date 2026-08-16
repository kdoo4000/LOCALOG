import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/core/l10n/app_language.dart';
import 'package:localog/features/trip_planning/presentation/place_search_map_screen.dart';
import 'package:localog/features/trip_planning/presentation/planned_route_edit_screen.dart';
import 'package:localog/features/route_search/presentation/route_download_edit_screen.dart';
import 'package:localog/models/place_candidate.dart';
import 'package:localog/services/place_candidate_service.dart';

void main() {
  testWidgets('direct route creation opens the map place search screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PlannedRouteEditScreen.create(
          planDayId: 'day-1',
          initialCity: '서울특별시',
        ),
      ),
    );

    expect(find.text('첫 장소 검색'), findsOneWidget);
    await tester.tap(find.text('첫 장소 검색'));
    await tester.pumpAndSettle();

    expect(find.byType(PlaceSearchMapScreen), findsOneWidget);
    expect(find.text('장소 검색'), findsOneWidget);
    expect(find.text('장소를 검색하면 지도에서 위치를 확인할 수 있어요.'), findsOneWidget);
    expect(find.text('장소를 선택해 주세요'), findsOneWidget);
  });

  testWidgets('log editing opens the same map place search screen', (
    tester,
  ) async {
    final languageController = AppLanguageController();
    addTearDown(languageController.dispose);

    await tester.pumpWidget(
      AppLanguageScope(
        controller: languageController,
        child: const MaterialApp(
          home: RouteDownloadEditScreen(
            routeId: 'seongsu-cafe-local-route',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('장소 추가'));
    await tester.pumpAndSettle();

    expect(find.byType(PlaceSearchMapScreen), findsOneWidget);
    expect(find.text('장소 검색'), findsOneWidget);
  });

  testWidgets('log place details open on a separate edit screen', (
    tester,
  ) async {
    final languageController = AppLanguageController();
    addTearDown(languageController.dispose);

    await tester.pumpWidget(
      AppLanguageScope(
        controller: languageController,
        child: const MaterialApp(
          home: RouteDownloadEditScreen(
            routeId: 'seongsu-cafe-local-route',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('장소 수정').first);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('장소 수정'), findsOneWidget);
    expect(find.text('지점 설명'), findsOneWidget);
    expect(find.text('예상 비용(원)'), findsOneWidget);
  });

  testWidgets('photo coordinates load nearby places on screen entry', (
    tester,
  ) async {
    final service = _NearbyPlaceService();
    await tester.pumpWidget(
      MaterialApp(
        home: PlaceSearchMapScreen(
          initialLatitude: 37.5445,
          initialLongitude: 127.0560,
          placeCandidateService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.latitude, 37.5445);
    expect(service.longitude, 127.0560);
    expect(find.text('성수 테스트 카페'), findsOneWidget);
    expect(find.text('성수 테스트 카페 추가'), findsOneWidget);
  });
}

class _NearbyPlaceService extends PlaceCandidateService {
  double? latitude;
  double? longitude;

  @override
  Future<PlaceCandidateResult> findCandidates({
    required double latitude,
    required double longitude,
  }) async {
    this.latitude = latitude;
    this.longitude = longitude;
    return const PlaceCandidateResult.success([
      PlaceCandidate(
        id: 'nearby-cafe',
        name: '성수 테스트 카페',
        address: '서울 성동구',
        source: 'test',
      ),
    ]);
  }
}
