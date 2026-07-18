import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/features/route_search/presentation/region_picker_screen.dart';

void main() {
  testWidgets('selected region field renders every region as a chip', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RegionSelectionField(
            regions: const ['서울특별시 > 중구', '경기도 > 부천시'],
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.byType(Chip), findsNWidgets(2));
    expect(find.text('서울 중구'), findsOneWidget);
    expect(find.text('경기 부천시'), findsOneWidget);
  });

  testWidgets('shows selected regions as removable chips above two panes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RegionPickerScreen(initialRegions: ['서울특별시 > 중구', '경기도 > 부천시']),
      ),
    );

    expect(find.text('서울 중구'), findsOneWidget);
    expect(find.text('경기 부천시'), findsOneWidget);
    expect(find.text('서울'), findsOneWidget);
    expect(find.text('경기'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '다음'), findsOneWidget);
  });

  test('selects the region appearing in the most photo addresses', () {
    final region = inferMostFrequentRegion([
      '서울특별시 중구 세종대로 110',
      '부산광역시 해운대구 해운대해변로 264',
      '서울특별시 중구 을지로 12',
    ]);

    expect(region, '서울특별시 > 중구');
  });

  test('returns every distinct photo region with the majority first', () {
    final regions = inferRegionsFromAddresses([
      '부산광역시 해운대구 해운대해변로 264',
      '서울특별시 중구 세종대로 110',
      '부산광역시 해운대구 달맞이길 30',
      '제주특별자치도 제주시 첨단로 242',
      '서울특별시 중구 을지로 12',
    ]);

    expect(regions, ['부산광역시 > 해운대구', '서울특별시 > 중구', '제주특별자치도 > 제주시']);
  });

  test('maps former Gwangju and Jeonnam addresses to the integrated city', () {
    expect(inferMostFrequentRegion(['광주광역시 동구 문화전당로 38']), '전남광주통합특별시 > 동구');
    expect(inferMostFrequentRegion(['전라남도 여수시 시청로 1']), '전남광주통합특별시 > 여수시');
  });
}
