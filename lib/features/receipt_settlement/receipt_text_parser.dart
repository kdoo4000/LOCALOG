import 'dart:math' as math;

import 'receipt_scan_result.dart';

class ReceiptTextParser {
  const ReceiptTextParser();

  ReceiptScanResult reconcile(List<List<ReceiptTextLine>> readings) {
    final original = parse(readings.first);
    if (readings.length < 2) return original;
    final scans = readings.map(_visualRows).toList();
    final groups = <_ReceiptCandidateGroup>[];
    final totals =
        <
          ({
            int value,
            int pass,
            bool repaired,
            bool damaged,
            String raw,
            bool target,
          })
        >[];
    final scores = [
      for (final rows in scans)
        for (final row in rows) _totalLabelScore(_normalize(row.text)),
    ];
    final highest = scores.fold(0, (a, b) => a > b ? a : b);
    for (var pass = 0; pass < scans.length; pass++) {
      final rows = scans[pass];
      _parseRows(
        rows,
        recoverQuantity: true,
        collect: (item, row) {
          final nearby = groups
              .where(
                (g) =>
                    (g.center - row.center).abs() <=
                    (g.height > row.height ? g.height : row.height) * .8,
              )
              .toList();
          if (nearby.length > 1) {
            // An ambiguous spatial match must not silently collapse two items.
            groups.add(_ReceiptCandidateGroup(row.center, row.height));
            return;
          }
          final group = nearby.isEmpty
              ? _ReceiptCandidateGroup(row.center, row.height)
              : nearby.single;
          if (nearby.isEmpty) groups.add(group);
          if (item != null) {
            group.choices.putIfAbsent(
              '${item.quantity}:${item.amount}',
              () => item,
            );
          }
        },
      );
      for (var i = 0; i < rows.length; i++) {
        var text = _normalize(rows[i].text);
        final score = _totalLabelScore(text);
        final target = highest > 0 && score == highest;
        // Received money corroborates a total, but cannot define one: it may
        // include cash change. Lower-priority subtotals cannot override payment.
        if (!target && !RegExp(r'^받.\s*금액').hasMatch(text)) continue;
        if (target &&
            !_hasNumericToken(text) &&
            i + 1 < rows.length &&
            rows[i + 1].center - rows[i].center <= rows[i].height * 2) {
          text = '$text ${_normalize(rows[i + 1].text)}';
        }
        text = text.split(RegExp(r'\(?VAT', caseSensitive: false)).first.trim();
        final match = RegExp(
          r'(?:^|\s|:)(\d[\d,. ]*(?:원|S1)?)$',
        ).firstMatch(text);
        if (match == null) continue;
        final raw = match.group(1)!.replaceAll(' ', '');
        final exact = _money(raw);
        if (exact != null) {
          totals.add((
            value: exact,
            pass: pass,
            repaired: false,
            damaged: false,
            raw: raw,
            target: target,
          ));
        }
        // Only known won-glyph confusions at the end of a summary amount are
        // proposed. Never trim item prices or invent digits to match a sum.
        for (final suffix in ['S1', '91', '1']) {
          if (!raw.endsWith(suffix) || raw.length <= suffix.length + 2) {
            continue;
          }
          final value = _money(raw.substring(0, raw.length - suffix.length));
          if (value != null) {
            totals.add((
              value: value,
              pass: pass,
              repaired: true,
              damaged: exact == null,
              raw: raw,
              target: target,
            ));
          }
        }
      }
    }
    final exactSupport = <int, Set<int>>{};
    for (final evidence in totals.where((t) => t.target && !t.repaired)) {
      (exactSupport[evidence.value] ??= {}).add(evidence.pass);
    }
    final repeatedExact = exactSupport.entries
        .where((e) => e.value.length >= 2)
        .map((e) => e.key)
        .toSet();
    final allowedTotals = <int>{};
    for (final evidence in totals.where((t) => t.target)) {
      if (repeatedExact.isNotEmpty && !repeatedExact.contains(evidence.value)) {
        continue;
      }
      if (!evidence.repaired ||
          totals.any(
            (other) =>
                other.pass != evidence.pass &&
                (evidence.damaged || other.raw != evidence.raw) &&
                _oneDigitApart(evidence.value, other.value),
          )) {
        allowedTotals.add(evidence.value);
      }
    }
    groups.sort((a, b) => a.center.compareTo(b.center));
    if (allowedTotals.isEmpty ||
        groups.isEmpty ||
        groups.any((g) => g.choices.isEmpty)) {
      if (original.items.isEmpty && repeatedExact.length == 1) {
        return ReceiptScanResult(
          items: original.items,
          totalAmount: repeatedExact.single,
          rawText: original.rawText,
          reviewNotes: original.reviewNotes,
        );
      }
      return original;
    }
    // ponytail: bounded exhaustive search preserves ambiguity and discounts;
    // use a sum-indexed solver if receipts exceed 4096 candidate combinations.
    var combinations = 1;
    for (final group in groups) {
      combinations *= group.choices.length;
      if (combinations > 4096 || groups.length > 120) return original;
    }
    final solutions = <List<ReceiptItemDraft>>[];
    void search(int index, int sum, List<ReceiptItemDraft> chosen) {
      if (solutions.length > 1) return;
      if (index == groups.length) {
        if (allowedTotals.contains(sum)) solutions.add([...chosen]);
        return;
      }
      for (final item in groups[index].choices.values) {
        chosen.add(item);
        search(index + 1, sum + item.amount, chosen);
        chosen.removeLast();
      }
    }

    search(0, 0, []);
    if (solutions.length != 1 ||
        solutions.single.length < original.items.length) {
      return original;
    }
    final items = [
      for (var i = 0; i < solutions.single.length; i++)
        ReceiptItemDraft(
          id: 'ocr-$i',
          name: solutions.single[i].name,
          quantity: solutions.single[i].quantity,
          amount: solutions.single[i].amount,
          confidence: solutions.single[i].confidence,
        ),
    ];
    return ReceiptScanResult(
      items: items,
      totalAmount: items.fold<int>(0, (sum, item) => sum + item.amount),
      rawText: original.rawText,
      reviewNotes: [
        ...original.reviewNotes,
        '여러 인식 결과와 품목 계산을 비교해 금액을 보정했어요. 원본을 확인해 주세요.',
      ],
    );
  }

