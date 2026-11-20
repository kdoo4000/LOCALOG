import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/supabase_initializer.dart';
import '../../../services/kakao_invite_service.dart';
import '../../../core/widgets/kakao_button.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_loading_dots.dart';
import '../../profile/data/social_repository.dart';
import '../../profile/presentation/public_profile_screen.dart';
import '../../profile/presentation/social_person_tile.dart';
import '../data/trip_friend_repository.dart';

class TripFriendsScreen extends StatefulWidget {
  const TripFriendsScreen({super.key, this.initialMessage})
    : _searchMode = false,
      _requestsMode = false;
  const TripFriendsScreen._search()
    : initialMessage = null,
      _searchMode = true,
      _requestsMode = false;
  const TripFriendsScreen._requests()
    : initialMessage = null,
      _searchMode = false,
      _requestsMode = true;
  final String? initialMessage;
  final bool _searchMode;
  final bool _requestsMode;
  @override
  State<TripFriendsScreen> createState() => _TripFriendsScreenState();
}

class _TripFriendsScreenState extends State<TripFriendsScreen> {
  final _search = TextEditingController();
  StreamSubscription<AuthState>? _auth;
  List<SocialPerson> _friends = [], _received = [], _sent = [], _results = [];
  List<SocialPerson> _kakaoFriends = [];
  bool _loading = true, _busy = false, _consented = false, _searched = false;
  String? _message;
  TripFriendRepository get _repo => TripFriendRepository(supabaseClient);

