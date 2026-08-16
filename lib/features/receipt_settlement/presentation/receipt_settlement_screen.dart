import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/premium_ui.dart';
import '../receipt_ocr_service.dart';
import '../receipt_scan_result.dart';

class ReceiptSettlementScreen extends StatefulWidget {
  const ReceiptSettlementScreen({super.key, required this.travelTitle});
  final String travelTitle;

  @override
  State<ReceiptSettlementScreen> createState() =>
      _ReceiptSettlementScreenState();
}

class _ReceiptSettlementScreenState extends State<ReceiptSettlementScreen> {
  static const _people = [
    _Person('나', Color(0xFF2457F5)),
    _Person('민지', Color(0xFFE65D8D)),
    _Person('준호', Color(0xFF00A78E)),
    _Person('서연', Color(0xFFFF8A3D)),
  ];

  final _imagePicker = ImagePicker();
  final _ocr = ReceiptOcrService();
  final Set<String> _selectedTravelers = {'나', '민지', '준호', '서연'};
  final Map<String, Set<String>> _itemPeople = {};
  List<ReceiptItemDraft> _items = [];
  Uint8List? _receiptBytes;
  String _rawText = '';
  String? _errorMessage;
  int? _receiptTotal;
  bool _isScanning = false;

  @override
  void dispose() {
    unawaited(_ocr.close());
    super.dispose();
  }

  bool get _supportsOnDeviceOcr =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  int get _itemSum => _items.fold(0, (sum, item) => sum + item.amount);
  bool get _hasTotalMismatch =>
      _receiptTotal != null && _items.isNotEmpty && _receiptTotal != _itemSum;

