import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/features/profile/data/social_repository.dart';
import 'package:localog/features/profile/presentation/social_profile_header.dart';

void main() {
  testWidgets('guest profile hides authenticated-only follow lists', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SocialProfileHeader(
            person: SocialPerson(
              id: 'person-1',
              displayName: '하나',
              handle: 'hana.travel',
            ),
            followersCount: 0,
            followingCount: 0,
            showFollows: false,
          ),
        ),
      ),
    );
    expect(find.text('@hana.travel'), findsOneWidget);
    expect(find.text('팔로워'), findsNothing);
    expect(find.text('팔로잉'), findsNothing);
  });
  testWidgets('profile shows handle and follower counts without email', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SocialProfileHeader(
            person: SocialPerson(
              id: 'person-1',
              displayName: '하나',
              handle: 'hana.travel',
            ),
            followersCount: 12,
            followingCount: 5,
          ),
        ),
      ),
    );
    expect(find.text('@hana.travel'), findsOneWidget);
    expect(find.text('팔로워'), findsOneWidget);
    expect(find.text('팔로잉'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.textContaining('person-1'), findsNothing);
  });
}
