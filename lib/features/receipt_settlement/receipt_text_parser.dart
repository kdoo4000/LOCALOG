import 'receipt_scan_result.dart';

class ReceiptTextParser {
  const ReceiptTextParser();

  static final _amountPattern = RegExp(
    r'(?:₩\s*)?(-?\d{1,3}(?:,\d{3})+|-?\d{3,})(?:\s*원)?',
  );
  static final _quantityPattern = RegExp(
    r'(?:^|\s)(\d{1,2})\s*(?:개|ea)(?:\s|$)',
    caseSensitive: false,
  );
  static final _bareQuantityPattern = RegExp(r'\s(\d{1,2})\s+(?=(?:₩\s*)?\d)');
  static final _headerPattern = RegExp(r'상\s*품\s*명|제\s*품\s*명|품\s*목\s*명');
  static final _metadataPattern = RegExp(
    r'사업자|대표|주소|전화|tel|ars|www|승인|카드|부가세|과세|면세|공급가|거스름|현금|결제|할\s*인|일시|번호|영수증|상영관|기기|좌석|원산지|교환번호|네이버\s*페이|vip\s*승급|받.금액|받을\s*금액',
    caseSensitive: false,
  );
  static final _numberLikePattern = RegExp(
    r'\d{2,4}-\d{2,4}-\d{4,5}|\d{4}[-./]\d{1,2}[-./]\d{1,2}|\d{1,2}:\d{2}',
  );
  static final _optionSuffixPattern = RegExp(
    r'\s*-\s*\(?변경\)?\s*-.*$',
    caseSensitive: false,
  );

  ReceiptScanResult parse(List<ReceiptTextLine> source) {
    final lines = [...source]..sort((a, b) => a.top.compareTo(b.top));
    final rows = _mergeVisualRows(lines);
    final headerIndex = rows.indexWhere(
      (row) => _headerPattern.hasMatch(row.text),
    );
    final totalCandidates = _findTotals(rows);
    final total = totalCandidates.isEmpty
        ? null
        : (totalCandidates..sort((a, b) => b.score.compareTo(a.score))).first;
    final summaryIndex = total?.rowIndex ?? rows.length;

    final candidates = <_ItemCandidate>[];
    for (
      var index = headerIndex < 0 ? 0 : headerIndex + 1;
      index < summaryIndex;
      index++
    ) {
      final candidate = _itemCandidate(rows[index], index, headerIndex >= 0);
      if (candidate != null) candidates.add(candidate);
      if (index + 1 < summaryIndex) {
        final continued = _twoRowItemCandidate(
          rows[index],
          rows[index + 1],
          index,
          headerIndex >= 0,
        );
        if (continued != null) candidates.add(continued);
      }
    }

    final selected = total == null
        ? candidates
        : _selectItemsMatchingTotal(candidates, total.amount);
    final items = <ReceiptItemDraft>[
      for (var index = 0; index < selected.length; index++)
        ReceiptItemDraft(
          id: 'ocr-$index',
          name: selected[index].name,
          quantity: selected[index].quantity,
          amount: selected[index].amount,
          confidence: selected[index].confidence,
        ),
    ];

    return ReceiptScanResult(
      items: items,
      totalAmount: total?.amount,
      rawText: lines.map((line) => line.text).join('\n'),
    );
  }

  List<_TotalCandidate> _findTotals(List<_ReceiptVisualRow> rows) {
    final totals = <_TotalCandidate>[];
    for (var index = 0; index < rows.length; index++) {
      final text = _normalize(rows[index].text);
      final score = _totalLabelScore(text);
      if (score == 0) continue;
      final ownAmount = _summaryAmount(text);
      if (ownAmount != null) {
        totals.add(_TotalCandidate(ownAmount.$1.abs(), index, score));
        continue;
      }
      for (var distance = 1; distance <= 2; distance++) {
        final nearbyIndexes = [index - distance, index + distance];
        final nearbyAmount = nearbyIndexes
            .where((candidate) => candidate >= 0 && candidate < rows.length)
            .map(
              (candidate) => _summaryAmount(_normalize(rows[candidate].text)),
            )
            .whereType<(int, RegExpMatch)>()
            .firstOrNull;
        if (nearbyAmount != null) {
          totals.add(
            _TotalCandidate(nearbyAmount.$1.abs(), index, score - distance),
          );
          break;
        }
      }
    }
    return totals;
  }

