import 'package:flutter/material.dart';

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
            Text(
              'LIKE LOCAL',
              style: Theme.of(
                context,
              ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Your best local guide',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 44),
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
