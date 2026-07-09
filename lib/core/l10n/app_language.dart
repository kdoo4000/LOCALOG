import 'package:flutter/material.dart';

enum AppLanguage {
  ko,
  en,
}

class AppLanguageController extends ChangeNotifier {
  AppLanguage _language = AppLanguage.ko;

  AppLanguage get language => _language;

  void setLanguage(AppLanguage language) {
    if (_language == language) {
      return;
    }

    _language = language;
    notifyListeners();
  }
}

class AppLanguageScope extends InheritedNotifier<AppLanguageController> {
  const AppLanguageScope({
    super.key,
    required AppLanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLanguageController controllerOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    assert(scope?.notifier != null, 'AppLanguageScope was not found.');
    return scope!.notifier!;
  }
}

extension AppLanguageContext on BuildContext {
  AppLanguageController get languageController =>
      AppLanguageScope.controllerOf(this);

  AppLanguage get appLanguage => languageController.language;

  AppStrings get strings => AppStrings(appLanguage);
}

class AppStrings {
  const AppStrings(this.appLanguage);

  final AppLanguage appLanguage;

  bool get isKo => appLanguage == AppLanguage.ko;

  String get appTitle => 'Like Local';

  String get korean => '한국어';
  String get english => 'English';

  String get navHome => isKo ? '홈' : 'Home';
  String get navSearch => isKo ? '검색' : 'Search';
  String get navUpload => isKo ? '업로드' : 'Upload';
  String get navMap => isKo ? '지도' : 'Map';
  String get navProfile => isKo ? '프로필' : 'Profile';

  String get mapComingTitle => isKo ? '지도' : 'Map';
  String get mapComingMessage => isKo
      ? '지도 화면은 다음 단계에서 연결할 예정입니다.'
      : 'The map screen will be connected in the next step.';

  String get homeHeroTitle => isKo ? '오늘은\n어디로 가볼까요?' : 'Where should\nwe go today?';
  String get homeLocation => isKo ? '서울, 한국' : 'Seoul, Korea';
  String get destinationComing => isKo
      ? '여행지 설정은 다음 단계에서 연결합니다.'
      : 'Destination settings will be connected in the next step.';
  String shortcutComing(String label) => isKo
      ? '$label 화면은 다음 단계에서 연결합니다.'
      : '$label will be connected in the next step.';
  String get monthlyRecommend => isKo ? '이번 달 추천 루트' : 'Monthly recommendations';
  String get shortcutRouteSearch => isKo ? '루트 검색' : 'Route Search';
  String get shortcutScanReceipt => isKo ? '영수증 스캔' : 'Scan Receipt';
  String get shortcutUploadRoute => isKo ? '루트 업로드' : 'Upload Route';
  String get shortcutDownload => isKo ? '다운로드' : 'Download';
  String get shortcutMapView => isKo ? '지도 보기' : 'Map View';
  String get shortcutNotifications => isKo ? '알림' : 'Notifications';

  String get routeSearchTitle => isKo ? '루트 검색' : 'Route Search';
  String get routeSearchHint => isKo ? '도시, 태그, 루트 검색' : 'Search city, tag, or route';
  String get noMatchingRoutes =>
      isKo ? '조건에 맞는 루트가 없습니다.' : 'No routes match your search.';
  List<String> get searchTags => isKo
      ? const ['맛집', '전망', '서점', '바다', '역사']
      : const ['Food', 'View', 'Bookstore', 'Sea', 'History'];
  List<String> searchAliases(String keyword) {
    final normalized = keyword.trim().toLowerCase();
    final aliases = <String>{normalized};
    const pairs = {
      'food': '맛집',
      'view': '전망',
      'bookstore': '서점',
      'sea': '바다',
      'history': '역사',
      'walk': '산책',
      'cafe': '카페',
      'local': '로컬',
    };

    for (final entry in pairs.entries) {
      if (normalized == entry.key) {
        aliases.add(entry.value);
      }
      if (normalized == entry.value.toLowerCase()) {
        aliases.add(entry.key);
      }
    }

    return aliases.where((alias) => alias.isNotEmpty).toList();
  }

