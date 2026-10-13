import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/supabase_initializer.dart';
import '../../profile/data/social_repository.dart';

class TripPerson {
  const TripPerson(this.id, this.name, this.handle, {this.avatarPath});
  final String id;
  final String name;
  final String handle;
  final String? avatarPath;
}

class TripInvitation {
  const TripInvitation(this.planId, this.title, this.inviterId);
  final String planId;
  final String title;
  final String inviterId;
}

class TripCode {
  const TripCode(this.id, this.code, this.expiresAt);
  final String id;
  final String code;
  final DateTime expiresAt;
}

class TripCodePreview {
  const TripCodePreview(this.title, this.ownerHandle);
  final String title;
  final String ownerHandle;
}

class TripActiveCode {
  const TripActiveCode(this.id, this.expiresAt);
  final String id;
  final DateTime expiresAt;
}

class TripExpense {
  const TripExpense(
    this.id,
    this.title,
    this.amount,
    this.payerId,
    this.createdBy,
    this.receiptPath,
    this.shares,
  );
  final String id;
  final String title;
  final int amount;
  final String payerId;
  final String createdBy;
  final String? receiptPath;
  final Map<String, int> shares;
}

class TripTransfer {
  const TripTransfer(this.fromId, this.toId, this.amount);
  final String fromId;
  final String toId;
  final int amount;
}

List<TripTransfer> settleTrip(List<TripExpense> expenses) {
  final balances = <String, int>{};
  for (final expense in expenses) {
    balances.update(
      expense.payerId,
      (v) => v + expense.amount,
      ifAbsent: () => expense.amount,
    );
    for (final share in expense.shares.entries) {
      balances.update(
        share.key,
        (v) => v - share.value,
        ifAbsent: () => -share.value,
      );
    }
  }
  final debtors = balances.entries.where((e) => e.value < 0).toList();
  final creditors = balances.entries.where((e) => e.value > 0).toList();
  final result = <TripTransfer>[];
  var d = 0;
  var c = 0;
  var debt = debtors.isEmpty ? 0 : -debtors.first.value;
  var credit = creditors.isEmpty ? 0 : creditors.first.value;
  while (d < debtors.length && c < creditors.length) {
    final amount = debt < credit ? debt : credit;
    result.add(TripTransfer(debtors[d].key, creditors[c].key, amount));
    debt -= amount;
    credit -= amount;
    if (debt == 0 && ++d < debtors.length) debt = -debtors[d].value;
    if (credit == 0 && ++c < creditors.length) credit = creditors[c].value;
  }
  return result;
}

class SharedTripRepository {
  SharedTripRepository._();
  static final instance = SharedTripRepository._();
  SupabaseClient get _db => supabaseClient;
  String get userId =>
      _db.auth.currentUser?.id ?? (throw StateError('로그인이 필요합니다.'));

  Future<List<TripPerson>> searchPeople(String query) async {
    if (query.trim().isNotEmpty) {
      final people = await SocialRepository.instance.search(query);
      return [
        for (final person in people)
          if (person.id != userId)
            TripPerson(
              person.id,
              person.displayName,
              person.handle,
              avatarPath: person.avatarPath,
            ),
      ];
    }
    final rows = await _db
        .from('profiles')
        .select('id,display_name,handle,avatar_path')
        .limit(30);
    return [
      for (final row in rows)
        if (row['id'] != userId)
          TripPerson(
            row['id'] as String,
            row['display_name'] as String,
            row['handle'] as String,
            avatarPath: row['avatar_path'] as String?,
          ),
    ];
  }

  Future<Set<String>> followingIds() async {
    final rows = await _db
        .from('user_follows')
        .select('followed_id')
        .eq('follower_id', userId);
    return {for (final row in rows) row['followed_id'] as String};
  }

  Future<List<TripPerson>> followedPeople() async {
    final ids = await followingIds();
    if (ids.isEmpty) return const [];
    final rows = await _db
        .from('profiles')
        .select('id,display_name,handle,avatar_path')
        .inFilter('id', ids.toList());
    return [
      for (final row in rows)
        TripPerson(
          row['id'] as String,
          row['display_name'] as String,
          row['handle'] as String,
          avatarPath: row['avatar_path'] as String?,
        ),
    ];
  }

  Future<bool> isFollowing(String personId) =>
      SocialRepository.instance.isFollowing(personId);

  Future<void> setFollowing(String personId, bool follow) =>
      SocialRepository.instance.setFollowing(personId, follow);

  Future<List<TripInvitation>> invitations() async {
    final rows = await _db
        .from('travel_plan_members')
        .select('plan_id,plan_title,invited_by')
        .eq('user_id', userId)
        .eq('status', 'pending');
    return [
      for (final row in rows)
        TripInvitation(
          row['plan_id'] as String,
          row['plan_title'] as String,
          row['invited_by'] as String,
        ),
    ];
  }

  Future<void> answerInvitation(String planId, bool accept) async {
    await _db
        .from('travel_plan_members')
        .update({'status': accept ? 'accepted' : 'declined'})
        .eq('plan_id', planId)
        .eq('user_id', userId)
        .eq('status', 'pending');
  }