  bool _oneDigitApart(int a, int b) {
    final x = '$a', y = '$b';
    if (x.length != y.length || x.length < 3) return a == b;
    var different = 0;
    for (var i = 0; i < x.length; i++) {
      if (x[i] != y[i]) different++;
    }
    return different <= 1;
  }

  static final _number = RegExp(r'^-?(?:\d{1,3}(?:,\d{3})+|\d+)$');
  static final _headerPattern = RegExp(
    r'상\s*품\s*명|제\s*품\s*명|품\s*목\s*명|^상\s*품(?:\s|$)',
  );
  static final _metadataPattern = RegExp(
    r'사업자|대표|주소|전화|tel|ars|www|승인|카드|부가세|과세|면세|공급가|거스름|현금|결제|일시|번호|영수증|상영관|기기|좌석|원산지|교환번호|네이버\s*페이|vip\s*승급|받.금액|받을\s*금액|소\s*계|포인트',
    caseSensitive: false,
  );
  static final _numberLikePattern = RegExp(
    r'\d{2,4}-\d{2,4}-\d{4,5}|\d{4}[-./]\d{1,2}[-./]\d{1,2}|\d{1,2}:\d{2}',
  );
  static final _optionSuffixPattern = RegExp(r'\s*-\s*\(?변경\)?\s*-.*$');

  ReceiptScanResult parse(List<ReceiptTextLine> source) =>
      _parseRows(_visualRows(source));

