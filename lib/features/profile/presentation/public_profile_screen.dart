import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/premium_ui.dart';
import '../../../services/supabase_initializer.dart';
import '../data/social_repository.dart';
import 'people_search_screen.dart';
import 'social_profile_header.dart';
import 'social_person_tile.dart';

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({super.key, required this.userId});
  final String userId;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  late Future<_ProfileView> _future = _load();
  bool _changingFollow = false;

  Future<_ProfileView> _load() async {
    final social = SocialRepository.instance;
    final person = await social.profile(widget.userId);
    if (person == null) throw StateError('프로필을 찾을 수 없어요.');
    final currentUser = supabaseClient.auth.currentUser;
    final followers = currentUser == null
        ? <SocialPerson>[]
        : await social.followers(widget.userId);
    final following = currentUser == null
        ? <SocialPerson>[]
        : await social.following(widget.userId);
    final isFollowing = currentUser == null || currentUser.id == widget.userId
        ? null
        : await social.isFollowing(widget.userId);
    final logs = await supabaseClient
        .from('routes')
        .select('id,title')
        .eq('owner_id', widget.userId)
        .eq('access_level', 'public')
        .order('published_at', ascending: false)
        .limit(30);
    return _ProfileView(
      person,
      followers,
      following,
      isFollowing,
      currentUser?.id == widget.userId,
      logs,
    );
  }

  Future<void> _toggleFollow(bool current) async {
    if (_changingFollow) return;
    setState(() => _changingFollow = true);
    try {
      await SocialRepository.instance.setFollowing(widget.userId, !current);
      final updated = await _load();
      if (mounted) setState(() => _future = Future.value(updated));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('팔로우를 변경하지 못했어요.')));
      }
    } finally {
      if (mounted) setState(() => _changingFollow = false);
    }
  }

  Future<void> _editProfile(SocialPerson person) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProfileEditDialog(
        person: person,
        onSave: (handle, name, avatarBytes, removeAvatar) =>
            SocialRepository.instance.updateMyProfile(
              handle: handle,
              displayName: name,
              avatarBytes: avatarBytes,
              removeAvatar: removeAvatar,
            ),
      ),
    );
    if (saved == true && mounted) setState(() => _future = _load());
  }

  void _openPeople(String title, List<SocialPerson> people) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PeopleListScreen(title: title, people: people),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('프로필')),
    body: AppPageBody(
      child: FutureBuilder<_ProfileView>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    color: AppColors.textSecondary,
                    size: 32,
                  ),
                  const SizedBox(height: 16),
                  const Text('프로필을 불러오지 못했어요.'),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => setState(() => _future = _load()),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              SocialProfileHeader(
                person: data.person,
                showFollows: hasSupabaseSession,
                followersCount: data.followers.length,
                followingCount: data.following.length,
                onFollowers: () => _openPeople('팔로워', data.followers),
                onFollowing: () => _openPeople('팔로잉', data.following),
                isFollowing: data.isFollowing,
                onFollow: data.isFollowing == null || _changingFollow
                    ? null
                    : () => _toggleFollow(data.isFollowing!),
              ),
              if (data.isOwn) ...[
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () => _editProfile(data.person),
                  child: const Text('프로필 수정'),
                ),
              ],
              const SizedBox(height: 24),
              Text('공개 로그', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (data.logs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    '아직 공개한 로그가 없어요.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              for (final log in data.logs)
                AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlueSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.map_outlined,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    title: Text(log['title'] as String),
                    onTap: () => Navigator.of(context).pushNamed(
                      RouteNames.routeDetail,
                      arguments: log['id'] as String,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class ProfileEditDialog extends StatefulWidget {
  const ProfileEditDialog({
    super.key,
    required this.person,
    required this.onSave,
  });

  final SocialPerson person;
  final Future<void> Function(
    String handle,
    String displayName,
    Uint8List? avatarBytes,
    bool removeAvatar,
  )
  onSave;

  @override
  State<ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<ProfileEditDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.person.displayName);
  late final _handle = TextEditingController(text: widget.person.handle);
  bool _saving = false;
  bool _pickingPhoto = false;
  Uint8List? _avatarBytes;
  bool _removeAvatar = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _handle.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_saving || _pickingPhoto) return;
    setState(() {
      _pickingPhoto = true;
      _error = null;
    });
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      try {
        final frame = await codec.getNextFrame();
        final image = frame.image;
        try {
          final side = (image.width < image.height ? image.width : image.height)
              .toDouble();
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          canvas.drawImageRect(
            image,
            Rect.fromLTWH(
              (image.width - side) / 2,
              (image.height - side) / 2,
              side,
              side,
            ),
            const Rect.fromLTWH(0, 0, 512, 512),
            Paint()..filterQuality = FilterQuality.high,
          );
          final picture = recorder.endRecording();
          try {
            final thumbnail = await picture.toImage(512, 512);
            try {
              final data = await thumbnail.toByteData(
                format: ui.ImageByteFormat.png,
              );
              if (data == null) throw const FormatException('사진을 불러오지 못했어요.');
              if (mounted) {
                setState(() {
                  _avatarBytes = data.buffer.asUint8List(
                    data.offsetInBytes,
                    data.lengthInBytes,
                  );
                  _removeAvatar = false;
                });
              }
            } finally {
              thumbnail.dispose();
            }
          } finally {
            picture.dispose();
          }
        } finally {
          image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } catch (_) {
      if (mounted) setState(() => _error = '사진을 불러오지 못했어요. 다시 선택해 주세요.');
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _pickingPhoto || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        normalizeHandle(_handle.text),
        _name.text.trim(),
        _avatarBytes,
        _removeAvatar,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = switch (error) {
            PostgrestException(code: '23505') => '이미 사용 중인 아이디입니다.',
            PostgrestException(code: 'PGRST116') =>
              '프로필을 찾을 수 없어요. 다시 로그인해 주세요.',
            FormatException(message: final message) => message,
            _ => '프로필을 저장하지 못했어요. 다시 시도해 주세요.',
          },
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving && !_pickingPhoto,
    child: AppDialog(
      title: const Text('프로필 수정'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SocialAvatar(
                name: widget.person.displayName,
                radius: 40,
                avatarPath: _removeAvatar ? null : widget.person.avatarPath,
                imageBytes: _avatarBytes,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _saving || _pickingPhoto ? null : _pickPhoto,
                icon: _pickingPhoto
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_a_photo_outlined, size: 18),
                label: const Text('사진 변경'),
              ),
              if (_avatarBytes != null ||
                  (!_removeAvatar && widget.person.avatarPath != null))
                TextButton(
                  onPressed: _saving || _pickingPhoto
                      ? null
                      : () => setState(() {
                          _avatarBytes = null;
                          _removeAvatar = true;
                        }),
                  child: const Text('사진 삭제'),
                ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _name,
                enabled: !_saving,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: '이름'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? '이름을 입력해 주세요.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _handle,
                enabled: !_saving,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  labelText: '아이디',
                  prefixText: '@',
                ),
                validator: (value) =>
                    isValidHandle(normalizeHandle(value ?? ''))
                    ? null
                    : '아이디는 영문·숫자·점·밑줄로 3~30자 입력해 주세요.',
              ),
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
      actions: [
        TextButton(
          onPressed: _saving || _pickingPhoto
              ? null
              : () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _saving || _pickingPhoto ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('저장'),
        ),
      ],
    ),
  );
}

class _ProfileView {
  const _ProfileView(
    this.person,
    this.followers,
    this.following,
    this.isFollowing,
    this.isOwn,
    this.logs,
  );
  final SocialPerson person;
  final List<SocialPerson> followers;
  final List<SocialPerson> following;
  final bool? isFollowing;
  final bool isOwn;
  final List<Map<String, dynamic>> logs;
}
