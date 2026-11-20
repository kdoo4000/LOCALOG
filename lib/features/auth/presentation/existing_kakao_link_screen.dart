import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../profile/presentation/kakao_account_tile.dart';

const kakaoLoginSeenKey = 'kakao_login_seen';
const kakaoLinkPendingUserKey = 'kakao_link_pending_user';

class ExistingKakaoLinkScreen extends StatefulWidget {
  const ExistingKakaoLinkScreen({super.key, required this.client});
  final SupabaseClient client;
  @override
  State<ExistingKakaoLinkScreen> createState() =>
      _ExistingKakaoLinkScreenState();
}

class _ExistingKakaoLinkScreenState extends State<ExistingKakaoLinkScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false, _linked = false, _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final code = Uri.base.queryParameters['error_code'];
    if (code != null) {
      _error = code == 'identity_already_exists'
          ? '이미 다른 LOCALOG 계정에 연결된 카카오는 연동할 수 없어요.'
          : '카카오 연결을 완료하지 못했어요. 다시 시도해 주세요.';
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await widget.client.auth
          .signInWithPassword(
            email: _email.text.trim(),
            password: _password.text,
          )
          .timeout(const Duration(seconds: 10));
      final user = response.user;
      if (user == null) throw StateError('No authenticated user');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kakaoLinkPendingUserKey, user.id);
      _password.clear();
    } on AuthException {
      if (mounted) setState(() => _error = '이메일과 비밀번호를 확인해 주세요.');
    } catch (_) {
      if (mounted) setState(() => _error = '로그인하지 못했어요. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kakaoLinkPendingUserKey);
      if (_linked) await prefs.setBool(kakaoLoginSeenKey, true);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '완료하지 못했어요. 다시 시도해 주세요.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.client.auth.currentUser;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('기존 계정 연결'),
          leading: IconButton(
            tooltip: '뒤로',
            onPressed: _busy ? null : _finish,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    user == null ? '기존 계정으로 로그인' : '카카오를 연결하세요',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (user == null) ...[
                    AutofillGroup(
                      child: Form(
                        key: _form,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _email,
                              enabled: !_busy,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: '이메일',
                              ),
                              validator: (value) => (value ?? '').contains('@')
                                  ? null
                                  : '이메일을 입력해 주세요.',
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _password,
                              enabled: !_busy,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) => _signIn(),
                              decoration: InputDecoration(
                                labelText: '비밀번호',
                                suffixIcon: IconButton(
                                  tooltip: _obscure ? '비밀번호 보기' : '비밀번호 숨기기',
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) => (value ?? '').isEmpty
                                  ? '비밀번호를 입력해 주세요.'
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _signIn,
                      child: Text(_busy ? '로그인 중…' : '로그인'),
                    ),
                  ] else ...[
                    Text(
                      user.email ?? '로그인된 계정',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    KakaoAccountTile(
                      client: widget.client,
                      onLinked: () {
                        if (mounted && !_linked) setState(() => _linked = true);
                      },
                    ),
                    const SizedBox(height: 24),
                    if (_linked)
                      FilledButton(
                        onPressed: _busy ? null : _finish,
                        child: const Text('시작하기'),
                      )
                    else
                      TextButton(
                        onPressed: _busy ? null : _finish,
                        child: const Text('나중에 연결하기'),
                      ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
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