  Future<List<TripPerson>> members(String planId) async {
    final plan = await _db
        .from('travel_plans')
        .select('owner_id')
        .eq('id', planId)
        .single();
    final rows = await _db
        .from('travel_plan_members')
        .select('user_id')
        .eq('plan_id', planId)
        .eq('status', 'accepted');
    final ids = <String>{
      plan['owner_id'] as String,
      for (final row in rows) row['user_id'] as String,
    };
    final profiles = await _db
        .from('profiles')
        .select('id,display_name,handle,avatar_path')
        .inFilter('id', ids.toList());
    return [
      for (final row in profiles)
        TripPerson(
          row['id'] as String,
          row['display_name'] as String,
          row['handle'] as String,
          avatarPath: row['avatar_path'] as String?,
        ),
    ];
  }

  Future<Map<String, String>> invitationStatuses(String planId) async {
    final rows = await _db
        .from('travel_plan_members')
        .select('user_id,status')
        .eq('plan_id', planId)
        .neq('status', 'declined');
    return {
      for (final row in rows) row['user_id'] as String: row['status'] as String,
    };
  }

  Future<void> invite(String planId, String title, String personId) async {
    await _db
        .from('travel_plan_members')
        .delete()
        .eq('plan_id', planId)
        .eq('user_id', personId)
        .eq('status', 'declined');
    await _db.from('travel_plan_members').insert({
      'plan_id': planId,
      'plan_title': title,
      'user_id': personId,
      'invited_by': userId,
    });
  }

  Future<void> removeMember(String planId, String personId) async {
    final removed = await _db
        .from('travel_plan_members')
        .delete()
        .eq('plan_id', planId)
        .eq('user_id', personId)
        .select('user_id');
    if (removed.isEmpty) {
      throw StateError('지출 기록이 있는 동행자는 해당 지출을 정리한 후 제거할 수 있어요.');
    }
  }

  Future<TripCode> createCode(String planId) async {
    final row = Map<String, dynamic>.from(
      await _db.rpc(
            'create_trip_invitation_code',
            params: {'p_plan_id': planId},
          )
          as Map,
    );
    return TripCode(
      row['id'] as String,
      row['code'] as String,
      DateTime.parse(row['expires_at'] as String),
    );
  }

  Future<List<TripActiveCode>> activeCodes(String planId) async {
    final rows =
        await _db.rpc(
              'active_trip_invitation_codes',
              params: {'p_plan_id': planId},
            )
            as List;
    return [
      for (final row in rows)
        TripActiveCode(
          row['id'] as String,
          DateTime.parse(row['expires_at'] as String),
        ),
    ];
  }

  Future<void> revokeCode(String codeId) =>
      _db.rpc('revoke_trip_invitation_code', params: {'p_code_id': codeId});

  Future<TripCodePreview> previewCode(String code) async {
    final row = Map<String, dynamic>.from(
      await _db.rpc(
            'preview_trip_invitation_code',
            params: {'p_code': code.trim().toLowerCase()},
          )
          as Map,
    );
    return TripCodePreview(
      row['title'] as String,
      row['owner_handle'] as String,
    );
  }

  Future<String> redeemCode(String code) async =>
      await _db.rpc(
            'redeem_trip_invitation_code',
            params: {'p_code': code.trim().toLowerCase()},
          )
          as String;

  Future<List<TripExpense>> expenses(String planId) async {
    final rows = await _db
        .from('travel_expenses')
        .select('''
      id,title,amount,payer_id,created_by,receipt_path,
      travel_expense_shares(user_id,amount)
    ''')
        .eq('plan_id', planId)
        .order('created_at');
    return [
      for (final row in rows)
        TripExpense(
          row['id'] as String,
          row['title'] as String,
          row['amount'] as int,
          row['payer_id'] as String,
          row['created_by'] as String,
          row['receipt_path'] as String?,
          {
            for (final share in row['travel_expense_shares'] as List)
              share['user_id'] as String: share['amount'] as int,
          },
        ),
    ];
  }

  Future<String> addExpense(
    String planId,
    String title,
    int amount,
    List<String> sharedWith,
  ) async {
    return await _db.rpc(
          'add_travel_expense',
          params: {
            'p_plan_id': planId,
            'p_title': title,
            'p_amount': amount,
            'p_shared_with': sharedWith,
          },
        )
        as String;
  }

  Future<void> addReceipt(
    String planId,
    String expenseId,
    String fileName,
    List<int> bytes,
    String contentType,
  ) async {
    final path = '$planId/$expenseId/$fileName';
    await _db.storage
        .from('travel-receipts')
        .uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    await _db
        .from('travel_expenses')
        .update({'receipt_path': path})
        .eq('id', expenseId)
        .eq('created_by', userId);
  }

  Future<String> receiptUrl(String path) =>
      _db.storage.from('travel-receipts').createSignedUrl(path, 300);

  Future<void> deleteExpense(TripExpense expense) async {
    if (expense.receiptPath != null) {
      await _db.storage.from('travel-receipts').remove([expense.receiptPath!]);
    }
    await _db
        .from('travel_expenses')
        .delete()
        .eq('id', expense.id)
        .eq('created_by', userId);
  }
}
