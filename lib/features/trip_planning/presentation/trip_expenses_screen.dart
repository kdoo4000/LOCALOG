import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../services/kakao_invite_service.dart';

import '../../../core/widgets/app_dialog.dart';
import 'package:image_picker/image_picker.dart';

import '../../receipt_settlement/receipt_ocr_service.dart';
import '../data/shared_trip_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/premium_ui.dart';
import '../../profile/presentation/social_person_tile.dart';

class TripExpensesScreen extends StatefulWidget {
  const TripExpensesScreen({
    super.key,
    required this.planId,
    required this.title,
  });
  final String planId;
  final String title;

  @override
  State<TripExpensesScreen> createState() => _TripExpensesScreenState();
}

class _TripExpensesScreenState extends State<TripExpensesScreen> {
  final _repo = SharedTripRepository.instance;
  List<TripPerson> _people = [];
  List<TripExpense> _expenses = [];
  bool _loading = true;
  bool _sharing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    try {
      final people = await _repo.members(widget.planId);
      final expenses = await _repo.expenses(widget.planId);
      if (!mounted) return;
      setState(() {
        _people = people;
        _expenses = expenses;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _add() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _ExpenseEditor(planId: widget.planId, people: _people),
      ),
    );
    if (mounted) await _reload();
  }

  String _name(String id) {
    final person = _people.where((p) => p.id == id).firstOrNull;
    if (person == null) return '알 수 없는 사용자';
    final duplicate = _people.where((p) => p.name == person.name).length > 1;
    return duplicate ? '${person.name} (@${person.handle})' : person.name;
  }

