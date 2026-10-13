import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/app_dialog.dart';

import '../data/shared_trip_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/premium_ui.dart';
import '../../profile/presentation/social_person_tile.dart';
import 'trip_code_screen.dart';

class TripInviteScreen extends StatefulWidget {
  const TripInviteScreen({
    super.key,
    required this.planId,
    required this.title,
  });
  final String planId;
  final String title;

  @override
  State<TripInviteScreen> createState() => _TripInviteScreenState();
}

class _TripInviteScreenState extends State<TripInviteScreen> {
  final _repo = SharedTripRepository.instance;
  final _search = TextEditingController();
  List<TripPerson> _people = [];
  Set<String> _following = {};
  Map<String, String> _invited = {};
  List<TripPerson> _members = [];
  String? _error;
  bool _busy = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final people = await _repo.searchPeople(_search.text);
      final followed = await _repo.followedPeople();
      final following = followed.map((p) => p.id).toSet();
      final invited = await _repo.invitationStatuses(widget.planId);
      final members = await _repo.members(widget.planId);
      final visible = <String, TripPerson>{
        for (final person in people) person.id: person,
      };
      for (final person in followed) {
        if (person.name.toLowerCase().contains(
          _search.text.trim().toLowerCase(),
        )) {
          visible[person.id] = person;
        }
      }
      if (mounted) {
        setState(() {
          _people = visible.values.toList();
          _following = following;
          _invited = invited;
          _members = members;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = '동행자를 불러오지 못했어요. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _invite(TripPerson person) async {
    setState(() => _busy = true);
    try {
      await _repo.invite(widget.planId, widget.title, person.id);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = '초대하지 못했어요: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _follow(TripPerson person) async {
    setState(() => _busy = true);
    try {
      await _repo.setFollowing(person.id, !_following.contains(person.id));
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = '팔로우를 바꾸지 못했어요: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(TripPerson person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: const Text('동행자 제거'),
        content: Text('${person.name}님의 초대나 참여를 취소할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('돌아가기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('제거'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.removeMember(widget.planId, person.id);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = '제거하지 못했어요: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = [..._people]
      ..sort((a, b) {
        final first = _following.contains(a.id) ? 0 : 1;
        final second = _following.contains(b.id) ? 0 : 1;
        return first.compareTo(second);
      });
    return Scaffold(
      appBar: AppBar(title: const Text('동행자 초대')),
      body: AppPageBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            AppCard(
              padding: EdgeInsets.zero,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TripCodeScreen(
                    planId: widget.planId,
                    title: widget.title,
                  ),
                ),
              ),
              child: const ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Icon(
                  Icons.ios_share_outlined,
                  color: AppColors.primaryBlue,
                ),
                title: Text('초대 코드 공유'),
                trailing: Icon(Icons.chevron_right),
              ),
            ),
            const SizedBox(height: 28),
            if (_loading)
              const LinearProgressIndicator(
                semanticsLabel: '동행자와 초대할 사람 불러오는 중',
              ),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(
                onPressed: _loading ? null : _load,
                child: const Text('다시 시도'),
              ),
            ],
            Text(
              _loading || _error != null ? '동행자' : '동행자 ${_members.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (!_loading && _error == null && _members.isEmpty)
              const Text('아직 동행자가 없어요. 아래에서 사람을 찾아 초대하세요.'),
            for (final person in _members)
              SocialPersonTile(
                name: person.name,
                handle: person.handle,
                avatarPath: person.avatarPath,
                trailing: Text(
                  _invited.containsKey(person.id) ? '동행자' : '방장',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            const SizedBox(height: 28),
            Text('초대하기', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: '@아이디 또는 이름',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: '검색',
                  onPressed: _loading || _busy ? null : _load,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
              onSubmitted: (_) => _load(),
            ),
            const SizedBox(height: 12),
            if (!_loading && _error == null && people.isEmpty)
              const Text('검색 결과가 없어요. 아이디나 이름을 바꿔 검색하세요.'),
            for (final person in people)
              SocialPersonTile(
                name: person.name,
                handle: person.handle,
                avatarPath: person.avatarPath,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        backgroundColor: AppColors.primaryBlueSoft,
                      ),
                      onPressed: _busy || _invited.containsKey(person.id)
                          ? null
                          : () => _invite(person),
                      child: Text(
                        _invited[person.id] == 'accepted'
                            ? '참여 중'
                            : _invited[person.id] == 'pending'
                            ? '대기 중'
                            : '초대',
                      ),
                    ),
                    PopupMenuButton<String>(
                      enabled: !_busy,
                      tooltip: '동행자 메뉴',
                      onSelected: (action) => action == 'follow'
                          ? _follow(person)
                          : _remove(person),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'follow',
                          child: Text(
                            _following.contains(person.id) ? '팔로우 취소' : '팔로우',
                          ),
                        ),
                        if (_invited.containsKey(person.id))
                          const PopupMenuItem(
                            value: 'remove',
                            child: Text('초대·참여 취소'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