  @override
  void initState() {
    super.initState();
    _message = widget.initialMessage;
    if (hasSupabaseSession) {
      _resumeConsent();
      _auth = supabaseClient.auth.onAuthStateChange.listen(
        (state) async {
          if (state.event != AuthChangeEvent.signedIn &&
              state.event != AuthChangeEvent.userUpdated) {
            return;
          }
          await _resumeConsent();
        },
        onError: (Object error) {
          if (mounted) {
            setState(() => _message = '카카오 동의를 완료하지 못했어요. 다시 시도해 주세요.');
          }
        },
      );
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _auth?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _resumeConsent() async {
    await TripFriendRepository.completePendingConsent(supabaseClient);
    final message = await TripFriendRepository.takeConsentResult();
    if (!mounted) return;
    if (message != null) setState(() => _message = message);
    await _reload();
  }

  Future<void> _reload() async {
    try {
      final data = await _repo.load();
      if (!mounted) return;
      setState(() {
        _friends = data.friends;
        _kakaoFriends = data.kakaoFriends;
        _received = data.received;
        _sent = data.sent;
        _consented = data.consented;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _message = '친구 목록을 불러오지 못했어요. 다시 시도해 주세요.';
        });
      }
    }
  }

  Future<void> _act(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      await _reload();
      if (mounted) setState(() => _message = success);
    } catch (_) {
      if (mounted) {
        setState(() => _message = '처리하지 못했어요. 받은 신청과 연결 상태를 확인하고 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _consent() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: const Text('카카오톡 친구 연결'),
        content: const Text(
          '카카오 친구 목록 제공에 동의한 LOCALOG 가입 친구와 자동으로 연결합니다. 친구가 되어도 비공개 로그나 여행은 공개되지 않습니다.\n\n기존 LOCALOG 계정에 연결할 카카오 계정으로 동의해 주세요. 동의하지 않아도 친구 신청은 사용할 수 있어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('나중에'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('카카오에서 동의하기'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    await _act(_repo.requestKakaoConsent, '카카오 인증을 마친 뒤 친구 목록으로 돌아와 주세요.');
  }

  Future<void> _runSearch() async {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final query = _search.text.trim();
    setState(() {
      _results = [];
      _searched = false;
      _message = null;
      _busy = query.isNotEmpty;
    });
    if (query.isEmpty) return;
    try {
      final results = await SocialRepository.instance.search(query);
      if (!mounted) return;
      setState(() {
        _results = results
            .where((p) => p.id != supabaseClient.auth.currentUser?.id)
            .toList();
        _searched = true;
      });
    } catch (_) {
      if (mounted) setState(() => _message = '검색하지 못했어요. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _invite() => _act(() async {
    final person = await SocialRepository.instance.profile(
      supabaseClient.auth.currentUser!.id,
    );
    await shareKakaoInvite(person?.displayName ?? '친구');
  }, '카카오톡에서 받을 친구나 채팅방을 선택해 주세요.');

  Widget _person(SocialPerson p, Widget? trailing) => SocialPersonTile(
    name: p.displayName,
    handle: p.handle,
    avatarPath: p.avatarPath,
    trailing: trailing,
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicProfileScreen(userId: p.id),
      ),
    ),
  );

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 4),
    child: Text(title, style: Theme.of(context).textTheme.labelLarge),
  );

  Widget _friendList(bool kakao, {bool requestsOnly = false}) {
    final kakaoIds = _kakaoFriends.map((p) => p.id).toSet();
    final people = kakao
        ? _kakaoFriends
        : _friends.where((p) => !kakaoIds.contains(p.id)).toList();
    return SafeArea(
      top: false,
      child: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          key: PageStorageKey(kakao ? 'kakao-friends' : 'app-friends'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            if (_message != null && _message!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(_message!),
              ),
            if (kakao) ...[
              if (!_loading && !_consented) ...[
                const SizedBox(height: 16),
                KakaoButton(
                  onPressed: _busy ? null : _consent,
                  label: '카카오 친구 연결',
                ),
              ],
              TextButton.icon(
                onPressed: _busy ? null : _invite,
                icon: SvgPicture.asset(
                  'assets/kakao_symbol.svg',
                  width: 20,
                  height: 20,
                ),
                label: const Text('카카오톡으로 초대'),
              ),
            ],
            if (requestsOnly && _received.isNotEmpty) ...[
              _section('받은 신청 ${_received.length}'),
              for (final p in _received)
                _person(
                  p,
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '친구 신청 거절',
                        onPressed: _busy
                            ? null
                            : () => _act(
                                () => _repo.answer(p.id, false),
                                '신청을 거절했어요.',
                              ),
                        icon: const Icon(Icons.close),
                      ),
                      IconButton(
                        tooltip: '친구 신청 수락',
                        onPressed: _busy
                            ? null
                            : () => _act(
                                () => _repo.answer(p.id, true),
                                '친구가 되었어요.',
                              ),
                        icon: const Icon(Icons.check),
                      ),
                    ],
                  ),
                ),
            ],
            if (!requestsOnly)
              _section(_loading ? '친구' : '친구 ${people.length}'),
            if (!requestsOnly)
              for (final p in people) _person(p, null),
            if (!_loading && !requestsOnly && people.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Text(
                  kakao
                      ? (_consented
                            ? '가입한 카카오 친구가 아직 없어요.'
                            : '카카오 친구를 연결해 보세요.')
                      : '사용자 검색으로 친구를 추가해 보세요.',
                  textAlign: TextAlign.center,
                ),
              ),
            if (requestsOnly && !_loading && _received.isEmpty && _sent.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Text('친구 요청이 없어요.', textAlign: TextAlign.center),
              ),
            if (requestsOnly && _sent.isNotEmpty) ...[
              const Divider(),
              _section('보낸 신청 ${_sent.length}'),
              for (final p in _sent) _person(p, const Text('수락 대기')),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget._searchMode) return _searchPage(context);
    if (widget._requestsMode) {
      return Scaffold(
        appBar: AppBar(title: const Text('친구 요청')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: AppLoadingOverlay(
              loading: _loading || _busy,
              semanticsLabel: '친구 요청 처리 중',
              child: _friendList(false, requestsOnly: true),
            ),
          ),
        ),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('친구'),
          actions: [
            IconButton(
              tooltip: '친구 요청',
              icon: Badge.count(
                count: _received.length,
                isLabelVisible: _received.isNotEmpty,
                child: const Icon(Icons.person_add_alt_1_outlined),
              ),
              onPressed: !hasSupabaseSession
                  ? null
                  : () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const TripFriendsScreen._requests(),
                        ),
                      );
                      if (mounted) await _reload();
                    },
            ),
            IconButton(
              tooltip: '사용자 검색',
              icon: const Icon(Icons.search_rounded),
              onPressed: !hasSupabaseSession
                  ? null
                  : () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const TripFriendsScreen._search(),
                        ),
                      );
                      if (mounted) await _reload();
                    },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: '카카오톡 친구'),
              Tab(text: '인앱 친구'),
            ],
          ),
        ),
        body: !hasSupabaseSession
            ? const Center(child: Text('로그인 후 친구를 관리할 수 있어요.'))
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: AppLoadingOverlay(
                    loading: _loading || _busy,
                    semanticsLabel: '친구 목록 불러오는 중',
                    child: _loading
                        ? const SizedBox.expand()
                        : TabBarView(
                            children: [_friendList(true), _friendList(false)],
                          ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _searchPage(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('사용자 검색')),
    body: !hasSupabaseSession
        ? const Center(child: Text('로그인 후 친구를 관리할 수 있어요.'))
        : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SafeArea(
                top: false,
                child: RefreshIndicator(
                  onRefresh: _reload,
                  child: AppLoadingOverlay(
                    loading: _loading || _busy,
                    semanticsLabel: '검색 처리 중',
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        TextField(
                          controller: _search,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _runSearch(),
                          decoration: InputDecoration(
                            labelText: '사용자 검색',
                            hintText: '아이디 또는 이름',
                            suffixIcon: IconButton(
                              tooltip: '검색',
                              onPressed: _busy ? null : _runSearch,
                              icon: const Icon(Icons.search),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_message != null && _message!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(_message!),
                          ),
                        if (_searched && _results.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('검색 결과가 없어요.'),
                          ),
                        for (final p in _results)
                          _person(
                            p,
                            _friends.any((f) => f.id == p.id)
                                ? const Text('친구')
                                : _received.any((f) => f.id == p.id)
                                ? const Text('받은 신청')
                                : _sent.any((f) => f.id == p.id)
                                ? const Text('수락 대기')
                                : TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _act(
                                            () => _repo.request(p.id),
                                            '친구 신청을 보냈어요.',
                                          ),
                                    child: const Text('친구 신청'),
                                  ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
  );
}
