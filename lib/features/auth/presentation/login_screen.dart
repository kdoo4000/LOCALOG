import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/router/route_names.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _agreed = false;

  void _continue() {
    if (!_agreed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('개인정보 수집 동의가 필요합니다.')));
      return;
    }

    Navigator.of(context).pushReplacementNamed(RouteNames.main);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 72),
            Align(
              alignment: Alignment.centerLeft,
              child: SvgPicture.asset(
                'assets/localog_text.svg',
                width: 240,
                height: 135,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 36),
            FilledButton(
              onPressed: _continue,
              child: const Text('Google로 계속하기'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _continue,
              child: const Text('Kakao로 계속하기'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushReplacementNamed(RouteNames.main);
              },
              child: const Text('게스트로 둘러보기'),
            ),
            const SizedBox(height: 24),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _agreed,
              onChanged: (value) {
                setState(() {
                  _agreed = value ?? false;
                });
              },
              title: const Text('개인정보 수집 및 이용에 동의합니다.'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
    );
  }
}