  String get photoTitle => isKo ? '사진으로 여행 기록 만들기' : 'Build a travel log from photos';
  String get photoSubtitle => isKo
      ? '여러 장의 사진을 선택하면 날짜별로 묶고, 촬영 시간순으로 정렬해 지도에 표시합니다.'
      : 'Select multiple photos to group them by date, sort them by time, and show each day on a map.';
  String get choosePhotos => isKo ? '사진 선택' : 'Choose photos';
  String get readingPhotos => isKo ? '사진 읽는 중' : 'Reading photos';
  String photoReadFailed(Object error) =>
      isKo ? '사진 메타데이터를 읽지 못했습니다. $error' : 'Could not read photo metadata. $error';
  String get selectedPhotos => isKo ? '선택한 사진' : 'Selected photos';
  String get photos => isKo ? '사진' : 'Photos';
  String get withGps => isKo ? 'GPS 있음' : 'With GPS';
  String get withoutGps => isKo ? 'GPS 없음' : 'Without GPS';
  String get createRoute => isKo ? '루트 만들기' : 'Create route';
  String get selectPhotoDateToCreateRoute =>
      isKo ? '루트를 만들 날짜를 선택하세요.' : 'Select a photo date to create a route.';
  String routablePhotoStops(int count) =>
      isKo ? '$count개의 사진 지점을 루트로 저장할 수 있습니다.' : '$count photo stop(s) can be saved as a route.';
  String get saveSelectedDayAsRoute =>
      isKo ? '선택한 날짜를 루트로 저장' : 'Save selected day as route';
  String get savingRoute => isKo ? '루트 저장 중' : 'Saving route';
  String get chooseRoutablePhotosFirst => isKo
      ? 'GPS가 있거나 장소가 선택된 사진을 먼저 선택하세요.'
      : 'Choose photos with GPS or selected places first.';
  String get savedPhotoRouteToProfile =>
      isKo ? '사진 루트를 프로필에 저장했습니다.' : 'Saved photo route to Profile.';
  String saveRouteFailed(Object error) =>
      isKo ? '루트를 저장하지 못했습니다. $error' : 'Could not save route. $error';
  String photoRouteTitle(String dateLabel) =>
      isKo ? '사진 루트 - $dateLabel' : 'Photo route - $dateLabel';
  String photoRouteDescription(int count) =>
      isKo ? '$count개의 사진 지점으로 만든 개인 루트입니다.' : 'A personal route created from $count photo stop(s).';
  String get myTrip => isKo ? '내 여행' : 'My trip';
  String get me => isKo ? '나' : 'Me';
  String get photoTag => isKo ? '사진' : 'Photo';
  String get localTag => isKo ? '로컬' : 'Local';
  String photoStop(int index) => isKo ? '사진 지점 ${index + 1}' : 'Photo stop ${index + 1}';
  String get photoSpot => isKo ? '사진 명소' : 'Photo spot';
  String takenAtFromFile(String timeLabel, String fileName) =>
      isKo ? '$timeLabel에 촬영한 사진입니다. 파일: $fileName' : 'Taken at $timeLabel from $fileName.';
  String get timelineSuffix => isKo ? '타임라인' : 'timeline';
  String get dynamicMapSuffix => isKo ? '동적 지도' : 'dynamic map';
  String markerCount(int count) =>
      isKo ? '$count개의 마커를 촬영 시간순으로 연결했습니다.' : '$count marker(s), connected in taken-time order.';
  String get noGpsForDate =>
      isKo ? '이 날짜에는 GPS 메타데이터가 없습니다.' : 'No GPS metadata is available for this date.';
  String get emptyPhotoState => isKo
      ? '여러 장의 사진을 선택해 날짜별 그리드와 지도를 만들어보세요.'
      : 'Choose multiple photos to build a date-grouped grid and map.';
  String get photoDetails => isKo ? '사진 정보' : 'Photo details';
  String get file => isKo ? '파일' : 'File';
  String get takenAt => isKo ? '촬영 시간' : 'Taken at';
  String get latitude => isKo ? '위도' : 'Latitude';
  String get longitude => isKo ? '경도' : 'Longitude';
  String get camera => isKo ? '카메라' : 'Camera';
  String get place => isKo ? '장소' : 'Place';
  String get none => isKo ? '없음' : 'None';
  String get notSelected => isKo ? '선택 안 됨' : 'Not selected';
  String get noGpsForSuggestions => isKo
      ? '장소 추천에 사용할 GPS 메타데이터가 없습니다.'
      : 'No GPS metadata is available for place suggestions.';
  String get placeSuggestionsUnavailable => isKo
      ? '이 사진에서는 장소 추천을 사용할 수 없습니다.'
      : 'Place suggestions are not available for this photo.';
  String get suggestedPlaces => isKo ? '추천 장소' : 'Suggested places';
  String get couldNotLoadPlaceSuggestions =>
      isKo ? '장소 추천을 불러오지 못했습니다.' : 'Could not load place suggestions.';
  String get unknownDate => isKo ? '날짜 없음' : 'Unknown date';
  String get assignPlaces => isKo ? '사진별 장소 지정' : 'Assign places';
  String get assignPlacesHelp => isKo
      ? '사진을 보면서 각 지점의 장소를 확인하거나 바꿀 수 있습니다.'
      : 'Review each photo and choose or change its place.';
  String get choosePlace => isKo ? '장소 지정' : 'Choose place';
  String get changePlace => isKo ? '장소 변경' : 'Change place';
  String get enterPlaceManually => isKo ? '장소 직접 입력' : 'Enter place manually';