  int _totalLabelScore(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), '');
    if (compact.contains('매출합계') ||
        compact.contains('총결제금액') ||
        compact.contains('총합계')) {
      return 100;
    }
    if (compact.contains('합계') || compact.contains('총금액')) return 90;
    if (compact == '합' ||
        compact == '계' ||
        RegExp(r'^[합계](?:\s|$)').hasMatch(text)) {
      return 80;
    }
    if (RegExp(r'받.금액|받을금액').hasMatch(compact)) return 50;
    return 0;
  }

  _ItemCandidate? _itemCandidate(
    _ReceiptVisualRow row,
    int rowIndex,
    bool followsHeader,
  ) {
    final text = _normalize(row.text);
    if (text.isEmpty ||
        _headerPattern.hasMatch(text) ||
        _metadataPattern.hasMatch(text) ||
        _numberLikePattern.hasMatch(text) ||
        _totalLabelScore(text) > 0) {
      return null;
    }
    final amountData = _rightmostAmount(text);
    if (amountData == null || amountData.$1.abs() < 1000) return null;

    final quantityMatch =
        _quantityPattern.firstMatch(text) ??
        _bareQuantityPattern.firstMatch(text);
    final quantity = int.tryParse(quantityMatch?.group(1) ?? '') ?? 1;
    final firstAmount = _amountPattern.firstMatch(text);
    final nameEnd = firstAmount?.start ?? amountData.$2.start;
    var nameText = text.substring(0, nameEnd);
    if (quantityMatch != null && quantityMatch.start < nameText.length) {
      nameText = nameText.replaceRange(
        quantityMatch.start.clamp(0, nameText.length),
        quantityMatch.end.clamp(0, nameText.length),
        ' ',
      );
    }
    final name = _cleanName(nameText);
    if (name.length < 2 || !RegExp(r'[A-Za-z가-힣]').hasMatch(name)) return null;

    var score = 2;
    if (amountData.$2.group(0)?.contains(',') ?? false) score += 2;
    if (quantityMatch != null) score += 2;
    if (_matchesUnitQuantityTotal(text, quantity)) score += 4;
    if (followsHeader) score += 2;
    if (RegExp(r'^\d{1,3}[.)]').hasMatch(text)) score += 1;
    return _ItemCandidate(
      name: name,
      quantity: quantity,
      amount: amountData.$1.abs(),
      score: score,
      rowIndex: rowIndex,
      confidence: row.confidence,
    );
  }

  _ItemCandidate? _twoRowItemCandidate(
    _ReceiptVisualRow nameRow,
    _ReceiptVisualRow detailRow,
    int rowIndex,
    bool followsHeader,
  ) {
    final nameText = _normalize(nameRow.text);
    final detailText = _normalize(detailRow.text);
    if (_isExcludedItemText(nameText) ||
        _isExcludedItemText(detailText) ||
        !RegExp(r'[A-Za-z가-힣]').hasMatch(nameText) ||
        RegExp(r'[A-Za-z가-힣]').hasMatch(detailText)) {
      return null;
    }
    final amountData = _rightmostAmount(detailText);
    if (amountData == null || amountData.$1.abs() < 1000) return null;

    final quantityMatch =
        _quantityPattern.firstMatch(detailText) ??
        _bareQuantityPattern.firstMatch(detailText);
    final quantity = int.tryParse(quantityMatch?.group(1) ?? '') ?? 1;
    if (!_matchesUnitQuantityTotal(detailText, quantity)) return null;
    final name = _cleanName(nameText);
    if (name.length < 2) return null;

    var score = followsHeader ? 6 : 4;
    score += 6;
    if (RegExp(r'^\d{1,3}[.)]?\s*').hasMatch(nameText)) score += 2;
    return _ItemCandidate(
      name: name,
      quantity: quantity,
      amount: amountData.$1.abs(),
      score: score,
      rowIndex: rowIndex,
      confidence: _averageConfidence(nameRow.confidence, detailRow.confidence),
    );
  }

  bool _isExcludedItemText(String text) =>
      text.isEmpty ||
      _headerPattern.hasMatch(text) ||
      _metadataPattern.hasMatch(text) ||
      _numberLikePattern.hasMatch(text) ||
      _totalLabelScore(text) > 0;

  bool _matchesUnitQuantityTotal(String text, int quantity) {
    if (quantity <= 0) return false;
    final amounts = _amountValues(text);
    if (amounts.length < 2) return false;
    final total = amounts.last.abs();
    return amounts
        .take(amounts.length - 1)
        .any((unit) => unit.abs() * quantity == total);
  }

  String _cleanName(String value) => value
      .replaceAll(_optionSuffixPattern, '')
      .replaceAll(RegExp(r'^\s*\d{1,3}[.)\-]?\s*'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  double? _averageConfidence(double? first, double? second) {
    if (first == null) return second;
    if (second == null) return first;
    return (first + second) / 2;
  }

  List<_ItemCandidate> _selectItemsMatchingTotal(
    List<_ItemCandidate> candidates,
    int total,
  ) {
    final eligible = candidates
        .where((candidate) => candidate.amount <= total)
        .take(32)
        .toList();
    var states = <int, _CandidateSelection>{
      0: const _CandidateSelection([], 0),
    };
    for (var index = 0; index < eligible.length; index++) {
      final candidate = eligible[index];
      final additions = <int, _CandidateSelection>{};
      for (final entry in states.entries) {
        final sum = entry.key + candidate.amount;
        if (sum > total) continue;
        final selection = _CandidateSelection([
          ...entry.value.indexes,
          index,
        ], entry.value.score + candidate.score);
        final current = states[sum] ?? additions[sum];
        if (current == null || selection.score > current.score) {
          additions[sum] = selection;
        }
      }
      states = {...states, ...additions};
      if (states.length > 20000) {
        final entries = states.entries.toList()
          ..sort((a, b) {
            final distance = (total - a.key).compareTo(total - b.key);
            return distance != 0
                ? distance
                : b.value.score.compareTo(a.value.score);
          });
        states = Map.fromEntries(entries.take(10000));
      }
    }
    final exact = states[total];
    if (exact == null || exact.indexes.isEmpty) return candidates;
    return [for (final index in exact.indexes) eligible[index]]
      ..sort((a, b) => a.rowIndex.compareTo(b.rowIndex));
  }

  (int, RegExpMatch)? _rightmostAmount(String text) {
    final matches = _amountPattern.allMatches(text).toList();
    if (matches.isEmpty) return null;
    final match = matches.last;
    return (_parseAmount(match.group(1)) ?? 0, match);
  }

  (int, RegExpMatch)? _summaryAmount(String text) {
    final vatIndex = text.toLowerCase().indexOf('vat');
    final amountText = vatIndex < 0 ? text : text.substring(0, vatIndex);
    return _rightmostAmount(amountText);
  }

  List<int> _amountValues(String text) => _amountPattern
      .allMatches(text)
      .map((match) => _parseAmount(match.group(1)))
      .whereType<int>()
      .toList();

  List<_ReceiptVisualRow> _mergeVisualRows(List<ReceiptTextLine> lines) {
    final rows = <_ReceiptVisualRow>[];
    for (final line in lines) {
      final height = line.bottom > line.top ? line.bottom - line.top : 1.0;
      final center = line.bottom > line.top
          ? (line.top + line.bottom) / 2
          : line.top;
      _ReceiptVisualRow? target;
      for (final row in rows.reversed) {
        final tolerance = (height > row.height ? height : row.height) * .85;
        if ((center - row.center).abs() <= tolerance) {
          target = row;
          break;
        }
        if (center - row.center > tolerance) break;
      }
      target == null ? rows.add(_ReceiptVisualRow(line)) : target.add(line);
    }
    rows.sort((a, b) => a.center.compareTo(b.center));
    return rows;
  }

  String _normalize(String value) {
    var normalized = value
        .replaceAll('\u00A0', ' ')
        .replaceAll('|', ' ')
        .replaceAllMapped(
          RegExp(r'(^|\s)[lLI](?=[.,]?\d)'),
          (match) => '${match.group(1)}1',
        )
        .replaceAll(RegExp(r',\s+(?=\d)'), ',')
        .replaceAllMapped(
          RegExp(r'(\d)\.(?=\d{3}(?:\D|$))'),
          (match) => '${match.group(1)},',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return normalized;
  }

  int? _parseAmount(String? value) => value == null
      ? null
      : int.tryParse(value.replaceAll(',', '').replaceAll(' ', ''));
}

class _ReceiptVisualRow {
  _ReceiptVisualRow(ReceiptTextLine line) {
    add(line);
  }

  final List<ReceiptTextLine> _lines = [];

  void add(ReceiptTextLine line) {
    _lines.add(line);
    _lines.sort((a, b) => a.left.compareTo(b.left));
  }

  double get center =>
      _lines
          .map(
            (line) => line.bottom > line.top
                ? (line.top + line.bottom) / 2
                : line.top,
          )
          .reduce((a, b) => a + b) /
      _lines.length;

  double get height => _lines
      .map((line) => line.bottom > line.top ? line.bottom - line.top : 1.0)
      .reduce((a, b) => a > b ? a : b);

  String get text => _lines.map((line) => line.text).join(' ');

  double? get confidence {
    final values = _lines
        .map((line) => line.confidence)
        .whereType<double>()
        .toList();
    return values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;
  }
}

class _ItemCandidate {
  const _ItemCandidate({
    required this.name,
    required this.quantity,
    required this.amount,
    required this.score,
    required this.rowIndex,
    required this.confidence,
  });
  final String name;
  final int quantity;
  final int amount;
  final int score;
  final int rowIndex;
  final double? confidence;
}

class _TotalCandidate {
  const _TotalCandidate(this.amount, this.rowIndex, this.score);
  final int amount;
  final int rowIndex;
  final int score;
}

class _CandidateSelection {
  const _CandidateSelection(this.indexes, this.score);
  final List<int> indexes;
  final int score;
}
