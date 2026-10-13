import 'package:flutter_test/flutter_test.dart';
import 'package:localog/features/receipt_settlement/receipt_scan_result.dart';
import 'package:localog/features/receipt_settlement/receipt_text_parser.dart';

// Manually transcribed from the five supplied photos. Coordinates below are
// synthetic layout fixtures, NOT output from running ML Kit on those photos.
void main() {
  const parser = ReceiptTextParser();
  ReceiptTextLine line(
    String text,
    double y, {
    double x = 0,
    double width = 100,
  }) => ReceiptTextLine(
    text: text,
    left: x,
    right: x + width,
    top: y,
    bottom: y + 20,
  );

  test('사진 1~3: 같은 영수증 10개 품목과 88180원', () {
    final entries = [
      ('001 (프로글레이드) 질레트 퓨전 매뉴얼', '250394 11,390 4 45,560'),
      ('002 라운드랩 포 맨 1025 독도 올', '240507 11,010 1 11,010'),
      ('003 라운드랩 1025 독도 토너 대용', '240504 9,220 1 9,220'),
      ('004 라운드랩 포 맨 자작나무 쉐이빙', '250566 5,020 1 5,020'),
      ('005 닥터지 레드블레미쉬 모이스처 클렌', '170316 4,430 2 8,860'),
      ('006 빈츠초콜릿', '110988 2,010 1 2,010'),
      ('007 프링글스핫앤스파이시', '160006 1,280 1 1,280'),
      ('008 프링글스 스모키 바비큐러버스 피자', '240149 1,440 1 1,440'),
      ('009 휴족시간 지압자극시트', '180239 2,510 1 2,510'),
      ('010 맥심 티오피 스위트아메리카노', '170270 1,270 1 1,270'),
    ];
    final result = parser.parse([
      line('마트코드 3440400', 0),
      line('상 품 단 가 수 량 금 액', 40),
      for (var i = 0; i < entries.length; i++) ...[
        line(entries[i].$1, 80 + i * 60),
        line(entries[i].$2, 110 + i * 60),
      ],
      line('합 계 88,180원', 700),
      line('받은금액 88,180원', 740),
    ]);
    expect(result.items, hasLength(10));
    expect(result.items.map((item) => item.quantity), [
      4,
      1,
      1,
      1,
      2,
      1,
      1,
      1,
      1,
      1,
    ]);
    expect(result.items.map((item) => item.amount), [
      45560,
      11010,
      9220,
      5020,
      8860,
      2010,
      1280,
      1440,
      2510,
      1270,
    ]);
    expect(result.itemSum, 88180);
    expect(result.totalAmount, 88180);
  });

  test('사진 4: 옵션을 별도 품목으로 청구하지 않는다', () {
    final result = parser.parse([
      line('상품명 단가 수량 금액', 0),
      // First product name abbreviated because the leading modifier is unclear.
      line('01.싸이버거 세트', 40), line('10,700 1 10,700', 70),
      line('-(변경)-펩시콜라제로', 100),
      line('02.후라이드통다리 6,000 1 6,000', 130),
      line('03.배달비 3,000 1 3,000', 170),
      line('매출합계 19,700', 210), line('받은금액 19,700', 250),
      line('교환번호 S047', 290),
    ]);
    expect(result.items.map((item) => item.amount), [10700, 6000, 3000]);
    expect(result.totalAmount, 19700);
    expect(result.hasTotalMismatch, isFalse);
  });

  test('사진 5: 비어 있는 단가와 부가세·결제수단·포인트 중복', () {
    final result = parser.parse([
      line('성인 18,000원 (1명)', 0),
      line('제품명', 40),
      line('단가', 40, x: 300),
      line('수량', 40, x: 450),
      line('금액', 40, x: 600),
      line('영화티켓', 80),
      line('1', 80, x: 450),
      line('18,000', 80, x: 600),
      line('할 인', 120),
      line('0', 120, x: 600),
      line('합 계', 160),
      line('18,000(VAT:1,597)', 160, x: 500),
      line('네이버페이 18,000', 200),
      line('VIP승급액 18,000', 240),
    ]);
    expect(result.items, hasLength(1));
    expect(result.items.single.name, '영화티켓');
    expect(result.items.single.quantity, 1);
    expect(result.items.single.amount, 18000);
    expect(result.totalAmount, 18000);
  });
}
