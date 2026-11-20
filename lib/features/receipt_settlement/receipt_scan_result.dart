enum ReceiptCategory {
  food('식료품'),
  dining('식사'),
  drinks('음료·간식'),
  household('생활용품'),
  beauty('뷰티·위생'),
  culture('영화·문화'),
  transport('교통·배송'),
  discount('할인'),
  unknown('미분류');

  const ReceiptCategory(this.label);
  final String label;

  static ReceiptCategory suggest(String name, {bool wholeReceipt = false}) {
    final text = name.replaceAll(RegExp(r'\s+'), '');
    final matches = <ReceiptCategory>{};
    final rules = <ReceiptCategory, String>{
      food: '콩나물|육회|정육|채소|과일|두부|계란',
      dining: '버거|치킨|피자|볶음밥|국밥',
      drinks: '커피|아메리카노|콜라|초콜릿|프링글스|생수',
      household: '샤워기|수세미|세제|봉투|휴지',
      beauty: '토너|쉐이빙|면도|클렌|모이스처|지압|질레트',
      culture: '영화|티켓',
      transport: '배달비|배송비|택시|버스|지하철',
      discount: '할인|쿠폰',
    };
    for (final rule in rules.entries) {
      if (RegExp(rule.value).hasMatch(text)) matches.add(rule.key);
    }
    if (wholeReceipt) {
      // Only merchant context, not footer offers or tax/discount information.
      if (RegExp('식당|음식점').hasMatch(text)) matches.add(dining);
      if (RegExp('메가박스|시네마').hasMatch(text)) matches.add(culture);
    }
    return matches.length == 1 ? matches.single : unknown;
  }
}

class ReceiptItemDraft {
  const ReceiptItemDraft({
    required this.id,
    required this.name,
    required this.quantity,
    required this.amount,
    this.confidence,
    this.category,
    this.isReceiptTotal = false,
  });
  final String id;
  final String name;
  final int quantity;
  final int amount;
  final double? confidence;
  final ReceiptCategory? category;
  final bool isReceiptTotal;
  ReceiptCategory get displayCategory =>
      category ?? ReceiptCategory.suggest(name);

  ReceiptItemDraft copyWith({String? name, int? quantity, int? amount}) =>
      ReceiptItemDraft(
        id: id,
        name: name ?? this.name,
        quantity: quantity ?? this.quantity,
        amount: amount ?? this.amount,
        confidence: confidence,
        category: category,
        isReceiptTotal: isReceiptTotal,
      );
}

class ReceiptScanResult {
  const ReceiptScanResult({
    required this.items,
    required this.rawText,
    this.totalAmount,
    this.reviewNotes = const [],
  });
  final List<ReceiptItemDraft> items;
  final String rawText;
  final int? totalAmount;
  final List<String> reviewNotes;
  String? get merchantName {
    final lines = rawText.split('\n').map((line) => line.trim()).toList();
    for (final line in lines) {
      final labelled = RegExp(
        r'^(?:가맹점명|상호명?|매장명)\s*[:：]\s*(.+)$',
      ).firstMatch(line);
      if (labelled != null) return labelled.group(1)!.trim();
    }
    for (final line in lines.take(12)) {
      final name = line.split('/').first.split('(').first.trim();
      if (name.length > 40 || RegExp(r'\d|주소|전화|안내|할인|사업자').hasMatch(name)) {
        continue;
      }
      if (RegExp(
            r'^[가-힣A-Za-z ]+(?:식당|식담|마트|정육점|정육집|본점|지점|카페)$',
          ).hasMatch(name) ||
          RegExp(
            r'^(?:메가박스|롯데시네마|CGV)(?:\s|$)',
            caseSensitive: false,
          ).hasMatch(name) ||
          (line.contains('/') &&
              RegExp(r'^[가-힣A-Za-z ]+\s*/\s*[가-힣]{2,4}$').hasMatch(line))) {
        return name;
      }
    }
    return null;
  }

  int get itemSum => items.fold(0, (sum, item) => sum + item.amount);
  bool get hasTotalMismatch =>
      totalAmount != null && items.isNotEmpty && totalAmount != itemSum;
}

class ReceiptTextLine {
  const ReceiptTextLine({
    required this.text,
    required this.top,
    required this.left,
    this.right = 0,
    this.bottom = 0,
    this.confidence,
    this.words = const [],
    this.rotationRadians = 0,
  });
  final String text;
  final double top;
  final double left;
  final double right;
  final double bottom;
  final double? confidence;
  final List<ReceiptTextLine> words;
  final double rotationRadians;
}
