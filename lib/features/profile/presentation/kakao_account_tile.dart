import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/supabase_initializer.dart';
import '../../../core/widgets/kakao_button.dart';

class KakaoAccountTile extends StatefulWidget {
  const KakaoAccountTile({super.key, required this.client, this.onLinked});

  final SupabaseClient client;
  final VoidCallback? onLinked;

  @override
  State<KakaoAccountTile> createState() => _KakaoAccountTileState();
}

class _KakaoAccountTileState extends State<KakaoAccountTile> {
  StreamSubscription<AuthState>? _subscription;
  List<UserIdentity>? _identities;
  bool _busy = true;
  String? _message;

  bool get _linked =>
      _identities?.any((identity) => identity.provider == 'kakao') == true;

  @override
  void initState() {
    super.initState();
    _refresh();
    _subscription = widget.client.auth.onAuthStateChange.listen(
      (_) => _refresh(),
      onError: (Object error) {
        if (mounted) {
          setState(() {
            _busy = false;
            _message = '카카오 연동을 완료하지 못했습니다. 다른 계정에 연결된 카카오인지 확인해 주세요.';
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final identities = await widget.client.auth.getUserIdentities().timeout(
        const Duration(seconds: 10),
      );
      if (!mounted) return;
      setState(() {
        _identities = identities;
        _busy = false;
        _message = null;
      });
      if (_linked) widget.onLinked?.call();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = '계정 연동 상태를 확인하지 못했습니다. 다시 확인해 주세요.';
      });
    }
  }

  Future<void> _link() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final launched = await widget.client.auth
          .linkIdentity(
            OAuthProvider.kakao,
            redirectTo: kIsWeb ? '${Uri.base.origin}/' : mobileAuthRedirectUrl,
            queryParams: const {'scope': 'profile_nickname profile_image'},
            authScreenLaunchMode: LaunchMode.externalApplication,
          )
          .timeout(const Duration(seconds: 10));
      if (!launched && mounted) {
        setState(() => _message = '카카오 인증 화면을 열지 못했습니다. 다시 시도해 주세요.');
      }
    } on AuthException catch (error) {
      if (mounted) {
        setState(() {
          _message = error.code == 'identity_already_exists'
              ? '이미 다른 LOCALOG 계정에 연결된 카카오입니다. 계정은 자동으로 합쳐지지 않습니다.'
              : '카카오 연동을 시작하지 못했습니다. 다시 시도해 주세요.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = '카카오 연동을 시작하지 못했습니다. 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_busy)
            const Center(
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  semanticsLabel: '카카오 연동 확인 중',
                ),
              ),
            )
          else if (_linked)
            const Row(
              children: [
                Icon(Icons.check_circle_outline, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('카카오 연동됨')),
              ],
            )
          else
            KakaoButton(
              label: _identities == null ? '다시 확인' : '카카오 계정 연결',
              onPressed: _identities == null ? _refresh : _link,
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _message!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}
