import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/app_dialog.dart';
import '../../../services/photo_log_draft_store.dart';

class AccountDeletionTile extends StatelessWidget {
  const AccountDeletionTile({
    super.key,
    required this.client,
    required this.onDeleted,
  });

  final SupabaseClient client;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(
      Icons.person_remove_outlined,
      color: Theme.of(context).colorScheme.error,
    ),
    title: Text(
      '회원 탈퇴',
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
    onTap: () async {
      final deleted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _AccountDeletionDialog(client: client),
      );
      if (deleted == true) onDeleted();
    },
  );
}

class _AccountDeletionDialog extends StatefulWidget {
  const _AccountDeletionDialog({required this.client});
  final SupabaseClient client;

  @override
  State<_AccountDeletionDialog> createState() => _AccountDeletionDialogState();
}

class _AccountDeletionDialogState extends State<_AccountDeletionDialog> {
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _deleted = false;
  String? _error;

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!_deleted) {
        await const PhotoLogDraftStore().delete();
        final response = await widget.client.functions.invoke(
          'delete-account',
          body: {'confirmation': '회원 탈퇴'},
        );
        if (response.status != 200 ||
            response.data is! Map ||
            response.data['deleted'] != true) {
          throw StateError('Deletion incomplete');
        }
        _deleted = true;
      }
      await widget.client.auth.signOut(scope: SignOutScope.local);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = _deleted
              ? '계정은 삭제됐습니다. 다시 시도하여 로그아웃을 완료해 주세요.'
              : '탈퇴를 완료하지 못했습니다. 일부 삭제가 진행됐을 수 있습니다. 다시 시도하면 이어서 처리합니다.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AppDialog(
      title: const Text('회원 탈퇴'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '계정, 프로필 사진, 업로드한 로그·사진·영수증과 본인의 정산 기록을 삭제합니다. 이 기기의 사진 임시 저장도 삭제합니다.',
          ),
          const SizedBox(height: 12),
          const Text(
            '소유한 여행은 참여를 수락한 다른 멤버에게 이관합니다. 여러 명이면 먼저 초대된 멤버를 우선합니다. 수락한 다른 멤버가 없는 여행은 삭제합니다. 다른 멤버의 일정과 영수증은 유지됩니다.',
          ),
          const SizedBox(height: 12),
          const Text(
            '본인의 정산 기록이 삭제되면 다른 멤버의 관련 지출은 송금 계산에서 제외되며, 다시 등록해야 합니다.',
          ),
          const SizedBox(height: 12),
          const Text(
            '삭제는 되돌릴 수 없습니다. 시작 후에는 새 업로드가 제한되며, 오류가 나면 다시 시도해 완료해 주세요.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmation,
            enabled: !_busy && !_deleted,
            decoration: const InputDecoration(
              labelText: '확인을 위해 “회원 탈퇴”를 입력해 주세요',
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy || _deleted
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed:
              !_busy && (_deleted || _confirmation.text.trim() == '회원 탈퇴')
              ? _delete
              : null,
          child: Text(
            _busy
                ? '삭제 중…'
                : _error != null
                ? '다시 시도'
                : '탈퇴하기',
          ),
        ),
      ],
    ),
  );
}
