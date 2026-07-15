import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/supabase_initializer.dart';
import '../../route_search/domain/route_place.dart';
import '../domain/travel_plan.dart';
import 'travel_plan_repository.dart';

class SupabaseTravelPlanRepository implements TravelPlanRepository {
  SupabaseTravelPlanRepository._();

  static final instance = SupabaseTravelPlanRepository._();
  final SupabaseClient _client = supabaseClient;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  static const _planSelect = '''
    id, title, region_name, start_date, end_date,
    travel_plan_days(
      id, travel_date, day_index, completed_log_id,
      planned_routes(
        id, source_log_id, source_log_title, source_author_name,
        title, city, estimated_duration_minutes,
        planned_route_places(
          id, place_id, name, category, order_index, address,
          latitude, longitude
        )
      )
    )
  ''';

  User get _user {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('로그인이 필요한 기능입니다.');
    return user;
  }

  @override
  Stream<void> get plansChanged => _changes.stream;

  @override
  Future<List<TravelPlan>> getPlans() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    final rows = await _client
        .from('travel_plans')
        .select(_planSelect)
        .eq('owner_id', user.id)
        .order('start_date');
    return (rows as List).map((row) => _mapPlan(_asMap(row))).toList();
  }

  @override
  Future<TravelPlan?> getPlanById(String planId) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final row = await _client
        .from('travel_plans')
        .select(_planSelect)
        .eq('id', planId)
        .eq('owner_id', user.id)
        .maybeSingle();
    return row == null ? null : _mapPlan(_asMap(row));
  }

  @override
  Future<TravelPlan> createPlan({
    required String title,
    required String regionName,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final owner = _user;
    final row = await _client
        .from('travel_plans')
        .insert({
          'owner_id': owner.id,
          'title': title.trim(),
          'region_name': regionName.trim(),
          'start_date': _dateValue(startDate),
          'end_date': _dateValue(endDate),
        })
        .select('id')
        .single();
    final planId = row['id'] as String;
    try {
      final dayCount =
          _dateOnly(endDate).difference(_dateOnly(startDate)).inDays + 1;
      await _client.from('travel_plan_days').insert([
        for (var index = 0; index < dayCount; index++)
          {
            'plan_id': planId,
            'travel_date': _dateValue(startDate.add(Duration(days: index))),
            'day_index': index,
          },
      ]);
      final saved = await getPlanById(planId);
      if (saved == null) throw StateError('여행 계획을 다시 불러오지 못했습니다.');
      _changes.add(null);
      return saved;
    } catch (_) {
      await _client.from('travel_plans').delete().eq('id', planId);
      rethrow;
    }
  }

  @override
  Future<TravelPlan> copyLogRouteToDay({
    required String logId,
    required String planDayId,
  }) async {
    _user;
    await _client.rpc(
      'copy_log_route_to_plan_day',
      params: {'p_log_id': logId, 'p_plan_day_id': planDayId},
    );
    final day = await _client
        .from('travel_plan_days')
        .select('plan_id')
        .eq('id', planDayId)
        .single();
    final plan = await getPlanById(day['plan_id'] as String);
    if (plan == null) throw StateError('여행 계획을 다시 불러오지 못했습니다.');
    _changes.add(null);
    return plan;
  }

  @override
  Future<PlannedRoute> updatePlannedRoute(PlannedRoute route) async {
    _user;
    await _client.rpc(
      'save_planned_route',
      params: {
        'p_planned_route_id': route.id,
        'p_title': route.title.trim(),
        'p_city': route.city.trim(),
        'p_estimated_duration_minutes': route.estimatedDurationMinutes,
        'p_places': [
          for (var index = 0; index < route.places.length; index++)
            {
              'place_id': route.places[index].canonicalPlaceId,
              'name': route.places[index].name,
              'category': route.places[index].category,
              'order_index': index,
              'address': route.places[index].address,
              'latitude': route.places[index].latitude,
              'longitude': route.places[index].longitude,
            },
        ],
      },
    );
    final row = await _client
        .from('planned_routes')
        .select('''
          id, source_log_id, source_log_title, source_author_name,
          title, city, estimated_duration_minutes,
          planned_route_places(
            id, place_id, name, category, order_index, address,
            latitude, longitude
          )
        ''')
        .eq('id', route.id)
        .single();
    _changes.add(null);
    return _mapPlannedRoute(_asMap(row));
  }

  @override
  Future<void> removePlannedRoute(String plannedRouteId) async {
    _user;
    await _client.from('planned_routes').delete().eq('id', plannedRouteId);
    _changes.add(null);
  }

  @override
  Future<void> linkCompletedLog({
    required String planDayId,
    required String logId,
  }) async {
    _user;
    await _client
        .from('travel_plan_days')
        .update({'completed_log_id': logId})
        .eq('id', planDayId);
    _changes.add(null);
  }

  @override
  Future<void> deletePlan(String planId) async {
    final user = _user;
    await _client
        .from('travel_plans')
        .delete()
        .eq('id', planId)
        .eq('owner_id', user.id);
    _changes.add(null);
  }

  TravelPlan _mapPlan(Map<String, dynamic> row) {
    final dayRows =
        (row['travel_plan_days'] as List? ?? const []).map(_asMap).toList()
          ..sort(
            (a, b) => _asInt(a['day_index']).compareTo(_asInt(b['day_index'])),
          );
    return TravelPlan(
      id: row['id'] as String,
      title: row['title'] as String? ?? '',
      regionName: row['region_name'] as String? ?? '',
      startDate: _parseDate(row['start_date']),
      endDate: _parseDate(row['end_date']),
      days: [
        for (final day in dayRows)
          TravelPlanDay(
            id: day['id'] as String,
            date: _parseDate(day['travel_date']),
            dayIndex: _asInt(day['day_index']),
            completedLogId: day['completed_log_id'] as String?,
            plannedRoute: _plannedRouteFromRelation(day['planned_routes']),
          ),
      ],
    );
  }

  PlannedRoute? _plannedRouteFromRelation(dynamic value) {
    if (value is Map) return _mapPlannedRoute(_asMap(value));
    if (value is List && value.isNotEmpty) {
      return _mapPlannedRoute(_asMap(value.first));
    }
    return null;
  }

  PlannedRoute _mapPlannedRoute(Map<String, dynamic> row) {
    final placeRows =
        (row['planned_route_places'] as List? ?? const []).map(_asMap).toList()
          ..sort(
            (a, b) =>
                _asInt(a['order_index']).compareTo(_asInt(b['order_index'])),
          );
    return PlannedRoute(
      id: row['id'] as String,
      sourceLogId: row['source_log_id'] as String?,
      sourceLogTitle: row['source_log_title'] as String?,
      sourceAuthorName: row['source_author_name'] as String?,
      title: row['title'] as String? ?? '',
      city: row['city'] as String? ?? '',
      estimatedDurationMinutes: _asInt(row['estimated_duration_minutes']),
      places: [
        for (final place in placeRows)
          RoutePlace(
            id: place['id'] as String,
            canonicalPlaceId: place['place_id'] as String?,
            name: place['name'] as String? ?? '',
            category: place['category'] as String? ?? '',
            orderIndex: _asInt(place['order_index']),
            address: place['address'] as String?,
            latitude: _asDoubleOrNull(place['latitude']),
            longitude: _asDoubleOrNull(place['longitude']),
          ),
      ],
    );
  }

  static String _dateValue(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime _parseDate(dynamic value) {
    final parsed = DateTime.parse(value.toString());
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static Map<String, dynamic> _asMap(dynamic value) =>
      Map<String, dynamic>.from(value as Map);

  static int _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  static double? _asDoubleOrNull(dynamic value) => value == null
      ? null
      : value is num
      ? value.toDouble()
      : double.tryParse(value.toString());
}
