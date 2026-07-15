import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/router/route_names.dart';
import '../../../services/supabase_initializer.dart';

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

  bool _isSignUp = false;
  bool _agreed = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (isSupabaseConfigured && supabaseClient.auth.currentSession != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openMain());
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
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
    if (_isSignUp && !_agreed) {
      _showMessage('회원가입을 위해 개인정보 수집 동의가 필요합니다.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (_isSignUp) {
        final response = await supabaseClient.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          data: {'display_name': _displayNameController.text.trim()},
        );
        if (!mounted) {
          return;
        }
        if (response.session == null) {
          setState(() => _isSignUp = false);
          _showMessage('인증 메일을 보냈습니다. 이메일 인증 후 로그인해 주세요.');
          return;
        }
      } else {
        await supabaseClient.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
      if (mounted) {
        _openMain();
      }
    } on AuthException catch (error) {
      if (mounted) {
        _showMessage(_authMessage(error.message));
      }
    } catch (error) {
      if (mounted) {
        _showMessage('로그인 처리 중 오류가 발생했습니다: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _openMain() {
    if (!mounted) {
      return;
    }
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(RouteNames.main, (route) => false);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
              children: [
                Center(
                  child: SvgPicture.asset(
                    'assets/localog_text_vertical.svg',
                    width: 156,
                    height: 156,
                    fit: BoxFit.contain,
                    semanticsLabel: 'LOCALOG',
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  _isSignUp ? 'LOCALOG 회원가입' : 'LOCALOG 로그인',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 24),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (_isSignUp) ...[
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
                      ],
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
                          if (!email.contains('@') || !email.contains('.')) {
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
                                () => _obscurePassword = !_obscurePassword,
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
                          if ((value ?? '').length < 6) {
                            return '비밀번호는 6자 이상이어야 합니다.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                if (_isSignUp) ...[
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _agreed,
                    onChanged: (value) {
                      setState(() => _agreed = value ?? false);
                    },
                    title: const Text('개인정보 수집 및 이용에 동의합니다.'),
                    controlAffinity: ListTileControlAffinity.leading,
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
                      : Text(_isSignUp ? '가입하기' : '로그인'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          setState(() => _isSignUp = !_isSignUp);
                        },
                  child: Text(_isSignUp ? '이미 계정이 있나요? 로그인' : '처음이신가요? 회원가입'),
                ),
                const Divider(height: 32),
                TextButton(
                  onPressed: _openMain,
                  child: const Text('게스트로 공개 로그 둘러보기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
  return message;
}
