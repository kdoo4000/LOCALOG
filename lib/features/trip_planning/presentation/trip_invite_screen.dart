import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/app_dialog.dart';

import '../data/shared_trip_repository.dart';
import '../data/trip_friend_repository.dart';
import '../../../services/supabase_initializer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/premium_ui.dart';
import '../../../core/widgets/app_loading_dots.dart';
import '../../profile/presentation/social_person_tile.dart';

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
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _loading = true);
    try {
      final friends = await TripFriendRepository(supabaseClient).load();
      final query = _search.text
          .trim()
          .replaceFirst(RegExp(r'^@'), '')
          .toLowerCase();
      final people = [
        for (final p in friends.friends)
          if (p.displayName.toLowerCase().contains(query) ||
              p.handle.toLowerCase().contains(query))
            TripPerson(p.id, p.displayName, p.handle, avatarPath: p.avatarPath),
      ];
      final invited = await _repo.invitationStatuses(widget.planId);
      final members = await _repo.members(widget.planId, includePending: true);
      if (mounted) {
        setState(() {
          _people = people;
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
    final people = _people.where((p) => !_invited.containsKey(p.id)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('동행자 초대')),
      body: AppPageBody(
        child: AppLoadingOverlay(
          loading: _loading || _busy,
          semanticsLabel: '동행자 목록 처리 중',
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
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
                const Text('아직 동행자가 없어요. 친구를 초대해 보세요.'),
              for (final person in _members)
                SocialPersonTile(
                  name: person.name,
                  handle: person.handle,
                  avatarPath: person.avatarPath,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _invited[person.id] == 'pending'
                            ? '초대 대기'
                            : _invited.containsKey(person.id)
                            ? '동행자'
                            : '방장',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      if (_invited.containsKey(person.id))
                        IconButton(
                          tooltip: '초대·참여 취소',
                          onPressed: _busy ? null : () => _remove(person),
                          icon: const Icon(Icons.person_remove_outlined),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 28),
              Text('친구 초대', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: '친구 아이디 또는 이름',
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
                Text(
                  _people.isNotEmpty && _search.text.trim().isEmpty
                      ? '친구들이 이미 참여 중이거나 초대 대기 중이에요.'
                      : _search.text.trim().isEmpty
                      ? '초대할 친구가 없어요. 친구 화면에서 친구를 추가해 주세요.'
                      : '검색한 친구가 없어요.',
                ),
              for (final person in people)
                SocialPersonTile(
                  name: person.name,
                  handle: person.handle,
                  avatarPath: person.avatarPath,
                  trailing: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      backgroundColor: AppColors.primaryBlueSoft,
                    ),
                    onPressed: _busy || _loading ? null : () => _invite(person),
                    child: const Text('초대'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