  Future<void> _requestPayment(TripTransfer transfer) async {
    if (_sharing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: const Text('정산 요청'),
        content: Text(
          '${_name(transfer.fromId)}님이 ${_name(transfer.toId)}님에게\n${_won(transfer.amount)}\n\n카카오톡에서 받을 친구나 채팅방을 선택해 주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('카톡으로 요청'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _sharing = true);
    try {
      await shareKakaoSettlement(
        planId: widget.planId,
        title: widget.title,
        debtor: _name(transfer.fromId),
        creditor: _name(transfer.toId),
        amount: transfer.amount,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('카카오톡 요청 화면을 열지 못했어요. 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _viewReceipt(String path) async {
    try {
      final url = await _repo.receiptUrl(path);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) =>
            Dialog(child: InteractiveViewer(child: Image.network(url))),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('영수증을 열 수 없어요: $error')));
      }
    }
  }

  Future<void> _delete(TripExpense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: const Text('지출 삭제'),
        content: Text('${expense.title} 항목과 영수증을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _repo.deleteExpense(expense);
      await _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('항목을 삭제하지 못했어요: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final transfers = settleTrip(_expenses);
    final stackAmounts =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(17) > 24;
    final mine = _repo.userId;
    final outgoing = transfers.where((t) => t.fromId == mine).toList();
    final incoming = transfers.where((t) => t.toId == mine).toList();
    final total = _expenses.fold<int>(0, (sum, item) => sum + item.amount);
    return Scaffold(
      appBar: AppBar(title: const Text('여행 정산')),
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('지출 등록'),
            ),
      body: AppPageBody(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text('정산을 불러오지 못했어요: $_error'))
            : RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 20),
                    AppMetricStrip(
                      items: [(label: '전체 지출', value: _won(total))],
                    ),
                    const SizedBox(height: 24),
                    if (_expenses.any(
                      (expense) => !expense.hasCompleteShares,
                    )) ...[
                      const Text(
                        '탈퇴 등으로 참여자 정보가 없어진 지출은 송금 계산에서 제외됩니다. 해당 지출을 등록한 멤버가 삭제 후 다시 등록해 주세요. 영수증과 원래 지출 금액은 유지됩니다.',
                        style: TextStyle(color: AppColors.warning),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      '내가 보낼 돈',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (outgoing.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          '보낼 돈이 없어요.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    for (final transfer in outgoing)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: SocialAvatar(name: _name(transfer.toId)),
                        title: Text('${_name(transfer.toId)}님에게'),
                        subtitle: stackAmounts
                            ? Text(
                                _won(transfer.amount),
                                style: Theme.of(context).textTheme.titleMedium,
                              )
                            : null,
                        trailing: stackAmounts
                            ? null
                            : Text(
                                _won(transfer.amount),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      '내가 받을 돈',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (incoming.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          '받을 돈이 없어요.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    for (final transfer in incoming)
                      Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: SocialAvatar(name: _name(transfer.fromId)),
                            title: Text('${_name(transfer.fromId)}님에게서'),
                            subtitle: stackAmounts
                                ? Text(
                                    _won(transfer.amount),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  )
                                : null,
                            trailing: stackAmounts
                                ? null
                                : Text(
                                    _won(transfer.amount),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _sharing
                                  ? null
                                  : () => _requestPayment(transfer),
                              icon: SvgPicture.asset(
                                'assets/kakao_symbol.svg',
                                width: 18,
                                height: 18,
                              ),
                              label: const Text('카톡으로 요청'),
                            ),
                          ),
                        ],
                      ),
                    if (transfers.any(
                      (t) => t.fromId != mine && t.toId != mine,
                    ))
                      ExpansionTile(
                        title: const Text('동행자 간 송금'),
                        children: [
                          for (final transfer in transfers.where(
                            (t) => t.fromId != mine && t.toId != mine,
                          ))
                            ListTile(
                              title: Text(
                                '${_name(transfer.fromId)} → ${_name(transfer.toId)}',
                              ),
                              subtitle: stackAmounts
                                  ? Text(_won(transfer.amount))
                                  : null,
                              trailing: stackAmounts
                                  ? null
                                  : Text(_won(transfer.amount)),
                            ),
                        ],
                      ),
                    const SizedBox(height: 28),
                    Text(
                      '등록된 지출',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (_expenses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          '아직 등록된 지출이 없어요.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    for (final expense in _expenses)
                      AppCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              expense.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_name(expense.payerId)} 결제 · ${expense.shares.keys.map(_name).join(', ')} 분담',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _won(expense.amount),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                ),
                                if (expense.receiptPath != null)
                                  IconButton(
                                    tooltip: '영수증 보기',
                                    icon: const Icon(
                                      Icons.receipt_long_outlined,
                                    ),
                                    onPressed: () =>
                                        _viewReceipt(expense.receiptPath!),
                                  ),
                                if (expense.createdBy == _repo.userId)
                                  IconButton(
                                    tooltip: '삭제',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _delete(expense),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ExpenseEditor extends StatefulWidget {
  const _ExpenseEditor({required this.planId, required this.people});
  final String planId;
  final List<TripPerson> people;

  @override
  State<_ExpenseEditor> createState() => _ExpenseEditorState();
}

class _ExpenseEditorState extends State<_ExpenseEditor> {
  final _repo = SharedTripRepository.instance;
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _selected = <String>{};
  XFile? _photo;
  Uint8List? _photoBytes;
  bool _reviewedPhoto = false;
  String? _savedExpenseId;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.people.map((p) => p.id));
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.android ||
                    defaultTargetPlatform == TargetPlatform.iOS))
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('카메라로 촬영'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('사진에서 선택'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final photo = await ImagePicker().pickImage(source: source);
    if (photo == null || !mounted) return;
    if (await photo.length() > 10 * 1024 * 1024) {
      setState(() => _error = '영수증 사진은 10MB 이하여야 해요.');
      return;
    }
    final bytes = await photo.readAsBytes();
    if (!mounted) return;
    setState(() {
      _photo = photo;
      _photoBytes = bytes;
      _reviewedPhoto = false;
      _error = null;
    });
    if (_savedExpenseId != null) return;
    if (kIsWeb ||
        !(defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return;
    }
    final ocr = ReceiptOcrService();
    setState(() => _busy = true);
    try {
      final scan = await ocr.scan(photo.path);
      if (!mounted) return;
      setState(() {
        if (scan.merchantName != null) _title.text = scan.merchantName!;
        if (scan.totalAmount != null) _amount.text = '${scan.totalAmount}';
        if (scan.totalAmount == null) _error = '금액을 읽지 못했어요. 직접 입력해 주세요.';
      });
    } catch (_) {
      if (mounted) setState(() => _error = '영수증을 읽지 못했어요. 금액을 직접 입력해 주세요.');
    } finally {
      await ocr.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final amount = int.tryParse(_amount.text.replaceAll(',', ''));
    if (_photo != null && !_reviewedPhoto) {
      setState(() => _error = '영수증의 금액을 확인해 주세요.');
      return;
    }
    if (_title.text.trim().isEmpty ||
        amount == null ||
        amount <= 0 ||
        _selected.isEmpty) {
      setState(() => _error = '항목명, 0원보다 큰 금액, 분담자를 확인해 주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final extension = _photo?.name.split('.').last.toLowerCase();
      if (extension != null &&
          !{'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
        throw const FormatException('JPG, PNG, WEBP 사진만 올릴 수 있어요.');
      }
      final id = _savedExpenseId ??= await _repo.addExpense(
        widget.planId,
        _title.text.trim(),
        amount,
        _selected.toList(),
      );
      if (_photo != null) {
        final type = switch (extension) {
          'png' => 'image/png',
          'webp' => 'image/webp',
          _ => 'image/jpeg',
        };
        await _repo.addReceipt(
          widget.planId,
          id,
          'receipt.$extension',
          _photoBytes!,
          type,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = _savedExpenseId == null
              ? '지출을 저장하지 못했어요: $error'
              : '지출은 저장됐지만 사진을 올리지 못했어요. 다시 시도해 주세요: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('지출 등록')),
    bottomNavigationBar: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: AppStickyActionBar(
        child: FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_savedExpenseId == null ? '등록' : '사진 다시 올리기'),
        ),
      ),
    ),
    body: AppPageBody(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickPhoto,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(_photo == null ? '영수증 사진 선택' : '영수증: ${_photo!.name}'),
          ),
          if (_photoBytes != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: Image.memory(_photoBytes!, fit: BoxFit.contain),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('영수증을 보고 금액을 확인했어요'),
              value: _reviewedPhoto,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _reviewedPhoto = value ?? false),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            enabled: !_busy && _savedExpenseId == null,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: '항목명'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            enabled: !_busy && _savedExpenseId == null,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '결제 금액',
              suffixText: '원',
            ),
          ),
          const SizedBox(height: 24),
          Text('함께 나눌 사람', style: Theme.of(context).textTheme.titleMedium),
          for (final person in widget.people)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              secondary: SocialAvatar(name: person.name),
              title: Text(person.name),
              subtitle: Text('@${person.handle}'),
              value: _selected.contains(person.id),
              onChanged: _busy || _savedExpenseId != null
                  ? null
                  : (value) => setState(() {
                      if (value == true) {
                        _selected.add(person.id);
                      } else {
                        _selected.remove(person.id);
                      }
                    }),
            ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_busy) const Center(child: CircularProgressIndicator()),
        ],
      ),
    ),
  );
}

String _won(int amount) =>
    '${amount.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')}원';