  List<_ReceiptVisualRow> _visualRows(List<ReceiptTextLine> source) {
    // Project word centres onto a common baseline before grouping. Image-space
    // y alone pairs a slanted row's amount with the next product's name.
    final slopes = <double>[];
    for (final line in source) {
      if (line.words.length < 3 ||
          _excluded(line.text) ||
          !RegExp(r'[가-힣]').hasMatch(line.text)) {
        continue;
      }
      final words = [...line.words]..sort((a, b) => a.left.compareTo(b.left));
      final first = words.first;
      final last = words.last;
      final dx = (last.left + last.right - first.left - first.right) / 2;
      if (dx < 100) continue;
      final slope =
          (last.top + last.bottom - first.top - first.bottom) / 2 / dx;
      if (slope.abs() < .3) slopes.add(slope);
    }
    slopes.sort();
    final headers = source.where((line) => _headerPattern.hasMatch(line.text));
    final headerSlopes =
        headers
            .map((line) => math.tan(line.rotationRadians))
            .where((value) => value.abs() > .01 && value.abs() < .3)
            .toList()
          ..sort();
    // The table can lean differently from the payment/footer on curled paper.
    final slope = headerSlopes.isNotEmpty
        ? headerSlopes[headerSlopes.length ~/ 2]
        : slopes.isEmpty
        ? 0.0
        : slopes[slopes.length ~/ 2];
    final lines = <ReceiptTextLine>[];
    for (final line in source) {
      final words = line.words.isEmpty ? [line] : line.words;
      final baseline =
          words
              .map(
                (word) =>
                    (word.top + word.bottom) / 2 -
                    slope * (word.left + word.right) / 2,
              )
              .reduce((a, b) => a + b) /
          words.length;
      // ML Kit's words in one native line stay together, even if individual
      // glyph boxes have different heights (for example "4." and "430").
      for (final word in words) {
        final height = word.bottom > word.top ? word.bottom - word.top : 0.0;
        final center = height == 0 ? word.top : baseline;
        lines.add(
          ReceiptTextLine(
            text: word.text,
            left: word.left,
            right: word.right,
            top: center - height / 2,
            bottom: center + height / 2,
            confidence: word.confidence,
          ),
        );
      }
    }
    lines.sort(
      (a, b) => ((a.top + a.bottom) / 2).compareTo((b.top + b.bottom) / 2),
    );
    return _mergeVisualRows(
      lines,
      source.any((line) => line.words.isNotEmpty) ? .6 : .85,
    );
  }

