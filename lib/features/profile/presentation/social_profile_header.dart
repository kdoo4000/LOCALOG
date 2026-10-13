import 'package:flutter/material.dart';

import '../data/social_repository.dart';
import '../../../core/theme/app_colors.dart';
import 'social_person_tile.dart';

class SocialProfileHeader extends StatelessWidget {
  const SocialProfileHeader({
    super.key,
    required this.person,
    required this.followersCount,
    required this.followingCount,
    this.showFollows = true,
    this.onFollowers,
    this.onFollowing,
    this.isFollowing,
    this.onFollow,
    this.onAvatarTap,
  });

  final SocialPerson person;
  final int followersCount;
  final int followingCount;
  final bool showFollows;
  final VoidCallback? onFollowers;
  final VoidCallback? onFollowing;
  final bool? isFollowing;
  final VoidCallback? onFollow;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Tooltip(
            message: onAvatarTap == null
                ? '${person.displayName} 프로필 사진'
                : '프로필 사진 변경',
            child: InkWell(
              onTap: onAvatarTap,
              borderRadius: BorderRadius.circular(36),
              child: Stack(
                children: [
                  SocialAvatar(
                    name: person.displayName,
                    avatarPath: person.avatarPath,
                    radius: 36,
                  ),
                  if (onAvatarTap != null)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          size: 14,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${person.handle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      if (showFollows) const SizedBox(height: 20),
      if (showFollows)
        Row(
          children: [
            Expanded(
              child: ProfileStat(
                label: '팔로워',
                value: '$followersCount',
                onTap: onFollowers,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ProfileStat(
                label: '팔로잉',
                value: '$followingCount',
                onTap: onFollowing,
              ),
            ),
          ],
        ),
      if (isFollowing != null) ...[
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: isFollowing!
              ? OutlinedButton(onPressed: onFollow, child: const Text('팔로잉'))
              : FilledButton(onPressed: onFollow, child: const Text('팔로우')),
        ),
      ],
    ],
  );
}

class ProfileStat extends StatelessWidget {
  const ProfileStat({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label $value',
    button: onTap != null,
    excludeSemantics: true,
    onTap: onTap,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