  String get routeDetailTitle => isKo ? '루트 상세' : 'Route Detail';
  String get routeNotFound => isKo ? '루트를 찾을 수 없습니다.' : 'Route not found.';
  String get routeSaved => isKo ? '루트를 저장했습니다.' : 'Route saved.';
  String get visitTimeline => isKo ? '방문 타임라인' : 'Visit timeline';
  String get routeMap => isKo ? '루트 지도' : 'Route map';
  String get noRouteMapPoints =>
      isKo ? '지도에 표시할 좌표가 아직 없습니다.' : 'No coordinates are available for this route yet.';
  String get editMyRoute => isKo ? '내 루트 편집' : 'Edit my route';
  String get downloadAndCustomize => isKo ? '다운로드해서 내 일정 만들기' : 'Download and customize';
  String get savedRoute => isKo ? '저장된 루트' : 'Saved route';
  String authorRoute(String authorName) =>
      isKo ? '@$authorName 님의 루트' : '@$authorName route';
  String get duration => isKo ? '소요 시간' : 'Duration';
  String durationLabel(int minutes) {
    if (minutes < 60) {
      return isKo ? '$minutes분' : '${minutes}m';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return isKo ? '$hours시간' : '${hours}h';
    }

    return isKo
        ? '$hours시간 $remainingMinutes분'
        : '${hours}h ${remainingMinutes}m';
  }

  String get upvote => isKo ? '추천' : 'Upvote';
  String get downloads => isKo ? '다운로드' : 'Downloads';

  String get editRouteTitle => isKo ? '루트 편집' : 'Edit Route';
  String get customizeYourRoute => isKo ? '내 루트 편집하기' : 'Customize your route';
  String get customizeYourRouteSubtitle => isKo
      ? '루트 이름을 바꾸고, 장소 순서를 조정하거나, 장소를 추가/삭제할 수 있습니다.'
      : 'Rename the route, reorder stops, remove places, or add another stop.';
  String get routeTitleLabel => isKo ? '루트 제목' : 'Route title';
  String get addPlace => isKo ? '장소 추가' : 'Add place';
  String get routeNeedsOnePlace =>
      isKo ? '루트에는 최소 한 곳 이상의 장소가 필요합니다.' : 'A route needs at least one place.';
  String get saveRoute => isKo ? '루트 저장' : 'Save route';
  String get saving => isKo ? '저장 중' : 'Saving';
  String get enterPlaceName => isKo ? '장소명을 입력하세요.' : 'Enter a place name.';
  String get placeName => isKo ? '장소명' : 'Place name';
  String get exampleCafe => isKo ? '예: 망원동 카페' : 'Example cafe';
  String get category => isKo ? '카테고리' : 'Category';
  String get categoryHint => isKo ? '카페, 맛집, 공원' : 'Cafe, Food, Park';
  String get address => isKo ? '주소' : 'Address';
  String get optional => isKo ? '선택 입력' : 'Optional';
  String get memo => isKo ? '메모' : 'Memo';
  String get cancel => isKo ? '취소' : 'Cancel';
  String get add => isKo ? '추가' : 'Add';
  String get moveUp => isKo ? '위로 이동' : 'Move up';
  String get moveDown => isKo ? '아래로 이동' : 'Move down';
  String get delete => isKo ? '삭제' : 'Delete';

  String get profileTitle => isKo ? '프로필' : 'Profile';
  String get language => isKo ? '언어' : 'Language';
  String get myRouteList => isKo ? '내 로컬 루트' : 'My local routes';
  String get myRouteListSubtitle => isKo
      ? '다운로드하거나 사진으로 만든 루트를 내 여행 일정으로 관리합니다.'
      : 'Manage downloaded and photo-created routes as your own travel plans.';
  String get deleteRouteTitle => isKo ? '루트 삭제' : 'Delete route';
  String deleteRouteMessage(String title) =>
      isKo ? '"$title" 루트를 프로필에서 삭제할까요?' : 'Delete "$title" from your profile?';
  String get routeDeleted => isKo ? '루트를 삭제했습니다.' : 'Route deleted.';
  String get savedRouteLabel => isKo ? '저장된 루트' : 'Saved route';
  String get emptyDownloadedRoutes => isKo
      ? '아직 저장한 루트가 없습니다. 검색이나 사진 업로드에서 마음에 드는 루트를 저장해보세요.'
      : 'No saved routes yet. Save a route from Search or photo upload.';
}
