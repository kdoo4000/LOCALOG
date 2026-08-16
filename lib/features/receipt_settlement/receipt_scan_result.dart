class ReceiptItemDraft {
  const ReceiptItemDraft({
    required this.id,
    required this.name,
    required this.quantity,
    required this.amount,
    this.confidence,
  });
  final String id;
  final String name;
  final int quantity;
  final int amount;
  final double? confidence;

  ReceiptItemDraft copyWith({String? name, int? quantity, int? amount}) =>
      ReceiptItemDraft(
        id: id,
        name: name ?? this.name,
        quantity: quantity ?? this.quantity,
        amount: amount ?? this.amount,
        confidence: confidence,
      );
}

class ReceiptScanResult {
  const ReceiptScanResult({
    required this.items,
    required this.rawText,
    this.totalAmount,
  });
  final List<ReceiptItemDraft> items;
  final String rawText;
  final int? totalAmount;
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
  });
  final String text;
  final double top;
  final double left;
  final double right;
  final double bottom;
  final double? confidence;
}
