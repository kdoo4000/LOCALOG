import 'package:flutter_test/flutter_test.dart';
import 'package:localog/features/receipt_settlement/receipt_scan_result.dart';
import 'package:localog/features/receipt_settlement/receipt_text_parser.dart';

void main() {
  const parser = ReceiptTextParser();

  test('품목과 총액을 구분한다', () {
    final result = parser.parse(const [
      ReceiptTextLine(text: '해물칼국수 2개 24,000원', top: 10, left: 0),
      ReceiptTextLine(text: '막걸리 6,000', top: 20, left: 0),
      ReceiptTextLine(text: '부가세 2,727', top: 30, left: 0),
      ReceiptTextLine(text: '총 결제금액 30,000원', top: 40, left: 0),
    ]);
    expect(result.items, hasLength(2));
    expect(result.items.first.name, '해물칼국수');
    expect(result.items.first.quantity, 2);
    expect(result.items.first.amount, 24000);
    expect(result.totalAmount, 30000);
    expect(result.hasTotalMismatch, isFalse);
  });

  test('영수증 메타데이터를 품목으로 만들지 않는다', () {
    final result = parser.parse(const [
      ReceiptTextLine(text: '승인번호 12345678', top: 10, left: 0),
      ReceiptTextLine(text: '사업자번호 123-45-67890', top: 20, left: 0),
      ReceiptTextLine(text: '아메리카노 4,500', top: 30, left: 0),
    ]);
    expect(result.items, hasLength(1));
    expect(result.items.single.name, '아메리카노');
  });

  test('품목 합계와 영수증 총액 불일치를 표시한다', () {
    final result = parser.parse(const [
      ReceiptTextLine(text: '커피 4,500', top: 10, left: 0),
      ReceiptTextLine(text: '총금액 5,000', top: 20, left: 0),
    ]);
    expect(result.hasTotalMismatch, isTrue);
  });

  test('로똜시네마 영수증에서 영화티켓만 추출한다', () {
    final result = parser.parse(const [
      ReceiptTextLine(
        text: '313-87-00979',
        top: 20,
        left: 500,
        right: 700,
        bottom: 50,
      ),
      ReceiptTextLine(
        text: 'ARS 1544-8855',
        top: 60,
        left: 500,
        right: 700,
        bottom: 90,
      ),
      ReceiptTextLine(
        text: '영화관/기기: 3044/4004',
        top: 100,
        left: 380,
        right: 720,
        bottom: 130,
      ),
      ReceiptTextLine(
        text: '오디세이(2D4K)',
        top: 150,
        left: 20,
        right: 300,
        bottom: 190,
      ),
      ReceiptTextLine(text: '제품명', top: 300, left: 20, right: 150, bottom: 335),
      ReceiptTextLine(text: '수량', top: 285, left: 500, right: 570, bottom: 320),
      ReceiptTextLine(text: '금액', top: 275, left: 650, right: 720, bottom: 310),
      ReceiptTextLine(
        text: '영화티켓',
        top: 380,
        left: 20,
        right: 180,
        bottom: 420,
      ),
      ReceiptTextLine(text: '1', top: 360, left: 520, right: 540, bottom: 395),
      ReceiptTextLine(
        text: '18,000',
        top: 350,
        left: 640,
        right: 720,
        bottom: 385,
      ),
      ReceiptTextLine(
        text: '할 인 0',
        top: 450,
        left: 20,
        right: 720,
        bottom: 485,
      ),
      ReceiptTextLine(text: '합 계', top: 500, left: 20, right: 140, bottom: 535),
      ReceiptTextLine(
        text: '18,000(VAT:1,597)',
        top: 510,
        left: 500,
        right: 720,
        bottom: 545,
      ),
      ReceiptTextLine(
        text: '네이버페이 18,000',
        top: 600,
        left: 20,
        right: 720,
        bottom: 635,
      ),
      ReceiptTextLine(
        text: 'VIP승급액 18,000',
        top: 680,
        left: 20,
        right: 720,
        bottom: 715,
      ),
    ]);

    expect(result.items, hasLength(1));
    expect(result.items.single.name, '영화티켓');
    expect(result.items.single.quantity, 1);
    expect(result.items.single.amount, 18000);
    expect(result.totalAmount, 18000);
  });

  test('총액이 합계 라벨보다 먼저 인식돼도 할인을 품목으로 만들지 않는다', () {
    final result = parser.parse(const [
      ReceiptTextLine(text: '제품명', top: 10, left: 10, right: 100, bottom: 30),
      ReceiptTextLine(text: '영화티켓', top: 50, left: 10, right: 120, bottom: 75),
      ReceiptTextLine(text: '1', top: 50, left: 300, right: 320, bottom: 75),
      ReceiptTextLine(
        text: '18,000',
        top: 50,
        left: 500,
        right: 580,
        bottom: 75,
      ),
      ReceiptTextLine(text: '할 인', top: 90, left: 10, right: 100, bottom: 115),
      ReceiptTextLine(
        text: '18,000(VAT:1,597)',
        top: 130,
        left: 500,
        right: 680,
        bottom: 155,
      ),
      ReceiptTextLine(text: '합계', top: 170, left: 10, right: 100, bottom: 195),
    ]);

    expect(result.items, hasLength(1));
    expect(result.items.single.name, '영화티켓');
    expect(result.totalAmount, 18000);
  });

  test('서로 다른 열 배치에서 품목 합계가 총액과 맞는 행만 선택한다', () {
    final result = parser.parse(const [
      ReceiptTextLine(text: '상품명', top: 10, left: 20, right: 160, bottom: 40),
      ReceiptTextLine(text: '단가', top: 10, left: 350, right: 430, bottom: 40),
      ReceiptTextLine(text: '수량', top: 10, left: 480, right: 550, bottom: 40),
      ReceiptTextLine(text: '금액', top: 10, left: 620, right: 700, bottom: 40),
      ReceiptTextLine(
        text: '01.매직쪼싸이버거 세트',
        top: 70,
        left: 20,
        right: 300,
        bottom: 100,
      ),
      ReceiptTextLine(
        text: '10,700',
        top: 70,
        left: 350,
        right: 430,
        bottom: 100,
      ),
      ReceiptTextLine(text: '1', top: 70, left: 500, right: 520, bottom: 100),
      ReceiptTextLine(
        text: '10,700',
        top: 70,
        left: 620,
        right: 700,
        bottom: 100,
      ),
      ReceiptTextLine(
        text: '02.후라이드통다리 -(변경)-펩시콜라제로',
        top: 120,
        left: 20,
        right: 320,
        bottom: 150,
      ),
      ReceiptTextLine(
        text: '6,000',
        top: 120,
        left: 350,
        right: 430,
        bottom: 150,
      ),
      ReceiptTextLine(text: '1', top: 120, left: 500, right: 520, bottom: 150),
      ReceiptTextLine(
        text: '6,000',
        top: 120,
        left: 620,
        right: 700,
        bottom: 150,
      ),
      ReceiptTextLine(
        text: '03.배달비',
        top: 170,
        left: 20,
        right: 160,
        bottom: 200,
      ),
      ReceiptTextLine(
        text: '3,000',
        top: 170,
        left: 350,
        right: 430,
        bottom: 200,
      ),
      ReceiptTextLine(text: '1', top: 170, left: 500, right: 520, bottom: 200),
      ReceiptTextLine(
        text: '3,000',
        top: 170,
        left: 620,
        right: 700,
        bottom: 200,
      ),
      ReceiptTextLine(
        text: '매출합계',
        top: 240,
        left: 20,
        right: 160,
        bottom: 270,
      ),
      ReceiptTextLine(
        text: '19,700',
        top: 240,
        left: 620,
        right: 700,
        bottom: 270,
      ),
      ReceiptTextLine(
        text: '바온금액',
        top: 300,
        left: 20,
        right: 160,
        bottom: 330,
      ),
      ReceiptTextLine(
        text: '19,700',
        top: 300,
        left: 620,
        right: 700,
        bottom: 330,
      ),
      ReceiptTextLine(
        text: '교환번호 S047',
        top: 360,
        left: 20,
        right: 300,
        bottom: 390,
      ),
    ]);

    expect(result.items.map((item) => item.name), [
      '매직쪼싸이버거 세트',
      '후라이드통다리',
      '배달비',
    ]);
    expect(result.items.map((item) => item.amount), [10700, 6000, 3000]);
    expect(result.totalAmount, 19700);
    expect(result.hasTotalMismatch, isFalse);
  });

  test('품목명과 숫자 열이 두 행으로 나뉘 영수증을 산술식으로 검증한다', () {
    final result = parser.parse(const [
      ReceiptTextLine(text: '상 품 명', top: 10, left: 10, right: 180, bottom: 35),
      ReceiptTextLine(text: '단가', top: 10, left: 330, right: 400, bottom: 35),
      ReceiptTextLine(text: '수량', top: 10, left: 470, right: 530, bottom: 35),
      ReceiptTextLine(text: '금액', top: 10, left: 620, right: 690, bottom: 35),
      ReceiptTextLine(
        text: '001 (프로글레이드) 질레트 퓨전 매뉴얼',
        top: 60,
        left: 10,
        right: 500,
        bottom: 85,
      ),
      ReceiptTextLine(
        text: '250394',
        top: 100,
        left: 10,
        right: 110,
        bottom: 125,
      ),
      ReceiptTextLine(
        text: '11,390',
        top: 100,
        left: 330,
        right: 410,
        bottom: 125,
      ),
      ReceiptTextLine(text: '4', top: 100, left: 490, right: 510, bottom: 125),
      ReceiptTextLine(
        text: '45,560',
        top: 100,
        left: 620,
        right: 700,
        bottom: 125,
      ),
      ReceiptTextLine(
        text: '002 라운드랩 포멘 1025 독도 올',
        top: 150,
        left: 10,
        right: 500,
        bottom: 175,
      ),
      ReceiptTextLine(
        text: '240507',
        top: 190,
        left: 10,
        right: 110,
        bottom: 215,
      ),
      ReceiptTextLine(
        text: '11,010',
        top: 190,
        left: 330,
        right: 410,
        bottom: 215,
      ),
      ReceiptTextLine(text: '1', top: 190, left: 490, right: 510, bottom: 215),
      ReceiptTextLine(
        text: '11,010',
        top: 190,
        left: 620,
        right: 700,
        bottom: 215,
      ),
      ReceiptTextLine(
        text: '005 닥터지 레드블레이쉬 모이스쳐 클렌',
        top: 240,
        left: 10,
        right: 550,
        bottom: 265,
      ),
      ReceiptTextLine(
        text: '170316',
        top: 280,
        left: 10,
        right: 110,
        bottom: 305,
      ),
      ReceiptTextLine(
        text: '4,430',
        top: 280,
        left: 330,
        right: 410,
        bottom: 305,
      ),
      ReceiptTextLine(text: '2', top: 280, left: 490, right: 510, bottom: 305),
      ReceiptTextLine(
        text: '8,860',
        top: 280,
        left: 620,
        right: 700,
        bottom: 305,
      ),
      ReceiptTextLine(text: '합 계', top: 350, left: 10, right: 120, bottom: 375),
      ReceiptTextLine(
        text: '65,430원',
        top: 350,
        left: 620,
        right: 720,
        bottom: 375,
      ),
    ]);

    expect(result.items.map((item) => item.name), [
      '(프로글레이드) 질레트 퓨전 매뉴얼',
      '라운드랩 포멘 1025 독도 올',
      '닥터지 레드블레이쉬 모이스쳐 클렌',
    ]);
    expect(result.items.map((item) => item.quantity), [4, 1, 2]);
    expect(result.items.map((item) => item.amount), [45560, 11010, 8860]);
    expect(result.totalAmount, 65430);
    expect(result.hasTotalMismatch, isFalse);
  });

  test('OCR이 천 단위 구분자와 합계 라벨을 손상해도 복원한다', () {
    final result = parser.parse(const [
      ReceiptTextLine(text: '상품', top: 10, left: 10, right: 120, bottom: 35),
      ReceiptTextLine(
        text: '단가 수량',
        top: 10,
        left: 330,
        right: 530,
        bottom: 35,
      ),
      ReceiptTextLine(text: '금액', top: 10, left: 620, right: 700, bottom: 35),
      ReceiptTextLine(
        text: '001 질레트 퓨전 매뉴얼',
        top: 60,
        left: 10,
        right: 400,
        bottom: 85,
      ),
      ReceiptTextLine(
        text: '250394',
        top: 100,
        left: 10,
        right: 110,
        bottom: 125,
      ),
      ReceiptTextLine(
        text: 'l1,390',
        top: 100,
        left: 330,
        right: 410,
        bottom: 125,
      ),
      ReceiptTextLine(text: '4', top: 100, left: 490, right: 510, bottom: 125),
      ReceiptTextLine(
        text: '45,560',
        top: 100,
        left: 620,
        right: 700,
        bottom: 125,
      ),
      ReceiptTextLine(
        text: '002 라운드랩 독도 올',
        top: 150,
        left: 10,
        right: 400,
        bottom: 175,
      ),
      ReceiptTextLine(
        text: '240507',
        top: 190,
        left: 10,
        right: 110,
        bottom: 215,
      ),
      ReceiptTextLine(
        text: '11.010',
        top: 190,
        left: 330,
        right: 410,
        bottom: 215,
      ),
      ReceiptTextLine(text: '1', top: 190, left: 490, right: 510, bottom: 215),
      ReceiptTextLine(
        text: '11,010',
        top: 190,
        left: 620,
        right: 700,
        bottom: 215,
      ),
      ReceiptTextLine(text: '합', top: 260, left: 10, right: 80, bottom: 285),
      ReceiptTextLine(
        text: '56, 57091',
        top: 260,
        left: 610,
        right: 720,
        bottom: 285,
      ),
    ]);

    expect(result.items.map((item) => item.amount), [45560, 11010]);
    expect(result.totalAmount, 56570);
    expect(result.hasTotalMismatch, isFalse);
  });
}
