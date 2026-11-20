import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/app_dialog.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../services/supabase_initializer.dart';
import '../../profile/data/social_repository.dart';
import '../../../core/widgets/kakao_button.dart';
import 'existing_kakao_link_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _handleController = TextEditingController();

  bool _isSignUp = false;
  bool _termsAgreed = false;
  bool _privacyAgreed = false;
  bool _locationAgreed = false;
  bool _thirdPartyAgreed = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _isKakaoSignup = false;
  bool _isOpeningMain = false;
  bool _linkingExistingAccount = false;
  StreamSubscription<AuthState>? _authSubscription;

  bool get _showSignup => _isSignUp || _isKakaoSignup;

  @override
  void initState() {
    super.initState();
    if (isSupabaseConfigured) {
      _authSubscription = supabaseClient.auth.onAuthStateChange.listen(
        (state) {
          if (state.event == AuthChangeEvent.signedIn) _handleSignedIn();
        },
        onError: (Object error) {
          if (mounted) _showMessage('카카오 인증을 완료하지 못했습니다. 다시 시도해 주세요.');
        },
      );
      if (supabaseClient.auth.currentSession != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _handleSignedIn());
      }
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _handleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!isSupabaseConfigured) {
      _showMessage('Supabase 설정이 없어 게스트 모드만 사용할 수 있습니다.');
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_showSignup && !_requiredAgreed) {
      _showMessage('회원가입을 위해 필수 약관에 동의해 주세요.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (_showSignup) {
        final handle = normalizeHandle(_handleController.text);
        final taken = await supabaseClient
            .from('profiles')
            .select('id')
            .eq('handle', handle)
            .maybeSingle();
        if (taken != null &&
            taken['id'] != supabaseClient.auth.currentUser?.id) {
          _showMessage('이미 사용 중인 아이디입니다.');
          return;
        }
        if (_isKakaoSignup) {
          await SocialRepository.instance
              .updateMyProfile(
                handle: handle,
                displayName: _displayNameController.text.trim(),
              )
              .timeout(const Duration(seconds: 10));
          await supabaseClient.auth
              .updateUser(
                UserAttributes(
                  data: {
                    'display_name': _displayNameController.text.trim(),
                    'handle': handle,
                    'terms_version': _termsVersion,
                    'terms_agreed_at': DateTime.now().toUtc().toIso8601String(),
                    'third_party_agreed': _thirdPartyAgreed,
                  },
                ),
              )
              .timeout(const Duration(seconds: 10));
          _openMain();
          return;
        }
        final response = await supabaseClient.auth
            .signUp(
              email: _emailController.text.trim(),
              password: _passwordController.text,
              data: {
                'display_name': _displayNameController.text.trim(),
                'handle': handle,
                'terms_version': _termsVersion,
                'terms_agreed_at': DateTime.now().toUtc().toIso8601String(),
                'third_party_agreed': _thirdPartyAgreed,
              },
            )
            .timeout(const Duration(seconds: 10));
        if (!mounted) {
          return;
        }
        if (response.session == null) {
          setState(() => _isSignUp = false);
          _showMessage('인증 메일을 보냈습니다. 이메일 인증 후 로그인해 주세요.');
          return;
        }
      } else {
        await supabaseClient.auth
            .signInWithPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            )
            .timeout(const Duration(seconds: 10));
      }
      if (mounted) {
        _openMain();
      }
    } on TimeoutException {
      if (mounted) {
        _showMessage('인증 서버에 연결하지 못했습니다. 인터넷 연결을 확인하고 다시 시도해 주세요.');
      }
    } on AuthException catch (error) {
      if (mounted) {
        _showMessage(_authMessage(error.message));
      }
    } catch (_) {
      if (mounted) {
        _showMessage('로그인 처리 중 오류가 발생했습니다. 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _handleSignedIn() {
    if (!mounted || _linkingExistingAccount) return;
    final user = supabaseClient.auth.currentUser;
    if (user == null) return;
    if (needsKakaoSignup(user)) {
      if (_isKakaoSignup) return;
      final metadata = user.userMetadata ?? {};
      _displayNameController.text =
          [metadata['display_name'], metadata['name'], metadata['nickname']]
              .whereType<String>()
              .firstOrNull ??
          '';
      _handleController.text = switch (metadata['handle']) {
        String handle => handle,
        _ => '',
      };
      setState(() {
        _isKakaoSignup = true;
        _isSubmitting = false;
      });
    } else {
      _openMain();
    }
  }

  Future<void> _signInWithKakao() async {
    if (!isSupabaseConfigured) {
      _showMessage('Supabase 설정이 없어 카카오 로그인을 사용할 수 없습니다.');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final launched = await supabaseClient.auth
          .signInWithOAuth(
            OAuthProvider.kakao,
            redirectTo: kIsWeb ? '${Uri.base.origin}/' : mobileAuthRedirectUrl,
            // Kakao email access requires a Biz App; signup also supports no email.
            queryParams: const {'scope': 'profile_nickname profile_image'},
            authScreenLaunchMode: LaunchMode.externalApplication,
          )
          .timeout(const Duration(seconds: 10));
      if (!launched && mounted) {
        _showMessage('카카오 로그인 화면을 열지 못했습니다. 다시 시도해 주세요.');
      }
    } catch (_) {
      if (mounted) _showMessage('카카오 로그인을 시작하지 못했습니다. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _chooseKakaoLogin() async {
    if (!isSupabaseConfigured) return _signInWithKakao();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (prefs.getBool(kakaoLoginSeenKey) == true) return _signInWithKakao();
    final existing = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: const Text('기존 LOCALOG 계정이 있나요?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('기존 계정 연결하기'),
            ),
            const SizedBox(height: 12),
            KakaoButton(
              label: '카카오 로그인',
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
    if (!mounted || existing == null) return;
    if (!existing) return _signInWithKakao();
    _linkingExistingAccount = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ExistingKakaoLinkScreen(client: supabaseClient),
        ),
      );
    } finally {
      _linkingExistingAccount = false;
    }
    if (mounted && supabaseClient.auth.currentUser != null) _handleSignedIn();
  }

  void _openMain() {
    if (!mounted || _isOpeningMain) {
      return;
    }
    _isOpeningMain = true;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(RouteNames.main, (route) => false);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool get _requiredAgreed => _termsAgreed && _privacyAgreed && _locationAgreed;

  void _setAllAgreements(bool value) {
    setState(() {
      _termsAgreed = value;
      _privacyAgreed = value;
      _locationAgreed = value;
      _thirdPartyAgreed = value;
    });
  }

  Future<void> _showAgreement(String title, String body) {
    return showDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Widget _agreementTile({
    required String title,
    required String body,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: value,
      onChanged: onChanged,
      title: Text(title),
      subtitle: Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => _showAgreement(title, body),
          child: const Text('자세히 보기'),
        ),
      ),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.warmBackground, AppColors.primaryBlueSoft],
            begin: Alignment.topCenter,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
                children: [
                  Center(
                    child: SvgPicture.asset(
                      'assets/localog_text_vertical.svg',
                      width: 84,
                      height: 84,
                      fit: BoxFit.contain,
                      colorFilter: const ColorFilter.mode(
                        AppColors.primaryBlue,
                        BlendMode.srcIn,
                      ),
                      semanticsLabel: 'LOCALOG',
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isKakaoSignup
                        ? '카카오 회원가입 마무리'
                        : _isSignUp
                        ? 'LOCALOG 회원가입'
                        : 'LOCALOG 로그인',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated.withValues(alpha: .94),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Form(
                      key: _formKey,
                      child: AnimatedSize(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : AppMotion.standard,
                        curve: AppMotion.curve,
                        child: Column(
                          children: [
                            if (_showSignup) ...[
                              TextFormField(
                                controller: _displayNameController,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: '닉네임',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return '닉네임을 입력해 주세요.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _handleController,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: '아이디',
                                  prefixText: '@',
                                ),
                                validator: (value) =>
                                    isValidHandle(normalizeHandle(value ?? ''))
                                    ? null
                                    : '영문 대소문자·숫자·._를 사용해 3~30자로 입력해 주세요.',
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (!_isKakaoSignup) ...[
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                decoration: const InputDecoration(
                                  labelText: '이메일',
                                  prefixIcon: Icon(Icons.mail_outline),
                                ),
                                validator: (value) {
                                  final email = value?.trim() ?? '';
                                  if (!email.contains('@') ||
                                      !email.contains('.')) {
                                    return '올바른 이메일 주소를 입력해 주세요.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: '비밀번호',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      );
                                    },
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if ((value ?? '').length < 8) {
                                    return '비밀번호는 8자 이상이어야 합니다.';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_showSignup) ...[
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _requiredAgreed && _thirdPartyAgreed,
                      onChanged: (value) => _setAllAgreements(value ?? false),
                      title: const Text('전체 동의'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const Divider(height: 1),
                    _agreementTile(
                      title: '[필수] 서비스 이용약관',
                      body: _serviceTerms,
                      value: _termsAgreed,
                      onChanged: (value) =>
                          setState(() => _termsAgreed = value ?? false),
                    ),
                    _agreementTile(
                      title: '[필수] 개인정보 수집 및 이용 동의',
                      body: _privacyTerms,
                      value: _privacyAgreed,
                      onChanged: (value) =>
                          setState(() => _privacyAgreed = value ?? false),
                    ),
                    _agreementTile(
                      title: '[필수] 위치정보 수집 및 이용 동의',
                      body: _locationTerms,
                      value: _locationAgreed,
                      onChanged: (value) =>
                          setState(() => _locationAgreed = value ?? false),
                    ),
                    _agreementTile(
                      title: '[선택] 개인정보 제3자 제공 동의',
                      body: _thirdPartyTerms,
                      value: _thirdPartyAgreed,
                      onChanged: (value) =>
                          setState(() => _thirdPartyAgreed = value ?? false),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_showSignup ? '가입하기' : '로그인'),
                  ),
                  if (!_isKakaoSignup) ...[
                    const SizedBox(height: 12),
                    KakaoButton(
                      key: const ValueKey('kakao-login-button'),
                      label: '카카오 로그인',
                      onPressed: _isSubmitting ? null : _chooseKakaoLogin,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              setState(() => _isSignUp = !_isSignUp);
                            },
                      child: Text(
                        _isSignUp ? '이메일로 로그인' : '이메일로 회원가입',
                      ),
                    ),
                    const Divider(height: 32),
                    TextButton(
                      onPressed: _openMain,
                      child: const Text('게스트로 공개 로그 둘러보기'),
                    ),
                  ] else
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () async {
                              try {
                                await supabaseClient.auth.signOut();
                                if (mounted) {
                                  setState(() {
                                    _isKakaoSignup = false;
                                    _isSignUp = false;
                                    _termsAgreed = false;
                                    _privacyAgreed = false;
                                    _locationAgreed = false;
                                    _thirdPartyAgreed = false;
                                  });
                                }
                              } catch (_) {
                                if (mounted) {
                                  _showMessage('로그아웃하지 못했습니다. 다시 시도해 주세요.');
                                }
                              }
                            },
                      child: const Text('로그아웃'),
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

const _termsVersion = '2026-09-11';

const _serviceTerms = '''
로컬로그(Localog)는 사진, 리뷰 및 이동 경로를 저장·공유하는 서비스를 제공합니다.

이용자가 작성·업로드한 사진, 리뷰, 경로 등의 저작권은 이용자에게 있습니다. 이용자는 서비스 제공, 저장, 표시 및 이용자가 선택한 공유 범위 내 배포를 위해 필요한 범위에서 로컬로그가 해당 콘텐츠를 이용하는 것에 동의합니다. 로컬로그는 별도 동의 없이 공개 범위를 넘어 콘텐츠를 광고 등에 사용하지 않습니다.

이용자는 타인의 권리를 침해하거나 불법적인 콘텐츠를 게시해서는 안 됩니다. 회원 탈퇴 시 계정과 콘텐츠는 관련 법령에 따른 보존 의무가 없는 한 파기됩니다.
''';

const _privacyTerms = '''
수집 항목: 이메일, 닉네임, 서비스 이용기록(접속 로그), 영수증 스캔 데이터의 구매 품목·일시·가격

수집·이용 목적: 회원 가입·관리 및 본인 확인, 영수증 스캔을 통한 지출 정산·예상 VAT 환급액 계산, 이용자 동선 아카이빙 및 맞춤형 로컬 루트 추천

보유·이용 기간: 회원 탈퇴 시 지체 없이 파기합니다. 다만, 관련 법령에 따라 보존해야 하는 정보는 해당 기간 동안 보관합니다.

동의를 거부할 권리가 있습니다. 다만, 필수 항목 동의를 거부하면 회원 가입 및 영수증 정산·동선 시각화 서비스 이용이 제한될 수 있습니다.
''';

const _locationTerms = '''
수집 항목: 앱 이용 중 스마트폰 GPS 정보, 이용자가 업로드한 사진의 EXIF 메타데이터에 포함된 위치정보

이용 목적: 사진 메타데이터를 활용한 실제 이동 경로 시각화, 현재 위치 기반 로컬 상점 추천 및 길 안내

보유·이용 기간: 위치정보 수집·이용·제공사실 확인자료는 관련 법령에 따라 6개월간 보관 후 파기합니다. 이용자가 동선 아카이빙을 위해 저장한 정보는 회원 탈퇴 시까지 보관됩니다.

동의를 거부할 권리가 있으며, 거부 시 사진 기반 지도 경로 생성 및 현재 위치 기반 기능을 이용할 수 없습니다.
''';

const _thirdPartyTerms = '''
제공받는 자: 제휴 지자체 및 관광 데이터 파트너사(제휴 확정 시 각 제공받는 자를 구체적으로 안내합니다.)

제공 목적: 지역 상권 분석, 로컬 관광 트렌드 리포트 생성 및 관광 정책 수립

제공 항목: 가명 처리된 이용자 식별자, 지역 내 방문 매장 정보, 소비 품목 및 금액

보유·이용 기간: 제공 목적 달성 시 또는 제공일로부터 1년

동의하지 않아도 더치페이 정산과 로컬 루트 확인 등 기본 서비스는 정상적으로 이용할 수 있습니다. 제공 전 대상과 목적을 투명하게 안내하고 동의를 받겠습니다.
''';

String _authMessage(String message) {
  final normalized = message.toLowerCase();
  if (normalized.contains('invalid login credentials')) {
    return '이메일 또는 비밀번호가 올바르지 않습니다.';
  }
  if (normalized.contains('email not confirmed')) {
    return '이메일 인증을 완료한 뒤 로그인해 주세요.';
  }
  if (normalized.contains('already registered')) {
    return '이미 가입된 이메일입니다.';
  }
  return '인증을 완료하지 못했습니다. 다시 시도해 주세요.';
}