  Future<void> _chooseReceiptSource() async {
    if (!_supportsOnDeviceOcr) {
      setState(() => _errorMessage = '영수증 OCR은 Android와 iOS에서 사용할 수 있어요.');
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('카메라로 촬영'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('앨범에서 선택'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;
    final image = await _imagePicker.pickImage(
      source: source,
      maxWidth: 2000,
      imageQuality: 92,
    );
    if (image == null || !mounted) return;
    await _scanReceipt(image);
  }

  Future<void> _scanReceipt(XFile image) async {
    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });
    try {
      final bytes = await image.readAsBytes();
      final result = await _ocr.scan(image.path);
      if (!mounted) return;
      setState(() {
        _receiptBytes = bytes;
        _rawText = result.rawText;
        _receiptTotal = result.totalAmount;
        _items = result.items;
        _itemPeople
          ..clear()
          ..addEntries(
            result.items.map(
              (item) => MapEntry(item.id, Set<String>.from(_selectedTravelers)),
            ),
          );
        if (result.items.isEmpty) {
          _errorMessage = '품목을 찾지 못했어요. 인식 원문을 확인하고 직접 추가해 주세요.';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage = '영수증을 읽지 못했어요. 더 밝고 선명한 사진으로 다시 시도해 주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _toggleTraveler(_Person person, bool selected) {
    setState(() {
      if (selected) {
        _selectedTravelers.add(person.name);
      } else {
        _selectedTravelers.remove(person.name);
        for (final people in _itemPeople.values) {
          people.remove(person.name);
        }
      }
    });
  }

  Future<void> _editItemPeople(ReceiptItemDraft item) async {
    final draft = Set<String>.from(_itemPeople[item.id] ?? const {});
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${item.name} 나눌 사람',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                const Text(
                  '이 품목의 금액을 같이 나눌 사람을 선택하세요.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final person in _people)
                      if (_selectedTravelers.contains(person.name))
                        FilterChip(
                          avatar: _Avatar(person: person, small: true),
                          label: Text(person.name),
                          selected: draft.contains(person.name),
                          onSelected: (selected) => setSheetState(() {
                            selected
                                ? draft.add(person.name)
                                : draft.remove(person.name);
                          }),
                        ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: draft.isEmpty
                      ? null
                      : () {
                          setState(() => _itemPeople[item.id] = draft);
                          Navigator.pop(sheetContext);
                        },
                  child: const Text('선택 완료'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addOrEditItem([ReceiptItemDraft? existing]) async {
    final result = await showDialog<ReceiptItemDraft>(
      context: context,
      builder: (context) => _ReceiptItemEditorDialog(existing: existing),
    );
    if (result == null || !mounted) return;
    setState(() {
      final index = _items.indexWhere((item) => item.id == result.id);
      if (index == -1) {
        _items = [..._items, result];
        _itemPeople[result.id] = Set<String>.from(_selectedTravelers);
      } else {
        _items = [..._items]..[index] = result;
      }
      _errorMessage = null;
    });
  }

  void _deleteItem(ReceiptItemDraft item) {
    setState(() {
      _items = _items.where((candidate) => candidate.id != item.id).toList();
      _itemPeople.remove(item.id);
    });
  }

  String _won(int amount) => _formatWon(amount);
  String _perPerson(ReceiptItemDraft item) {
    final count = _itemPeople[item.id]?.length ?? 0;
    return count == 0 ? '나눌 사람 선택' : '1인 ${_won(item.amount ~/ count)}';
  }

  List<(_Person, String)> _settlementRows() {
    final totals = {for (final person in _people) person.name: 0};
    for (final item in _items) {
      final names = _itemPeople[item.id]?.toList() ?? const <String>[];
      if (names.isEmpty) continue;
      final base = item.amount ~/ names.length;
      final remainder = item.amount % names.length;
      for (var index = 0; index < names.length; index++) {
        totals[names[index]] =
            totals[names[index]]! + base + (index < remainder ? 1 : 0);
      }
    }
    return _people
        .where((person) => (totals[person.name] ?? 0) > 0)
        .map((person) => (person, _won(totals[person.name]!)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final gutter = MediaQuery.sizeOf(context).width < 360 ? 16.0 : 24.0;
    return Scaffold(
      appBar: AppBar(title: const Text('영수증 정산')),
      bottomNavigationBar: AppStickyActionBar(
        child: FilledButton(
          onPressed: _items.isEmpty
              ? null
              : () => ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('정산 결과를 확인했어요.'))),
          child: const Text('정산 결과 확인'),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.readingWidth),
            child: ListView(
              padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 32),
              children: [
                AppHeroCard(
                  padding: const EdgeInsets.all(22),
                  visual: AppHeroVisual.settlement,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TRIP SETTLEMENT',
                        style: TextStyle(
                          color: AppColors.accentLime,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.travelTitle,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(color: AppColors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '영수증은 기기에서만 읽고 서버에 저장하지 않아요.',
                        style: TextStyle(
                          color: AppColors.white.withValues(alpha: .76),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      AppMetricStrip(
                        items: [
                          (label: '총액', value: _won(_receiptTotal ?? _itemSum)),
                          (label: '참여자', value: '${_people.length}명'),
                          (label: '품목', value: '${_items.length}개'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const _SectionHeader(
                  step: '01',
                  title: '영수증 사진',
                  description: '품목과 금액이 잘 보이는 사진을 올려주세요.',
                ),
                const SizedBox(height: 12),
                _ReceiptUploadCard(
                  imageBytes: _receiptBytes,
                  isScanning: _isScanning,
                  onPressed: _isScanning ? null : _chooseReceiptSource,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  _Notice(message: _errorMessage!, isError: true),
                ],
                if (_rawText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text(
                      'OCR 인식 원문 보기',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SelectableText(
                          _rawText,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 30),
                const _SectionHeader(
                  step: '02',
                  title: '같이 여행한 사람',
                  description: '이번 결제에 함께한 사람을 선택해요.',
                ),
                const SizedBox(height: 12),
                _TravelerCard(
                  people: _people,
                  selectedNames: _selectedTravelers,
                  onSelected: _toggleTraveler,
                ),
                const SizedBox(height: 30),
                const _SectionHeader(
                  step: '03',
                  title: '정산 품목',
                  description: '인식 결과를 확인하고 잘못된 부분을 수정하세요.',
                ),
                const SizedBox(height: 12),
                if (_items.isEmpty)
                  const _EmptyItemsCard()
                else
                  for (var index = 0; index < _items.length; index++) ...[
                    if (index > 0) const SizedBox(height: 12),
                    _ItemCard(
                      item: _items[index],
                      perPerson: _perPerson(_items[index]),
                      people: _people
                          .where(
                            (person) =>
                                _itemPeople[_items[index].id]?.contains(
                                  person.name,
                                ) ??
                                false,
                          )
                          .toList(),
                      onAssign: () => _editItemPeople(_items[index]),
                      onEdit: () => _addOrEditItem(_items[index]),
                      onDelete: () => _deleteItem(_items[index]),
                    ),
                  ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _addOrEditItem(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('품목 직접 추가'),
                ),
                if (_hasTotalMismatch) ...[
                  const SizedBox(height: 12),
                  _Notice(
                    message:
                        '품목 합계 ${_won(_itemSum)}와 영수증 총액 ${_won(_receiptTotal!)}이 달라요.',
                    isError: false,
                  ),
                ],
                const SizedBox(height: 30),
                const _SectionHeader(
                  step: '04',
                  title: '정산',
                  description: '각자 낼 금액을 마지막으로 확인해요.',
                ),
                const SizedBox(height: 12),
                _SettlementSummary(
                  total: _receiptTotal ?? _itemSum,
                  rows: _settlementRows(),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceiptItemEditorDialog extends StatefulWidget {
  const _ReceiptItemEditorDialog({this.existing});

  final ReceiptItemDraft? existing;

  @override
  State<_ReceiptItemEditorDialog> createState() =>
      _ReceiptItemEditorDialogState();
}

class _ReceiptItemEditorDialogState extends State<_ReceiptItemEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name);
    _quantityController = TextEditingController(
      text: widget.existing?.quantity.toString() ?? '1',
    );
    _amountController = TextEditingController(
      text: widget.existing?.amount.toString(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      ReceiptItemDraft(
        id:
            widget.existing?.id ??
            'manual-${DateTime.now().microsecondsSinceEpoch}',
        name: _nameController.text.trim(),
        quantity: int.parse(_quantityController.text),
        amount: int.parse(_amountController.text.replaceAll(',', '')),
        confidence: widget.existing?.confidence,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '품목 직접 추가' : '품목 수정'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: '품목명'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? '품목명을 입력해 주세요.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '수량'),
                validator: (value) => (int.tryParse(value ?? '') ?? 0) < 1
                    ? '1 이상의 수량을 입력해 주세요.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '총 금액',
                  suffixText: '원',
                ),
                validator: (value) =>
                    (int.tryParse((value ?? '').replaceAll(',', '')) ?? 0) < 1
                    ? '금액을 입력해 주세요.'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _save, child: const Text('저장')),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.step,
    required this.title,
    required this.description,
  });
  final String step;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.sky,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Text(
          step,
          style: const TextStyle(
            color: AppColors.primaryBlue,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 3),
            Text(
              description,
              style: const TextStyle(color: AppColors.gray500, fontSize: 13),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ReceiptUploadCard extends StatelessWidget {
  const _ReceiptUploadCard({
    required this.imageBytes,
    required this.isScanning,
    required this.onPressed,
  });
  final Uint8List? imageBytes;
  final bool isScanning;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => _Panel(
    onTap: onPressed,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final preview = ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: constraints.maxWidth < 340 ? double.infinity : 88,
            height: 112,
            color: AppColors.gray50,
            child: imageBytes == null
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        color: AppColors.primaryBlue,
                        size: 28,
                      ),
                      SizedBox(height: 7),
                      Text(
                        '사진 추가',
                        style: TextStyle(
                          color: AppColors.primaryBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  )
                : Image.memory(imageBytes!, fit: BoxFit.cover),
          ),
        );
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isScanning
                  ? '영수증을 읽고 있어요'
                  : imageBytes == null
                  ? '촬영하거나 앨범에서 선택하세요'
                  : '다른 영수증으로 다시 인식',
              style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35),
            ),
            const SizedBox(height: 8),
            Text(
              isScanning ? '품목과 금액을 찾는 중입니다.' : '한국어 인쇄 영수증 · 기기 내 처리',
              style: const TextStyle(color: AppColors.gray500, fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (isScanning)
              const LinearProgressIndicator()
            else
              const Row(
                children: [
                  Icon(
                    Icons.document_scanner_outlined,
                    size: 18,
                    color: AppColors.primaryBlue,
                  ),
                  SizedBox(width: 6),
                  Text(
                    '영수증 선택',
                    style: TextStyle(
                      color: AppColors.primaryBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
          ],
        );
        if (constraints.maxWidth < 340) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [preview, const SizedBox(height: 16), details],
          );
        }
        return Row(
          children: [
            preview,
            const SizedBox(width: 16),
            Expanded(child: details),
          ],
        );
      },
    ),
  );
}

class _TravelerCard extends StatelessWidget {
  const _TravelerCard({
    required this.people,
    required this.selectedNames,
    required this.onSelected,
  });
  final List<_Person> people;
  final Set<String> selectedNames;
  final void Function(_Person, bool) onSelected;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final person in people)
          FilterChip(
            avatar: _Avatar(person: person, small: true),
            label: Text(person.name),
            selected: selectedNames.contains(person.name),
            onSelected: (selected) => onSelected(person, selected),
            materialTapTargetSize: MaterialTapTargetSize.padded,
          ),
      ],
    ),
  );
}

class _Person {
  const _Person(this.name, this.color);
  final String name;
  final Color color;
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.person, this.small = false});
  final _Person person;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final size = small ? 26.0 : 36.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: person.color.withValues(alpha: .14),
        shape: BoxShape.circle,
        border: Border.all(color: person.color.withValues(alpha: .32)),
      ),
      child: Text(
        person.name.characters.first,
        style: TextStyle(
          color: person.color,
          fontSize: small ? 11 : 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.perPerson,
    required this.people,
    required this.onAssign,
    required this.onEdit,
    required this.onDelete,
  });
  final ReceiptItemDraft item;
  final String perPerson;
  final List<_Person> people;
  final VoidCallback onAssign;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.sky,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                color: AppColors.primaryBlue,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.quantity}개',
                    style: const TextStyle(
                      color: AppColors.gray500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatWon(item.amount),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  perPerson,
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            PopupMenuButton<String>(
              tooltip: '품목 메뉴',
              onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('수정')),
                PopupMenuItem(value: 'delete', child: Text('삭제')),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(height: 1),
        InkWell(
          onTap: onAssign,
          child: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 2),
            child: Row(
              children: [
                const Text(
                  '나눌 사람',
                  style: TextStyle(
                    color: AppColors.gray500,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: people.isEmpty
                      ? const Text(
                          '선택 필요',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            for (final person in people)
                              _Avatar(person: person, small: true),
                          ],
                        ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.gray400,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

String _formatWon(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return '${buffer.toString()}원';
}

class _EmptyItemsCard extends StatelessWidget {
  const _EmptyItemsCard();
  @override
  Widget build(BuildContext context) => const _Panel(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Icon(
            Icons.document_scanner_outlined,
            color: AppColors.gray400,
            size: 34,
          ),
          SizedBox(height: 10),
          Text(
            '영수증을 올리면 품목이 여기에 표시돼요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}

class _SettlementSummary extends StatelessWidget {
  const _SettlementSummary({required this.total, required this.rows});
  final int total;
  final List<(_Person, String)> rows;

  @override
  Widget build(BuildContext context) => _Panel(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Text(
                '총 결제 금액',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                _formatWon(total),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              '품목과 나눌 사람을 선택해 주세요.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                children: [
                  _Avatar(person: row.$1, small: true),
                  const SizedBox(width: 9),
                  Text(
                    row.$1.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Text(
                    row.$2,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 8),
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, required this.isError});
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: isError ? const Color(0xFFFFF1F0) : AppColors.yellow,
      borderRadius: BorderRadius.circular(AppRadii.control),
      border: Border.all(
        color: isError
            ? AppColors.error.withValues(alpha: .3)
            : AppColors.warning.withValues(alpha: .25),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
          size: 20,
          color: isError ? AppColors.error : AppColors.warning,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(20);
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: const BorderSide(color: AppColors.gray200),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
