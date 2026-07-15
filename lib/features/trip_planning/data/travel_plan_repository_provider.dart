import '../../../services/supabase_initializer.dart';
import 'mock_travel_plan_repository.dart';
import 'supabase_travel_plan_repository.dart';
import 'travel_plan_repository.dart';

TravelPlanRepository get travelPlanRepository => isSupabaseConfigured
    ? SupabaseTravelPlanRepository.instance
    : MockTravelPlanRepository.instance;
