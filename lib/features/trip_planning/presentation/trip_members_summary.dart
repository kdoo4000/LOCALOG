import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../profile/presentation/social_person_tile.dart';
import '../data/shared_trip_repository.dart';

class TripMembersSummary extends StatelessWidget {
  const TripMembersSummary({
    super.key,
    required this.members,
    required this.ownerId,
  });

  final List<TripPerson> members;
  final String? ownerId;

  void _showMembers(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: AppLayout.readingWidth),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .55,
        minChildSize: .3,
        maxChildSize: .9,
        builder: (context, controller) => ListView.builder(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          itemCount: members.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '동행자 ${members.length}명',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: '동행자 명단 닫기',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              );
            }
            final person = members[index - 1];
            return SocialPersonTile(
              name: person.name,
              handle: person.handle,
              avatarPath: person.avatarPath,
              trailing: person.id == ownerId ? const Text('방장') : null,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const Text('아직 동행자가 없어요.');
    final visible = members.take(3).toList();
    final remaining = members.length - visible.length;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduceMotion ? Duration.zero : AppMotion.standard,
      curve: AppMotion.curve,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 4 * (1 - value)),
          child: child,
        ),
      ),
      child: Semantics(
        button: true,
        label: '동행자 ${members.length}명, 전체 명단 보기',
        excludeSemantics: true,
        onTap: () => _showMembers(context),
        child: AppCard(
          onTap: () => _showMembers(context),
          child: Row(
            children: [
              SizedBox(
                width:
                    40 + 28.0 * (visible.length - 1 + (remaining > 0 ? 1 : 0)),
                height: 40,
                child: Stack(
                  children: [
                    for (var i = 0; i < visible.length; i++)
                      Positioned(
                        left: i * 28.0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceElevated,
                            shape: BoxShape.circle,
                          ),
                          child: SocialAvatar(
                            name: visible[i].name,
                            avatarPath: visible[i].avatarPath,
                            radius: 18,
                          ),
                        ),
                      ),
                    if (remaining > 0)
                      Positioned(
                        left: visible.length * 28.0,
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlueSoft,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.surfaceElevated,
                              width: 2,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '+$remaining',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: AppColors.primaryBlueDark,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${members.length}명',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '전체 보기',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
