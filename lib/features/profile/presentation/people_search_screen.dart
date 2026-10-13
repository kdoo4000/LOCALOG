import 'package:flutter/material.dart';

import '../data/social_repository.dart';
import 'public_profile_screen.dart';
import 'social_person_tile.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/premium_ui.dart';

class PeopleSearchScreen extends StatefulWidget {
  const PeopleSearchScreen({super.key});

  @override
  State<PeopleSearchScreen> createState() => _PeopleSearchScreenState();
}

class _PeopleSearchScreenState extends State<PeopleSearchScreen> {
  final _search = TextEditingController();
  List<SocialPerson> _people = const [];
  String? _error;
  bool _searching = false;
  bool _searched = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    if (_searching) return;
    setState(() => _searching = true);
    try {
      final people = await SocialRepository.instance.search(_search.text);
      if (mounted) {
        setState(() {
          _people = people;
          _error = null;
          _searched = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '사람을 찾지 못했어요. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('사람 찾기')),
    body: AppPageBody(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: '@아이디 또는 이름',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: '검색',
                icon: const Icon(Icons.arrow_forward_rounded),
                onPressed: _searching ? null : _runSearch,
              ),
            ),
            onSubmitted: (_) => _runSearch(),
          ),
          const SizedBox(height: 20),
          if (_searching) const LinearProgressIndicator(),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          if (_searched && _people.isEmpty && _error == null && !_searching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('검색 결과가 없어요.')),
            ),
          for (final person in _people)
            SocialPersonTile(
              name: person.displayName,
              handle: person.handle,
              avatarPath: person.avatarPath,
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PublicProfileScreen(userId: person.id),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class PeopleListScreen extends StatelessWidget {
  const PeopleListScreen({
    super.key,
    required this.title,
    required this.people,
  });

  final String title;
  final List<SocialPerson> people;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: AppPageBody(
      child: people.isEmpty
          ? const Center(
              child: Text(
                '아직 아무도 없어요.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              itemCount: people.length,
              itemBuilder: (context, index) {
                final person = people[index];
                return SocialPersonTile(
                  name: person.displayName,
                  handle: person.handle,
                  avatarPath: person.avatarPath,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PublicProfileScreen(userId: person.id),
                    ),
                  ),
                );
              },
            ),
    ),
  );
}