  ReceiptScanResult _parseRows(
    List<_ReceiptVisualRow> rows, {
    bool recoverQuantity = false,
    void Function(ReceiptItemDraft?, _ReceiptVisualRow)? collect,
  }) {
    final headerIndex = rows.indexWhere(
      (row) => _headerPattern.hasMatch(row.text),
    );
    var columns = headerIndex < 0
        ? <String>[]
        : RegExp(r'단\s*가|수\s*량|금\s*액')
              .allMatches(rows[headerIndex].text)
              .map((m) => m.group(0)!.replaceAll(RegExp(r'\s'), ''))
              .toList();
    // Native OCR can split the product-name and numeric header into two rows.
    // Still preserve the requirement for an explicit quantity in that table.
    if (headerIndex >= 0 && columns.isEmpty && headerIndex > 0) {
      final previous = rows[headerIndex - 1];
      if (rows[headerIndex].center - previous.center <= previous.height * 2) {
        columns = RegExp(r'단\s*가|수\s*량|금\s*액')
            .allMatches(previous.text)
            .map((m) => m.group(0)!.replaceAll(RegExp(r'\s'), ''))
            .toList();
      }
    }
    final totals = <(int, int)>[];
    final notes = <String>[];
    var highestTotalScore = 0;
    var summaryIndex = rows.length;
    for (var i = 0; i < rows.length; i++) {
      final text = _normalize(rows[i].text);
      final score = _totalLabelScore(text);
      if (score == 0) continue;
      if (score > highestTotalScore) {
        highestTotalScore = score;
        summaryIndex = i;
      }
      var amount = _summaryAmount(text);
      if (amount == null) {
        final verified = _taxVerifiedTotal(text, rows);
        if (verified != null) {
          amount = verified;
          notes.add('세전 금액과 부가세를 대조한 금액이에요. 원본을 확인해 주세요.');
        }
      }
      // Only an adjacent amount-only row may belong to a detached total label.
      if (amount == null && !_hasNumericToken(text)) {
        final nearby = <int>[];
        for (final j in [i - 1, i + 1]) {
          if (j < 0 || j >= rows.length) continue;
          final candidate = _normalize(rows[j].text);
          if ((rows[j].center - rows[i].center).abs() > rows[i].height * 2) {
            continue;
          }
          // A preceding price is not evidence of a total. VAT is an explicit
          // summary marker; otherwise only a following detached amount is used.
          if (j < i &&
              !RegExp(r'VAT', caseSensitive: false).hasMatch(candidate)) {
            continue;
          }
          final withoutVat = candidate
              .split(RegExp(r'\(?VAT', caseSensitive: false))
              .first
              .trim();
          final value = _money(withoutVat);
          if (value != null) nearby.add(value);
        }
        if (nearby.toSet().length == 1) amount = nearby.first;
      }
      if (amount != null && amount >= 0) {
        totals.add((score, amount));
      } else {
        notes.add('총액을 확정하지 못했어요: ${rows[i].text}');
      }
    }
    totals.sort((a, b) => b.$1.compareTo(a.$1));
    final bestTotals = totals.isEmpty
        ? <int>{}
        : totals
              .where((t) => t.$1 == highestTotalScore)
              .map((t) => t.$2)
              .toSet();
    if (bestTotals.length > 1) notes.add('서로 다른 총액이 인식됐어요. 최종 결제 금액을 확인해 주세요.');
    final items = <ReceiptItemDraft>[];
    for (var i = headerIndex < 0 ? 0 : headerIndex + 1; i < summaryIndex; i++) {
      final nameRow = rows[i];
      final text = _normalize(
        headerIndex < 0
            ? rows[i].text
            : _columnText(
                rows[i],
                rows[headerIndex],
                recoverQuantity: recoverQuantity,
              ),
      );
      final originalText = rows[i].text;
      var item = _item(text, columns, rows[i].confidence, items.length);
      if (item == null &&
          !_excluded(text) &&
          !_endsInNumber(text) &&
          RegExp(r'[A-Za-z가-힣]').hasMatch(text) &&
          i + 1 < summaryIndex) {
        final detail = _normalize(rows[i + 1].text);
        var tokens = detail.split(' ');
        // A code/unit/amount row with an empty quantity cell is a candidate,
        // not a confirmed item. Only reconciliation may use this calculation.
        if (recoverQuantity &&
            columns.join(',') == '단가,수량,금액' &&
            tokens.length == 3 &&
            RegExp(r'^\d{6,}$').hasMatch(tokens.first)) {
          final unit = _money(tokens[1]);
          final amount = _money(tokens[2]);
          if (unit != null &&
              unit > 0 &&
              amount != null &&
              amount > 0 &&
              amount % unit == 0 &&
              amount ~/ unit <= 99) {
            tokens = [tokens[1], '${amount ~/ unit}', tokens[2]];
          }
        }
        // Product code followed by unit price, quantity and line amount.
        if (tokens.length == 4 && tokens.every((t) => _money(t) != null)) {
          tokens = tokens.sublist(1);
        }
        if (tokens.length == 3 && tokens.every((t) => _money(t) != null)) {
          final first = rows[i].confidence;
          final second = rows[i + 1].confidence;
          final confidence = first == null
              ? second
              : second == null
              ? first
              : (first < second ? first : second);
          item = _item(
            '$text ${tokens.join(' ')}',
            columns,
            confidence,
            items.length,
          );
          if (item != null) i++;
        }
      }
      if (item != null) {
        collect?.call(item, nameRow);
        items.add(item);
        if (item.confidence != null && item.confidence! < .8) {
          notes.add('흐리게 인식된 품목을 확인해 주세요: $originalText');
        }
      } else if (!_excluded(_normalize(originalText)) &&
          _hasNumericToken(originalText)) {
        notes.add('품목으로 확정하지 못한 행이에요: $originalText');
      }
      if (item == null &&
          (headerIndex >= 0 || items.isNotEmpty) &&
          !_excluded(_normalize(originalText)) &&
          _cleanName(originalText).isNotEmpty &&
          RegExp(
            r'[A-Za-z가-힣]',
          ).hasMatch(originalText.replaceAll(RegExp(r'[원개]'), '')) &&
          !RegExp(r'^\d{6,}(?:\s|$)').hasMatch(originalText)) {
        collect?.call(null, nameRow);
      }
    }
    return ReceiptScanResult(
      items: items,
      totalAmount: bestTotals.length == 1 ? bestTotals.single : null,
      rawText: rows.map((row) => row.text).join('\n'),
      reviewNotes: notes,
    );
  }

