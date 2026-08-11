import 'package:flutter/material.dart';

enum AppLanguage { ko, en }

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

  String get appTitle => 'LOCALOG';

  String get korean => '한국어';
  String get english => 'English';

  String get navHome => isKo ? '홈' : 'Home';
  String get navSearch => isKo ? '검색' : 'Search';
  String get navUpload => isKo ? '업로드' : 'Upload';
  String get navPlan => isKo ? '계획' : 'Plan';
  String get navMap => isKo ? '정산' : 'Split';
  String get navProfile => isKo ? '프로필' : 'Profile';

  String get mapComingTitle => isKo ? '영수증 정산' : 'Receipt settlement';
  String get mapComingMessage => isKo
      ? '영수증 이미지 업로드와 친구별 품목 배분 기능을 준비하고 있어요.'
      : 'Receipt upload and item splitting are coming soon.';

  String get homeHeroTitle =>
      isKo ? 'Where should\nwe go today?' : 'Where should\nwe go today?';
  String get homeLocation => isKo ? 'Seoul, Korea' : 'Seoul, Korea';
  String get destinationComing => isKo
      ? '여행 지역 설정은 다음 단계에서 연결할게요.'
      : 'Destination settings will be connected in the next step.';
  String shortcutComing(String label) => isKo
      ? '$label 화면은 다음 단계에서 연결할게요.'
      : '$label will be connected in the next step.';
  String get monthlyRecommend =>
      isKo ? 'July\'s local picks' : 'July\'s local picks';
  String get shortcutRouteSearch => isKo ? 'Log' : 'Log';
  String get shortcutScanReceipt => isKo ? 'Receipt' : 'Receipt';
  String get shortcutUploadRoute => isKo ? 'Upload' : 'Upload';
  String get shortcutDownload => isKo ? 'Plan' : 'Plan';
  String get shortcutMapView => isKo ? 'Map' : 'Map';
  String get shortcutNotifications => isKo ? 'Alerts' : 'Alerts';

  String get routeSearchTitle => isKo ? '어떤 로컬 로그를 찾아볼까요?' : 'Find a local log';
  String get routeSearchHint =>
      isKo ? '성수, 야경, 한식...' : 'Seongsu, night view, food...';
  String get noMatchingRoutes =>
      isKo ? '조건에 맞는 로그가 없어요.' : 'No logs match your search.';
  List<String> get searchTags => isKo
      ? const ['성수', '홍대', '야경', '궁궐', '박물관', '닭한마리', '이태원', '기념품']
      : const [
          'Seongsu',
          'Hongdae',
          'Night',
          'Palace',
          'Museum',
          'Food',
          'Itaewon',
          'Souvenir',
        ];
  List<String> searchAliases(String keyword) {
    final normalized = keyword.trim().toLowerCase();
    final aliases = <String>{normalized};
    const pairs = {
      'food': '맛집',
      'night': '야경',
      'view': '전망',
      'bookstore': '서점',
      'sea': '바다',
      'history': '역사',
      'walk': '산책',
      'cafe': '카페',
      'local': '로컬',
      'seongsu': '성수',
      'hongdae': '홍대',
      'palace': '궁궐',
      'museum': '박물관',
      'souvenir': '기념품',
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

  String get photoTitle =>
      isKo ? '여행 사진으로\n로그를 만들어 보세요' : 'Create a log from your travel photos';
  String get photoSubtitle => isKo
      ? '사진 메타데이터를 읽어 방문 장소와 순서를 분석합니다.'
      : 'Read photo metadata, sort stops by time, and review places on a map.';
  String get choosePhotos => isKo ? '여행 사진 업로드' : 'Upload trip photos';
  String get readingPhotos => isKo ? '사진 읽는 중' : 'Reading photos';
  String photoReadFailed(Object error) => isKo
      ? '사진 메타데이터를 읽지 못했어요. $error'
      : 'Could not read photo metadata. $error';
  String get selectedPhotos => isKo ? '생성된 방문 장소' : 'Generated stops';
  String get photos => isKo ? '사진' : 'Photos';
  String get withGps => isKo ? 'GPS 있음' : 'With GPS';
  String get withoutGps => isKo ? 'GPS 없음' : 'Without GPS';
  String get createRoute => isKo ? '로그 만들기' : 'Create log';
  String get selectPhotoDateToCreateRoute =>
      isKo ? '로그로 만들 날짜를 선택하세요.' : 'Select a photo date to create a log.';
  String routablePhotoStops(int count) => isKo
      ? '$count개의 사진 지점을 로그로 저장할 수 있어요.'
      : '$count photo stop(s) can be saved as a log.';
  String get saveSelectedDayAsRoute =>
      isKo ? '선택한 날짜를 로그로 저장' : 'Save selected day as log';
  String get reviewAndSaveRoute => isKo ? '검토하고 로그 저장' : 'Review and save log';
  String get routePreviewTitle => isKo ? '로그 저장 전 확인' : 'Review log';
  String get routePreviewSubtitle => isKo
      ? '제목, 방문 순서, 포함할 사진 지점을 확인하고 저장해요.'
      : 'Check the title, visit order, and photo stops before saving.';
  String get routeDescriptionLabel => isKo ? '상세 설명' : 'Description';
  String reviewPhotoStops(int count) => isKo
      ? '$count개의 사진 지점을 바로 수정하고 로그로 저장합니다.'
      : 'Edit $count photo stop(s) here and save as a log.';
  String missingPlaceWarning(int count) => isKo
      ? '장소가 지정되지 않은 사진 $count장이 있어요. 모든 사진의 장소를 지정해야 로그를 저장할 수 있습니다.'
      : '$count photo(s) do not have a selected place. Select a place for every photo before saving.';
  String get selectAllPlacesBeforeSave => isKo
      ? '모든 사진의 장소를 지정한 뒤 로그를 저장해 주세요.'
      : 'Select a place for every photo before saving the log.';
  String get includedStops => isKo ? '포함된 지점' : 'Included stops';
  String get atLeastOneStopRequired =>
      isKo ? '로그에는 최소 한 개의 지점이 필요해요.' : 'A log needs at least one stop.';
  String get savingRoute => isKo ? '로그 저장 중' : 'Saving log';
  String get chooseRoutablePhotosFirst => isKo
      ? 'GPS가 있거나 장소가 선택된 사진을 먼저 선택하세요.'
      : 'Choose photos with GPS or selected places first.';
  String get savedPhotoRouteToProfile =>
      isKo ? '사진 로그를 프로필에 저장했어요.' : 'Saved photo log to Profile.';
  String saveRouteFailed(Object error) =>
      isKo ? '로그를 저장하지 못했어요. $error' : 'Could not save log. $error';
  String photoRouteTitle(String dateLabel) =>
      isKo ? '사진 로그 - $dateLabel' : 'Photo log - $dateLabel';
  String photoRouteDescription(int count) => isKo
      ? '$count개의 사진 지점으로 만든 개인 로그입니다.'
      : 'A personal log created from $count photo stop(s).';
  String get myTrip => isKo ? '내 여행' : 'My trip';
  String get me => isKo ? '나' : 'Me';
  String get photoTag => isKo ? '사진' : 'Photo';
  String get localTag => isKo ? '로컬' : 'Local';
  String photoStop(int index) =>
      isKo ? '사진 지점 ${index + 1}' : 'Photo stop ${index + 1}';
  String get photoSpot => isKo ? '사진 명소' : 'Photo spot';
  String takenAtFromFile(String timeLabel, String fileName) => isKo
      ? '$timeLabel에 촬영한 사진입니다. 파일: $fileName'
      : 'Taken at $timeLabel from $fileName.';
  String get timelineSuffix => isKo ? '타임라인' : 'timeline';
  String get dynamicMapSuffix => isKo ? '동적 지도' : 'dynamic map';
  String markerCount(int count) => isKo
      ? '$count개의 마커를 촬영 시간순으로 연결했어요.'
      : '$count marker(s), connected in taken-time order.';
  String get noGpsForDate => isKo
      ? '이 날짜에는 GPS 메타데이터가 없어요.'
      : 'No GPS metadata is available for this date.';
  String get emptyPhotoState => isKo
      ? '여행 사진을 선택하면 방문 장소와 로그를 자동으로 정리해요.'
      : 'Choose photos to build a date-grouped log and map.';
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
      ? '장소 추천에 사용할 GPS 메타데이터가 없어요.'
      : 'No GPS metadata is available for place suggestions.';
  String get placeSuggestionsUnavailable => isKo
      ? '이 사진에서는 장소 추천을 사용할 수 없어요.'
      : 'Place suggestions are not available for this photo.';
  String get suggestedPlaces => isKo ? '추천 장소' : 'Suggested places';
  String get couldNotLoadPlaceSuggestions =>
      isKo ? '장소 추천을 불러오지 못했어요.' : 'Could not load place suggestions.';
  String get unknownDate => isKo ? '날짜 없음' : 'Unknown date';
  String get assignPlaces => isKo ? '사진별 장소 지정' : 'Assign places';
  String get assignPlacesHelp => isKo
      ? '사진을 보며 각 지점의 장소를 확인하거나 바꿀 수 있어요.'
      : 'Review each photo and choose or change its place.';
  String get choosePlace => isKo ? '장소 지정' : 'Choose place';
  String get changePlace => isKo ? '장소 변경' : 'Change place';
  String get enterPlaceManually => isKo ? '장소 직접 입력' : 'Enter place manually';
  String get searchPlace => isKo ? '장소 검색' : 'Search place';
  String placeSearchResults(String query) =>
      isKo ? '"$query" 검색 결과' : 'Results for "$query"';
  String get noMatchingPlaces => isKo ? '검색 결과가 없어요.' : 'No places were found.';

  String get routeDetailTitle => isKo ? '로그 상세' : 'Log Detail';
  String get routeNotFound => isKo ? '로그를 찾을 수 없어요.' : 'Log not found.';
  String get routeSaved => isKo ? '로그를 저장했어요.' : 'Log saved.';
  String get visitTimeline => isKo ? '방문 타임라인' : 'Visit timeline';
  String get routeMap => isKo ? '로그 지도' : 'Log map';
  String routeStopCount(int count) => isKo ? '$count곳' : '$count stops';
  String get noRouteMapPoints => isKo
      ? '지도에 표시할 좌표가 아직 없어요.'
      : 'No coordinates are available for this log yet.';
  String get mapLoadFailed =>
      isKo ? '지도를 불러오지 못했어요.' : 'Could not load the map.';
  String get naverDynamicMapKeyMissing => isKo
      ? '네이버 동적 지도 키가 설정되지 않았어요.'
      : 'Naver Dynamic Map key is not configured.';
  String get editMyRoute => isKo ? '수정하기' : 'Edit';
  String get downloadAndCustomize =>
      isKo ? '이 루트로 여행 계획하기' : 'Plan with this route';
  String get savedRoute => isKo ? '저장된 로그' : 'Saved log';
  String authorRoute(String authorName) =>
      isKo ? '@$authorName의 로그' : '@$authorName\'s log';
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
  String get downvote => isKo ? '비추천' : 'Downvote';
  String get routeVoteTitle =>
      isKo ? '이 로그가 마음에 드나요?' : 'Do you recommend this log?';
  String routeVoteRatio(int percentage) =>
      isKo ? '현재 추천율 $percentage%' : '$percentage% recommend this log';
  String get voteLoginRequired =>
      isKo ? '추천 또는 비추천하려면 로그인해 주세요.' : 'Sign in to vote on logs.';
  String get voteFailed =>
      isKo ? '추천 정보를 반영하지 못했습니다.' : 'Could not save your vote.';
  String get downloads => isKo ? '루트 참고' : 'Route uses';

  String get editRouteTitle => isKo ? '로그 편집' : 'Edit Log';
  String get customizeYourRoute => isKo ? '내 로그 편집하기' : 'Customize your log';
  String get customizeYourRouteSubtitle => isKo
      ? '로그 이름과 장소 순서를 조정하거나 장소를 추가, 삭제할 수 있어요.'
      : 'Rename the log, reorder stops, remove places, or add another stop.';
  String get routeImportPrivacyNotice => isKo
      ? '장소와 이동 순서만 가져옵니다. 원작자의 사진, 방문 시각, 메모, 비용 및 구매 내역은 저장하지 않아요.'
      : 'Only places and their order are imported. The creator\'s photos, visit times, notes, costs, and purchases are not saved.';
  String get routeTitleLabel => isKo ? '로그 이름 입력' : 'Log title';
  String get addPlace => isKo ? '장소 추가' : 'Add place';
  String get routeNeedsOnePlace =>
      isKo ? '로그에는 최소 한 곳 이상의 장소가 필요해요.' : 'A log needs at least one place.';
  String get saveRoute => isKo ? '저장' : 'Save';
  String get saving => isKo ? '저장 중' : 'Saving';
  String get enterPlaceName => isKo ? '장소명을 입력하세요.' : 'Enter a place name.';
  String get placeName => isKo ? '장소명' : 'Place name';
  String get exampleCafe => isKo ? '예: 망원동 카페' : 'Example cafe';
  String get category => isKo ? '카테고리' : 'Category';
  String get categoryHint => isKo ? '카페, 맛집, 공원' : 'Cafe, Food, Park';
  String get address => isKo ? '주소' : 'Address';
  String get optional => isKo ? '선택 입력' : 'Optional';
  String get memo => isKo ? '메모' : 'Memo';
  String get placeDescription => isKo ? '지점 설명' : 'Stop description';
  String get estimatedCost => isKo ? '예상 비용' : 'Estimated cost';
  String get estimatedCostWon => isKo ? '예상 비용(원)' : 'Estimated cost (KRW)';
  String get costHint => isKo ? '예: 12000' : 'Example: 12000';
  String get editPlace => isKo ? '장소 수정' : 'Edit place';
  String get invalidCost =>
      isKo ? '비용은 숫자로 입력하세요.' : 'Enter the cost as a number.';
  String get cancel => isKo ? '취소' : 'Cancel';
  String get close => isKo ? '닫기' : 'Close';
  String get add => isKo ? '추가' : 'Add';
  String get dragToReorder => isKo ? '끌어서 순서 변경' : 'Drag to reorder';
  String get routeEditGestureHelp => isKo
      ? '카드를 길게 눌러 순서를 바꾸고, 좌우로 밀어서 삭제할 수 있어요.'
      : 'Long-press a card to reorder it, or swipe either way to delete it.';
  String get moveUp => isKo ? '위로 이동' : 'Move up';
  String get moveDown => isKo ? '아래로 이동' : 'Move down';
  String get delete => isKo ? '삭제' : 'Delete';

  String get profileTitle => isKo ? '프로필' : 'Profile';
  String get language => isKo ? '언어 설정' : 'Language';
  String get myRouteList => isKo ? '내 로그' : 'My logs';
  String get myRouteListSubtitle => isKo
      ? '사진으로 기록한 하루치 로그를 관리해요.'
      : 'Manage the daily logs you created from your photos.';
  String get deleteRouteTitle => isKo ? '로그 삭제' : 'Delete log';
  String deleteRouteMessage(String title) =>
      isKo ? '"$title" 로그를 프로필에서 삭제할까요?' : 'Delete "$title" from your profile?';
  String get routeDeleted => isKo ? '로그를 삭제했어요.' : 'Log deleted.';
  String get savedRouteLabel => isKo ? '저장된 로그' : 'Saved log';
  String get uploadedRoutes => isKo ? '업로드한 로그' : 'Uploaded logs';
  String get downloadedRoutes => isKo ? '보관된 이전 루트' : 'Legacy saved routes';
  String get uploadedRouteLabel => isKo ? '사진으로 만든 로그' : 'Created from photos';
  String get downloadedRouteLabel => isKo ? '보관된 이전 루트' : 'Legacy saved route';
  String get emptyDownloadedRoutes => isKo
      ? '아직 만든 로그가 없어요. 사진을 업로드해 하루의 기록을 만들어보세요.'
      : 'No logs yet. Upload photos to record a day of travel.';
}
