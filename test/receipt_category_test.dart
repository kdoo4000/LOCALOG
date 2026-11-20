import 'package:flutter_test/flutter_test.dart';
import 'package:localog/features/receipt_settlement/receipt_scan_result.dart';

void main() {
  test('총액 정산용 업소명을 추출하되 안내문을 상호로 사용하지 않는다', () {
    String? merchant(String raw) =>
        ReceiptScanResult(items: const [], rawText: raw).merchantName;
    expect(merchant('Easy Check\n마포식당 / 홍길동\n합계 9,500'), '마포식당');
    expect(merchant('메가박스 신촌(12345)\n합계 21,000'), '메가박스 신촌');
    expect(merchant('가맹점명 : 에이스 마트'), '에이스 마트');
    expect(merchant('가맹점명, 가맹점주소가 실제와 다른\n경우 신고안내\n합계 9,500'), isNull);
  });
  test('정확한 이름도 분류로 표시하고 원래 이름과 사용자 선택은 보존한다', () {
    const item = ReceiptItemDraft(
      id: '1',
      name: '국산콩나물 300g',
      quantity: 1,
      amount: 1500,
    );
    expect(item.displayCategory, ReceiptCategory.food);
    expect(item.name, '국산콩나물 300g');
    const edited = ReceiptItemDraft(
      id: '2',
      name: 'F헤드',
      quantity: 1,
      amount: 3000,
      category: ReceiptCategory.household,
    );
    expect(
      edited.copyWith(amount: 4000).displayCategory,
      ReceiptCategory.household,
    );
  });
  test('불분명한 품목이나 여러 분류 단서로 확정하지 않는다', () {
    expect(ReceiptCategory.suggest('F헤드'), ReceiptCategory.unknown);
    expect(ReceiptCategory.suggest('다이소'), ReceiptCategory.unknown);
    expect(ReceiptCategory.suggest('커피 세제'), ReceiptCategory.unknown);
    expect(
      ReceiptCategory.suggest('마포식당', wholeReceipt: true),
      ReceiptCategory.dining,
    );
    expect(
      ReceiptCategory.suggest('메가박스 신촌', wholeReceipt: true),
      ReceiptCategory.culture,
    );
    expect(ReceiptCategory.suggest('육우육회'), ReceiptCategory.food);
  });
}
