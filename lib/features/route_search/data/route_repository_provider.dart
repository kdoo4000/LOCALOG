import '../../../services/supabase_initializer.dart';
import 'mock_route_repository.dart';
import 'route_repository.dart';
import 'supabase_route_repository.dart';

RouteRepository get routeRepository => isSupabaseConfigured
    ? SupabaseRouteRepository.instance
    : const MockRouteRepository();