  String _columnText(
    _ReceiptVisualRow row,
    _ReceiptVisualRow header, {
    bool recoverQuantity = false,
  }) {
    if (row._lines.length < 2) return row.text;
    final anchors = header._lines
        .where(
          (word) =>
              _headerPattern.hasMatch(word.text) ||
              const ['단가', '수량', '금액'].contains(word.text.replaceAll(' ', '')),
        )
        .toList();
    if (anchors.length < 3 ||
        anchors.any((a) => a.right <= a.left) ||
        row._lines.any((a) => a.right <= a.left) ||
        !anchors.any((a) => a.text.replaceAll(' ', '') == '금액')) {
      return row.text;
    }
    final cells = List.generate(anchors.length, (_) => <String>[]);
    for (final word in row._lines) {
      final x = (word.left + word.right) / 2;
      var column = 0;
      for (var i = 1; i < anchors.length; i++) {
        final boundary =
            (anchors[i - 1].left +
                anchors[i - 1].right +
                anchors[i].left +
                anchors[i].right) /
            4;
        if (x >= boundary) column = i;
      }
      cells[column].add(word.text);
    }
    // Preserve numeric product names, but never shift a missing numeric cell.
    final numeric = <String>[];
    final numericLabels = <String>[];
    var name = '';
    for (var i = 0; i < anchors.length; i++) {
      final value = cells[i].join(' ');
      if (_headerPattern.hasMatch(anchors[i].text)) {
        name = value;
      } else {
        numericLabels.add(anchors[i].text.replaceAll(' ', ''));
        numeric.add(value.replaceAll(RegExp(r'\s+(?=원|개|ea)|(?<=₩)\s+'), ''));
      }
    }
    if (numeric.every((value) => value.isEmpty)) return name;
    // A long name can extend across the price columns on a name-only row.
    // Keep that row intact for the following product-code/price detail row.
    if (numeric.any((value) => RegExp(r'[가-힣A-Za-z]').hasMatch(value))) {
      return row.text;
    }
    if (numeric.any((value) => value.isEmpty)) {
      final unit = numericLabels.indexOf('단가');
      final quantity = numericLabels.indexOf('수량');
      final amount = numericLabels.indexOf('금액');
      if (recoverQuantity &&
          unit >= 0 &&
          quantity >= 0 &&
          amount >= 0 &&
          numeric[quantity].isEmpty) {
        final price = _money(_normalize(numeric[unit]));
        final total = _money(_normalize(numeric[amount]));
        if (price != null &&
            price > 0 &&
            total != null &&
            total > 0 &&
            total % price == 0 &&
            total ~/ price <= 99) {
          return '$name § $price ${total ~/ price} $total';
        }
      }
      // Some receipts intentionally leave unit price blank. Use the explicitly
      // positioned quantity and line amount, without inventing a unit price.
      if (numeric.length == 3 &&
          unit >= 0 &&
          quantity >= 0 &&
          amount >= 0 &&
          numeric[unit].isEmpty &&
          _money(numeric[quantity]) != null &&
          _money(numeric[amount]) != null) {
        return '$name § ${numeric[quantity]}개 ${numeric[amount]}';
      }
      return '';
    }
    // A separator prevents a trailing number in a product name joining the numeric columns.
    return '$name § ${numeric.join(' ')}';
  }

