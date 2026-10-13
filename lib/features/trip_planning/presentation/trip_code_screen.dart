import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../data/shared_trip_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/premium_ui.dart';

class TripCodeScreen extends StatefulWidget {
  const TripCodeScreen({super.key, required this.planId, required this.title});
  final String planId;
  final String title;

  @override
  State<TripCodeScreen> createState() => _TripCodeScreenState();
}

class _TripCodeScreenState extends State<TripCodeScreen> {
  TripCode? _code;
  List<TripActiveCode> _active = const [];
  bool _busy = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final codes = await SharedTripRepository.instance.activeCodes(
        widget.planId,
      );
      if (mounted) {
        setState(() {
          _active = codes;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '활성 초대를 불러오지 못했어요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final code = await SharedTripRepository.instance.createCode(
        widget.planId,
      );
      if (mounted) {
        setState(() {
          _code = code;
          _error = null;
        });
      }
      await _refresh();
    } catch (_) {
      if (mounted) setState(() => _error = '초대 코드를 만들지 못했어요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke(String codeId) async {
    setState(() => _busy = true);
    try {
      await SharedTripRepository.instance.revokeCode(codeId);
      if (mounted) {
        setState(() {
          if (_code?.id == codeId) _code = null;
          _error = null;
        });
      }
      await _refresh();
    } catch (_) {
      if (mounted) setState(() => _error = '초대를 취소하지 못했어요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('초대 코드')),
    body: AppPageBody(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: AppColors.error)),
            TextButton(
              onPressed: _busy || _loading ? null : _refresh,
              child: const Text('다시 시도'),
            ),
            const SizedBox(height: 16),
          ],
          if (_loading)
            const LinearProgressIndicator(semanticsLabel: '활성 초대 불러오는 중'),
          if (!_loading && _error == null && _active.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text('활성 초대가 없어요. 코드를 만들어 동행자에게 공유하세요.'),
            ),
          if (_code == null)
            FilledButton(
              onPressed: _busy || _loading ? null : _create,
              child: const Text('일회용 코드 만들기'),
            )
          else ...[
            AppCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.confirmation_number_outlined,
                    color: AppColors.primaryBlue,
                    size: 32,
                  ),
                  const SizedBox(height: 20),
                  SelectableText(
                    _code!.code,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      letterSpacing: 2,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '만료 ${_code!.expiresAt.toLocal().year}.${_code!.expiresAt.toLocal().month}.${_code!.expiresAt.toLocal().day}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      final box = context.findRenderObject() as RenderBox?;
                      await SharePlus.instance.share(
                        ShareParams(
                          text:
                              'LOCALOG 여행 초대 · ${widget.title}\n초대 코드: ${_code!.code}\n앱의 내 여행 → 초대 코드 입력에서 참여하세요.',
                          sharePositionOrigin: box == null
                              ? null
                              : box.localToGlobal(Offset.zero) & box.size,
                        ),
                      );
                    },
              icon: const Icon(Icons.share_outlined),
              label: const Text('공유하기'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => Clipboard.setData(ClipboardData(text: _code!.code)),
              child: const Text('코드 복사'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
              onPressed: _busy ? null : () => _revoke(_code!.id),
              child: const Text('초대 취소'),
            ),
          ],
          if (_active.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('활성 초대', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final code in _active)
              if (code.id != _code?.id)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.confirmation_number_outlined,
                    color: AppColors.primaryBlue,
                  ),
                  title: Text(
                    '만료 ${code.expiresAt.toLocal().month}.${code.expiresAt.toLocal().day}',
                  ),
                  trailing: TextButton(
                    onPressed: _busy ? null : () => _revoke(code.id),
                    child: const Text('취소'),
                  ),
                ),
          ],
        ],
      ),
    ),
  );
}

class JoinTripCodeScreen extends StatefulWidget {
  const JoinTripCodeScreen({super.key});

  @override
  State<JoinTripCodeScreen> createState() => _JoinTripCodeScreenState();
}

class _JoinTripCodeScreenState extends State<JoinTripCodeScreen> {
  final _input = TextEditingController();
  TripCodePreview? _preview;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _preview = null;
    });
    try {
      final preview = await SharedTripRepository.instance.previewCode(
        _input.text,
      );
      if (mounted) {
        setState(() {
          _preview = preview;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '사용할 수 없는 코드예요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    if (_busy || _preview == null) return;
    setState(() => _busy = true);
    try {
      final planId = await SharedTripRepository.instance.redeemCode(
        _input.text,
      );
      if (mounted) Navigator.of(context).pop(planId);
    } catch (_) {
      if (mounted) setState(() => _error = '참여하지 못했어요. 코드를 다시 확인해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('초대 코드 입력')),
    body: AppPageBody(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        children: [
          TextField(
            controller: _input,
            enabled: !_busy,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            style: const TextStyle(
              fontSize: 20,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            ),
            decoration: const InputDecoration(
              labelText: '초대 코드',
              prefixIcon: Icon(Icons.confirmation_number_outlined),
            ),
            onSubmitted: (_) => _check(),
            onChanged: (_) => setState(() {
              _preview = null;
              _error = null;
            }),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _check,
            child: const Text('확인'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          if (_preview != null) ...[
            const SizedBox(height: 24),
            AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.map_outlined,
                  color: AppColors.primaryBlue,
                ),
                title: Text(_preview!.title),
                subtitle: Text('방장 @${_preview!.ownerHandle}'),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _join,
              child: const Text('여행 참여'),
            ),
          ],
        ],
      ),
    ),
  );
}
