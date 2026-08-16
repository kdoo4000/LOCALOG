import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/premium_ui.dart';
import '../../../models/place_candidate.dart';
import '../../../services/naver_static_map_service.dart';
import '../../../services/place_candidate_service.dart';
import '../../photo_location/naver_dynamic_map.dart';

class PlaceSearchMapScreen extends StatefulWidget {
  const PlaceSearchMapScreen({super.key});

  @override
  State<PlaceSearchMapScreen> createState() => _PlaceSearchMapScreenState();
}

class _PlaceSearchMapScreenState extends State<PlaceSearchMapScreen> {
  final _controller = TextEditingController();
  final _service = const PlaceCandidateService();
  Timer? _debounce;
  List<PlaceCandidate> _candidates = const [];
  PlaceCandidate? _selected;
  MapPoint? _mapCenter;
  bool _searching = false;
  bool _showSearchAreaButton = false;
  String? _message;
  int _requestGeneration = 0;

  List<PlaceCandidate> get _locatedCandidates =>
      _candidates.where((candidate) => candidate.hasLocation).toList();

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      _requestGeneration += 1;
      setState(() {
        _candidates = const [];
        _selected = null;
        _message = query.isEmpty ? null : '두 글자 이상 입력해 주세요.';
        _searching = false;
      });
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _search(useMapCenter: false),
    );
  }

  Future<void> _search({required bool useMapCenter}) async {
    final query = _controller.text.trim();
    if (query.length < 2) return;
    final generation = ++_requestGeneration;
    final center = useMapCenter ? _mapCenter : null;
    setState(() {
      _searching = true;
      _message = null;
      _showSearchAreaButton = false;
    });
    final result = await _service.searchByKeyword(
      query,
      latitude: center?.latitude,
      longitude: center?.longitude,
    );
    if (!mounted || generation != _requestGeneration) return;
    setState(() {
      _searching = false;
      if (!result.isSuccess) {
        _message = result.errorMessage;
        _candidates = const [];
        _selected = null;
        return;
      }
      _candidates = result.candidates;
      _selected = result.candidates.firstOrNull;
      _message = result.candidates.isEmpty ? '검색 결과가 없습니다.' : null;
    });
  }

  void _selectCandidate(PlaceCandidate candidate) {
    setState(() => _selected = candidate);
  }

  @override
  Widget build(BuildContext context) {
    final located = _locatedCandidates;
    final selectedIndex = _selected == null
        ? null
        : located.indexWhere((candidate) => candidate.id == _selected!.id);
    final normalizedSelectedIndex =
        selectedIndex != null && selectedIndex >= 0 ? selectedIndex : null;
    final mapHeight = (MediaQuery.sizeOf(context).height * .38).clamp(
      240.0,
      380.0,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('장소 검색')),
      bottomNavigationBar: AppStickyActionBar(
        child: FilledButton(
          onPressed: _selected == null
              ? null
              : () => Navigator.of(context).pop(_selected),
          child: Text(
            _selected == null ? '장소를 선택해 주세요' : '${_selected!.displayName} 추가',
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: SearchBar(
                controller: _controller,
                hintText: '장소 이름을 입력하세요',
                leading: const Icon(Icons.search),
                trailing: [
                  if (_searching)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (_controller.text.isNotEmpty)
                    IconButton(
                      tooltip: '검색어 지우기',
                      onPressed: () {
                        _controller.clear();
                        _onQueryChanged('');
                      },
                      icon: const Icon(Icons.close),
                    ),
                ],
                onChanged: (value) {
                  setState(() {});
                  _onQueryChanged(value);
                },
                onSubmitted: (_) {
                  _debounce?.cancel();
                  _search(useMapCenter: false);
                },
              ),
            ),
            SizedBox(
              height: mapHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (located.isEmpty)
                    Container(
                      color: AppColors.gray100,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _controller.text.trim().length < 2
                            ? '장소를 검색하면 지도에서 위치를 확인할 수 있어요.'
                            : _searching
                            ? '지도에 검색 결과를 표시하는 중입니다.'
                            : '지도에 표시할 위치가 없습니다.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.gray500),
                      ),
                    )
                  else
                    NaverDynamicMap(
                      points: [
                        for (final candidate in located)
                          MapPoint(
                            latitude: candidate.latitude!,
                            longitude: candidate.longitude!,
                          ),
                      ],
                      height: mapHeight,
                      connectPoints: false,
                      selectedIndex: normalizedSelectedIndex,
                      onPointTap: (index) => _selectCandidate(located[index]),
                      onCameraIdle: (center) {
                        _mapCenter = center;
                        if (!_searching && _controller.text.trim().length >= 2) {
                          setState(() => _showSearchAreaButton = true);
                        }
                      },
                    ),
                  if (_showSearchAreaButton && located.isNotEmpty)
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: FilledButton.icon(
                          onPressed: _searching
                              ? null
                              : () => _search(useMapCenter: true),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('이 지역에서 검색'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_message != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.yellow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_message!),
              ),
            Expanded(
              child: _candidates.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: _candidates.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final candidate = _candidates[index];
                        final selected = candidate.id == _selected?.id;
                        return Card(
                          color: selected ? AppColors.sky : null,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: selected
                                  ? AppColors.primaryBlue
                                  : AppColors.gray200,
                              foregroundColor: selected
                                  ? AppColors.white
                                  : AppColors.ink,
                              child: Text('${index + 1}'),
                            ),
                            title: Text(
                              candidate.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(candidate.displayDetail),
                            trailing: selected
                                ? const Icon(
                                    Icons.check_circle,
                                    color: AppColors.primaryBlue,
                                  )
                                : null,
                            onTap: () => _selectCandidate(candidate),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