  ReceiptItemDraft? _item(
    String text,
    List<String> columns,
    double? confidence,
    int index,
  ) {
    final isDiscount = RegExp(r'할\s*인|쿠폰').hasMatch(text);
    if (_nonPurchase(text)) return null;
    if (_excluded(text) && !isDiscount) return null;
    final tokens = text.split(' ');
    var start = tokens.length;
    while (start > 0 && _money(tokens[start - 1]) != null) {
      start--;
    }
    if (start == tokens.length || start == 0) return null;
    final numbers = tokens.sublist(start).map((t) => _money(t)!).toList();
    final name = _cleanName(tokens.take(start).join(' ').replaceAll('§', ''));
    if (name.isEmpty || !RegExp(r'[A-Za-z가-힣]').hasMatch(name)) return null;
    if (RegExp(r'^\d{6,}(?:\s|$)').hasMatch(name)) return null;
    var quantity = 1;
    var amount = numbers.last;
    if (numbers.length == 3) {
      final layout =
          columns.length == 3 && columns.toSet().containsAll(['단가', '수량', '금액'])
          ? columns
          : ['단가', '수량', '금액'];
      quantity = numbers[layout.indexOf('수량')];
      amount = numbers[layout.indexOf('금액')];
      final unit = numbers[layout.indexOf('단가')];
      if (quantity <= 0 || unit * quantity != amount) return null;
    } else if (numbers.length == 2) {
      if (columns.length == 2 &&
          columns.contains('수량') &&
          columns.contains('금액')) {
        quantity = numbers[columns.indexOf('수량')];
        amount = numbers[columns.indexOf('금액')];
      } else if (RegExp(
            r'(개|ea)$',
            caseSensitive: false,
          ).hasMatch(tokens[start]) ||
          ((columns.isEmpty ||
                  (columns.length == 1 && columns.single == '금액')) &&
              numbers.first > 0 &&
              numbers.first < 100)) {
        quantity = numbers.first;
      } else {
        return null;
      }
    } else if (numbers.length != 1 || (columns.contains('수량') && !isDiscount)) {
      return null;
    }
    if (quantity <= 0) return null;
    // A positive discount has no reliable sign; retain it only in the raw text.
    if (isDiscount && amount >= 0) return null;
    return ReceiptItemDraft(
      id: 'ocr-$index',
      name: name,
      quantity: quantity,
      amount: amount,
      confidence: confidence,
    );
  }

  bool _excluded(String text) =>
      text.isEmpty ||
      _nonPurchase(text) ||
      _headerPattern.hasMatch(text) ||
      _metadataPattern.hasMatch(text) ||
      _numberLikePattern.hasMatch(text) ||
      _totalLabelScore(text) > 0;

  bool _hasNumericToken(String text) => RegExp(r'\d').hasMatch(text);
  bool _endsInNumber(String text) => _money(text.split(' ').last) != null;

