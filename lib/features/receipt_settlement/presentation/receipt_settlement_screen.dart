import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/app_dialog.dart';
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
  final _people = <_Person>[_Person('나', Color(0xFF2457F5))];

  final _imagePicker = ImagePicker();
  final _ocr = ReceiptOcrService();
  final Set<String> _selectedTravelers = {'나'};
  final Map<String, Set<String>> _itemPeople = {};
  List<ReceiptItemDraft> _items = [];
  List<ReceiptItemDraft> _detailItems = [];
  ReceiptItemDraft? _totalItem;
  Uint8List? _receiptBytes;
  String _rawText = '';
  List<String> _reviewNotes = [];
  String? _errorMessage;
  int? _receiptTotal;
  bool _isScanning = false;
  bool _reviewed = false;

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
  bool get _usingTotal => _items.length == 1 && _items.single.isReceiptTotal;

  void _toggleTotalMode() {
    if (_receiptTotal == null) return;
    setState(() {
      _reviewed = false;
      if (_usingTotal) {
        _totalItem = _items.single;
        _items = _detailItems;
      } else {
        _detailItems = _items;
        _items = [
          _totalItem?.copyWith(amount: _receiptTotal!) ??
              ReceiptItemDraft(
                id: 'receipt-total',
                name:
                    ReceiptScanResult(
                      items: const [],
                      rawText: _rawText,
                    ).merchantName ??
                    '업소명 확인',
                quantity: 1,
                amount: _receiptTotal!,
                isReceiptTotal: true,
                category: ReceiptCategory.suggest(
                  _rawText.split('\n').take(8).join(' '),
                  wholeReceipt: true,
                ),
              ),
        ];
        _itemPeople.putIfAbsent(
          'receipt-total',
          () => Set<String>.from(_selectedTravelers),
        );
      }
      _errorMessage = null;
    });
  }

  bool get _hasTotalMismatch =>
      _receiptTotal != null && _items.isNotEmpty && _receiptTotal != _itemSum;

  bool get _canSettle =>
      !_isScanning &&
      _items.isNotEmpty &&
      _itemSum >= 0 &&
      !_hasTotalMismatch &&
      (_receiptBytes == null || (_reviewed && _receiptTotal != null)) &&
      _items.every((item) => _itemPeople[item.id]?.isNotEmpty ?? false);

  Future<void> _editTotal() async {
    var totalText = _receiptTotal?.toString() ?? '';
    final formKey = GlobalKey<FormState>();
    final total = await showDialog<int>(
      context: context,
      builder: (context) => AppDialog(
        title: const Text('사진의 최종 결제 금액'),
        content: Form(
          key: formKey,
          child: TextFormField(
            initialValue: totalText,
            onChanged: (value) => totalText = value,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '총액', suffixText: '원'),
            validator: (value) =>
                (int.tryParse((value ?? '').replaceAll(',', '')) ?? -1) < 0
                ? '0 이상의 정수 금액을 입력해 주세요.'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(
                  context,
                  int.parse(totalText.replaceAll(',', '')),
                );
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (!mounted || total == null) return;
    setState(() {
      _receiptTotal = total;
      if (_usingTotal) _items = [_items.single.copyWith(amount: total)];
      _reviewed = false;
    });
  }

  Future<void> _chooseReceiptSource() async {
    if (!_supportsOnDeviceOcr) {
      setState(() => _errorMessage = '영수증 글자 인식은 Android와 iOS에서 사용할 수 있어요.');
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
    final image = await _imagePicker.pickImage(source: source);
    if (image == null || !mounted) return;
    await _scanReceipt(image);
  }

  Future<void> _scanReceipt(XFile image) async {
    setState(() {
      _isScanning = true;
      _errorMessage = null;
      _reviewed = false;
      _items = [];
      _detailItems = [];
      _totalItem = null;
      _itemPeople.clear();
      _receiptTotal = null;
      _rawText = '';
      _reviewNotes = [];
      _receiptBytes = null;
    });
    try {
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() => _receiptBytes = bytes);

      final result = await _ocr.scan(image.path);
      if (!mounted) return;
      setState(() {
        _rawText = result.rawText;
        _reviewNotes = result.reviewNotes;
        _receiptTotal = result.totalAmount;
        _items = result.items;
        _itemPeople
          ..clear()
          ..addEntries(
            result.items.map(
              (item) => MapEntry(item.id, Set<String>.from(_selectedTravelers)),
            ),
          );
        if (result.items.isEmpty && result.totalAmount == null) {
          _errorMessage = '품목을 읽지 못했어요. 다시 촬영하거나 직접 추가해 주세요.';
        }
      });
    } catch (error, stackTrace) {
      debugPrint('Receipt OCR failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(
          () => _errorMessage = '영수증을 읽지 못했어요. 선명하게 다시 촬영하거나 품목을 직접 입력해 주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _toggleTraveler(_Person person, bool selected) {
    setState(() {
      _reviewed = false;
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

  Future<void> _addTraveler() async {
    var enteredName = '';
    final form = GlobalKey<FormState>();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AppDialog(
        title: const Text('정산 참여자 추가'),
        content: Form(
          key: form,
          child: TextFormField(
            onSaved: (value) => enteredName = value!.trim(),
            autofocus: true,
            maxLength: 30,
            decoration: const InputDecoration(labelText: '이름'),
            validator: (value) {
              final name = value?.trim() ?? '';
              if (name.isEmpty) return '이름을 입력해 주세요.';
              if (_people.any((person) => person.name == name)) {
                return '이미 추가한 이름입니다.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                form.currentState!.save();
                Navigator.pop(context, enteredName);
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
    if (name == null || !mounted) return;
    setState(() {
      _people.add(_Person(name, AppColors.primaryBlue));
      _selectedTravelers.add(name);
      _reviewed = false;
    });
  }

  void _removeTraveler(_Person person) {
    setState(() {
      _people.remove(person);
      _selectedTravelers.remove(person.name);
      for (final names in _itemPeople.values) {
        names.remove(person.name);
      }
      _reviewed = false;
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
    final result = await Navigator.of(context).push<ReceiptItemDraft>(
      MaterialPageRoute(
        builder: (_) => _ReceiptItemEditorScreen(existing: existing),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _reviewed = false;
      final index = _items.indexWhere((item) => item.id == result.id);
      if (index == -1) {
        _items = [..._items, result];
        _itemPeople[result.id] = Set<String>.from(_selectedTravelers);
      } else {
        _items = [..._items]..[index] = result;
      }
      if (result.isReceiptTotal) _receiptTotal = result.amount;
      _errorMessage = null;
    });
  }

  void _deleteItem(ReceiptItemDraft item) {
    setState(() {
      _reviewed = false;
      _items = _items.where((candidate) => candidate.id != item.id).toList();
      _itemPeople.remove(item.id);
    });
  }

  String _won(int amount) => _formatWon(amount);
  String _perPerson(ReceiptItemDraft item) {
    if (!_canSettle) return '확인 전';
    final count = _itemPeople[item.id]?.length ?? 0;
    return count == 0 ? '나눌 사람 선택' : '1인 ${_won(item.amount ~/ count)}';
  }

  List<(_Person, String)> _settlementRows() {
    final totals = {for (final person in _people) person.name: 0};
    for (final item in _items) {
      final names = _itemPeople[item.id]?.toList() ?? const <String>[];
      if (names.isEmpty) continue;
      final base = (item.amount / names.length).floor();
      final remainder = item.amount % names.length;
      for (var index = 0; index < names.length; index++) {
        totals[names[index]] =
            totals[names[index]]! + base + (index < remainder ? 1 : 0);
      }
    }
    return _people
        .where((person) => (totals[person.name] ?? 0) != 0)
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
          onPressed: !_canSettle
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
                        '이번 여행에서 사용한 비용을 정산할 수 있어요',
                        style: TextStyle(
                          color: AppColors.white.withValues(alpha: .76),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      AppMetricStrip(
                        items: [
                          (
                            label: '총액',
                            value: _canSettle ? _won(_itemSum) : '확인 전',
                          ),
                          (
                            label: '참여자',
                            value: '${_selectedTravelers.length}명',
                          ),
                          (
                            label: '정산 항목',
                            value: _usingTotal ? '전체 결제' : '${_items.length}개',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const _SectionHeader(
                  step: '01',
                  title: '영수증 사진',
                  description: '영수증 전체를 반사광 없이 평평하게 찍고 작은 글자에 초점을 맞춰 주세요.',
                ),
                const SizedBox(height: 12),
                _ReceiptUploadCard(
                  imageBytes: _receiptBytes,
                  isScanning: _isScanning,
                  onPressed: _isScanning ? null : _chooseReceiptSource,
                ),
                if (_receiptBytes != null) ...[
                  TextButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (context) => Dialog.fullscreen(
                        child: Scaffold(
                          appBar: AppBar(title: const Text('영수증 원본')),
                          body: InteractiveViewer(
                            minScale: .5,
                            maxScale: 8,
                            child: Center(child: Image.memory(_receiptBytes!)),
                          ),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.zoom_in),
                    label: const Text('원본 확대해서 확인'),
                  ),
                  const _Notice(
                    message: '사진을 보고 품목과 금액이 맞는지 확인해 주세요.',
                    isError: false,
                  ),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  _Notice(message: _errorMessage!, isError: true),
                ],
                if (_rawText.isNotEmpty) ...[
                  if (_reviewNotes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const _Notice(
                      message: '확인이 필요한 내용이 있어요. 사진을 보고 품목과 금액을 확인해 주세요.',
                      isError: false,
                    ),
                  ],
                  const SizedBox(height: 8),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text(
                      '사진에서 읽은 내용 보기',
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
                  onRemove: _removeTraveler,
                ),
                TextButton.icon(
                  onPressed: _isScanning ? null : _addTraveler,
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('참여자 추가'),
                ),
                const SizedBox(height: 30),
                const _SectionHeader(
                  step: '03',
                  title: '정산 품목',
                  description: '인식 결과를 확인하고 잘못된 부분을 수정하세요.',
                ),
                const SizedBox(height: 12),
                if (_receiptBytes != null && _receiptTotal != null) ...[
                  OutlinedButton.icon(
                    onPressed: _isScanning ? null : _toggleTotalMode,
                    icon: const Icon(Icons.swap_horiz),
                    label: Text(_usingTotal ? '품목별로 나누기' : '총액으로 나누기'),
                  ),
                  if (_items.isEmpty)
                    const _Notice(
                      message: '확인된 총액으로 나누거나 품목을 직접 추가할 수 있어요.',
                      isError: false,
                    ),
                  if (_usingTotal)
                    const _Notice(
                      message: '품목별 금액 대신 전체 결제 금액을 나눠요. 업소명과 금액을 확인해 주세요.',
                      isError: false,
                    ),
                  const SizedBox(height: 12),
                ],
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
                      onDelete: _usingTotal
                          ? _toggleTotalMode
                          : () => _deleteItem(_items[index]),
                    ),
                  ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isScanning || _usingTotal
                      ? null
                      : () => _addOrEditItem(),
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
                if (_receiptBytes != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _isScanning ? null : _editTotal,
                    child: Text(
                      _receiptTotal == null
                          ? '총 결제 금액 입력'
                          : '총 결제 금액 ${_won(_receiptTotal!)} · 수정',
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('품목·할인·총액을 원본과 대조했어요'),
                    value: _reviewed,
                    onChanged:
                        _isScanning ||
                            _items.isEmpty ||
                            _hasTotalMismatch ||
                            _receiptTotal == null
                        ? null
                        : (value) => setState(() => _reviewed = value ?? false),
                  ),
                ],
                const SizedBox(height: 30),
                const _SectionHeader(
                  step: '04',
                  title: '정산',
                  description: '각자 낼 금액을 마지막으로 확인해요.',
                ),
                const SizedBox(height: 12),
                if (_canSettle)
                  _SettlementSummary(total: _itemSum, rows: _settlementRows())
                else
                  const _Notice(
                    message: '품목과 총액을 확인하고 나눌 사람을 선택하면 정산 결과가 표시돼요.',
                    isError: false,
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

class _ReceiptItemEditorScreen extends StatefulWidget {
  const _ReceiptItemEditorScreen({this.existing});

  final ReceiptItemDraft? existing;

  @override
  State<_ReceiptItemEditorScreen> createState() =>
      _ReceiptItemEditorScreenState();
}

class _ReceiptItemEditorScreenState extends State<_ReceiptItemEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _amountController;
  late ReceiptCategory _category;

  @override
  void initState() {
    super.initState();
    _category = widget.existing?.displayCategory ?? ReceiptCategory.unknown;
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
        category: _category,
        isReceiptTotal: widget.existing?.isReceiptTotal ?? false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? '품목 수정' : '품목 직접 추가')),
      bottomNavigationBar: AppStickyActionBar(
        child: FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: Text(isEditing ? '수정 내용 저장' : '품목 추가'),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.readingWidth),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                children: [
                  Text(
                    isEditing
                        ? '영수증에서 인식한 품목 정보를 바로잡아 주세요.'
                        : '정산에 포함할 품목과 금액을 입력해 주세요.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<ReceiptCategory>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: '분류'),
                    items: [
                      for (final value in ReceiptCategory.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                    ],
                    onChanged: (value) => setState(
                      () => _category = value ?? ReceiptCategory.unknown,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: (widget.existing?.isReceiptTotal ?? false)
                          ? '업소명'
                          : '품목명',
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? '품목명을 입력해 주세요.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  if (!(widget.existing?.isReceiptTotal ?? false)) ...[
                    TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: '수량'),
                      validator: (value) => (int.tryParse(value ?? '') ?? 0) < 1
                          ? '1 이상의 수량을 입력해 주세요.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _save(),
                    decoration: const InputDecoration(
                      labelText: '품목 총 금액',
                      helperText: '단가 × 수량의 금액을 입력하세요. 할인·환불은 음수로 입력해요.',
                      suffixText: '원',
                    ),
                    validator: (value) =>
                        int.tryParse((value ?? '').replaceAll(',', '')) ==
                                null ||
                            ((widget.existing?.isReceiptTotal ?? false) &&
                                (int.tryParse(
                                          (value ?? '').replaceAll(',', ''),
                                        ) ??
                                        -1) <
                                    0)
                        ? '정수 금액을 입력해 주세요.'
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
    required this.onRemove,
  });
  final List<_Person> people;
  final Set<String> selectedNames;
  final void Function(_Person, bool) onSelected;
  final ValueChanged<_Person> onRemove;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final person in people)
          InputChip(
            avatar: _Avatar(person: person, small: true),
            label: Text(person.name),
            selected: selectedNames.contains(person.name),
            onSelected: (selected) => onSelected(person, selected),
            onDeleted: person.name == '나' ? null : () => onRemove(person),
            deleteButtonTooltipMessage: '${person.name} 제거',
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
                    item.isReceiptTotal ? '전체 결제' : '${item.quantity}개',
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
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return '${amount < 0 ? '-' : ''}${buffer.toString()}원';
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