  int _totalLabelScore(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), '');
    if (RegExp(r'^(총결제금액|실결제금액|결제금액)').hasMatch(compact)) return 100;
    if (RegExp(r'^(판매합계|매출합계|총합계|총금액|합계)').hasMatch(compact)) return 90;
    if (RegExp(r'^[합계](?:\s|$)').hasMatch(text)) return 80;
    // A single explicitly labelled payment is useful on total-only tickets.
    // Multiple different payment lines remain ambiguous, never summed here.
    if (RegExp(
      r'^(KBPay|네이버페이|신용카드지불|승인금액)',
      caseSensitive: false,
    ).hasMatch(compact)) {
      return 70;
    }
    return 0;
  }

  bool _nonPurchase(String text) {
    final compact = text.replaceAll(RegExp(r'[\s:：\-]'), '');
    return RegExp(
      r'^(부가[세서]|과세|면세|공급가|거래금액|판매합계|KBPay|네이버페이|사용가능|주차|.*할인.*(?:혜택|안내)|.*쿠폰.*(?:혜택|안내))',
      caseSensitive: false,
    ).hasMatch(compact);
  }

  Set<int> _summaryCandidates(String text) {
    final match = RegExp(
      r'(?:^|\s|:)(\d[\d,.]*(?:원|S1)?)$',
    ).firstMatch(_normalize(text));
    if (match == null) return {};
    final raw = match.group(1)!;
    final exact = _money(raw);
    // A valid number wins. Repairs need malformed grouping or a damaged glyph.
    if (exact != null) return {exact};
    return {
      for (final suffix in ['S1', '91', '1'])
        if (raw.endsWith(suffix) && raw.length > suffix.length + 2)
          if (_money(raw.substring(0, raw.length - suffix.length))
              case final int value)
            value,
    };
  }

  int? _taxVerifiedTotal(String text, List<_ReceiptVisualRow> rows) {
    final bases = <int>{};
    final taxes = <int>{};
    for (final row in rows) {
      final compact = row.text.replaceAll(RegExp(r'[\s:：\-]'), '');
      if (RegExp(r'^(거래금액|공급가액|과세합계)').hasMatch(compact)) {
        bases.addAll(_summaryCandidates(row.text));
      } else if (RegExp(r'^부가[세서](?=\d)').hasMatch(compact)) {
        taxes.addAll(_summaryCandidates(row.text));
      }
    }
    final candidates = _summaryCandidates(text);
    final matches = {
      for (final base in bases)
        for (final tax in taxes)
          if (base >= 0 && tax >= 0 && candidates.contains(base + tax))
            base + tax,
    };
    return matches.length == 1 ? matches.single : null;
  }

  int? _summaryAmount(String text) {
    final withoutVat = text
        .split(RegExp(r'\(?VAT', caseSensitive: false))
        .first
        .trim();
    final match = RegExp(
      r'(?:^|\s|:)(₩?\s*-?[\d,.]+\s*원?)$',
    ).firstMatch(withoutVat);
    return match == null ? null : _money(match.group(1)!);
  }

  int? _money(String text) {
    final value = text
        .replaceAll(RegExp(r'^(?:₩\s*)|(?:원|개|ea)$', caseSensitive: false), '')
        .trim();
    return _number.hasMatch(value)
        ? int.tryParse(value.replaceAll(',', ''))
        : null;
  }

  String _cleanName(String value) => value
      .replaceAll(_optionSuffixPattern, '')
      .replaceAll(RegExp(r'^\s*\d{1,3}(?:[.)\-]\s*|\s+)'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  List<_ReceiptVisualRow> _mergeVisualRows(
    List<ReceiptTextLine> lines,
    double toleranceFactor,
  ) {
    final rows = <_ReceiptVisualRow>[];
    for (final line in lines) {
      final height = line.bottom > line.top ? line.bottom - line.top : 1.0;
      final center = line.bottom > line.top
          ? (line.top + line.bottom) / 2
          : line.top;
      _ReceiptVisualRow? target;
      var closest = double.infinity;
      // ponytail: quadratic scan for short receipts; use a vertical index if
      // long documents become a supported input.
      for (final row in rows.reversed) {
        final tolerance =
            (height > row.height ? height : row.height) * toleranceFactor;
        final distance = (center - row.center).abs();
        if (distance <= tolerance &&
            distance < closest &&
            !row.overlapsHorizontally(line)) {
          target = row;
          closest = distance;
        }
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
        .replaceAll(RegExp(r'(?<=\d)\s*#\s*$'), '')
        .replaceAllMapped(
          RegExp(r'(^|\s)[lLI](?=[.,]?\s*\d)'),
          (match) => '${match.group(1)}1',
        )
        .replaceAllMapped(RegExp(r'([,.])\s+(?=\d)'), (m) => m.group(1)!)
        .replaceAllMapped(
          RegExp(r'(\d)\.(?=\d{3}(?:\D|$))'),
          (match) => '${match.group(1)},',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return normalized;
  }
}

class _ReceiptCandidateGroup {
  _ReceiptCandidateGroup(this.center, this.height);
  final double center;
  final double height;
  final Map<String, ReceiptItemDraft> choices = {};
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

  bool overlapsHorizontally(ReceiptTextLine line) => _lines.any(
    (other) =>
        line.right > line.left &&
        other.right > other.left &&
        // Adjacent glyph boxes can overlap slightly ("4." / "430").
        // Substantial overlap still identifies competing, separate rows.
        (line.right < other.right ? line.right : other.right) -
                (line.left > other.left ? line.left : other.left) >
            .1 *
                ((line.right - line.left) < (other.right - other.left)
                    ? line.right - line.left
                    : other.right - other.left),
  );

  String get text => _lines.map((line) => line.text).join(' ');

  double? get confidence {
    final values = _lines
        .map((line) => line.confidence)
        .whereType<double>()
        .toList();
    return values.isEmpty ? null : values.reduce((a, b) => a < b ? a : b);
  }
}
