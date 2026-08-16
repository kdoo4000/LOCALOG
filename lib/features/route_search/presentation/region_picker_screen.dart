import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/premium_ui.dart';
import '../../../core/widgets/region_chip_wrap.dart';

String? inferMostFrequentRegion(Iterable<String> addresses) {
  return inferRegionsFromAddresses(addresses).firstOrNull;
}

List<String> inferRegionsFromAddresses(Iterable<String> addresses) {
  final counts = <String, ({int count, int firstIndex})>{};
  var index = 0;
  for (final address in addresses) {
    final region = _regionFromAddress(address);
    if (region != null) {
      final previous = counts[region];
      counts[region] = (
        count: (previous?.count ?? 0) + 1,
        firstIndex: previous?.firstIndex ?? index,
      );
    }
    index += 1;
  }
  final entries = counts.entries.toList()
    ..sort((a, b) {
      final countOrder = b.value.count.compareTo(a.value.count);
      return countOrder != 0
          ? countOrder
          : a.value.firstIndex.compareTo(b.value.firstIndex);
    });
  return entries.map((entry) => entry.key).toList(growable: false);
}

String? _regionFromAddress(String address) {
  final normalized = address.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) return null;

  String? province;
  if (normalized.startsWith('광주광역시 ') ||
      normalized.startsWith('광주 ') ||
      normalized.startsWith('전라남도 ') ||
      normalized.startsWith('전남 ') ||
      normalized.startsWith('전남광주통합특별시 ')) {
    province = '전남광주통합특별시';
  } else {
    for (final entry in _provinceAliases.entries) {
      if (entry.value.any((alias) => normalized.startsWith('$alias '))) {
        province = entry.key;
        break;
      }
    }
  }
  if (province == null) return null;

  final districts = _regions[province]!;
  for (final district in districts) {
    if (normalized.split(' ').contains(district)) {
      return '$province > $district';
    }
  }
  return province;
}

const _provinceAliases = <String, List<String>>{
  '서울특별시': ['서울특별시', '서울'],
  '부산광역시': ['부산광역시', '부산'],
  '대구광역시': ['대구광역시', '대구'],
  '인천광역시': ['인천광역시', '인천'],
  '대전광역시': ['대전광역시', '대전'],
  '울산광역시': ['울산광역시', '울산'],
  '세종특별자치시': ['세종특별자치시', '세종'],
  '경기도': ['경기도', '경기'],
  '강원특별자치도': ['강원특별자치도', '강원도', '강원'],
  '충청북도': ['충청북도', '충북'],
  '충청남도': ['충청남도', '충남'],
  '전북특별자치도': ['전북특별자치도', '전라북도', '전북'],
  '경상북도': ['경상북도', '경북'],
  '경상남도': ['경상남도', '경남'],
  '제주특별자치도': ['제주특별자치도', '제주도', '제주'],
};

class RegionPickerScreen extends StatefulWidget {
  const RegionPickerScreen({super.key, this.initialRegions = const []});

  final List<String> initialRegions;

  @override
  State<RegionPickerScreen> createState() => _RegionPickerScreenState();
}

class RegionSelectionField extends StatelessWidget {
  const RegionSelectionField({
    super.key,
    required this.regions,
    required this.onTap,
    this.helperText,
    this.emptyText = '지역 선택',
  });

  final List<String> regions;
  final VoidCallback onTap;
  final String? helperText;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '지역',
          helperText: helperText,
          suffixIcon: const Icon(Icons.chevron_right),
          border: const OutlineInputBorder(),
        ),
        child: regions.isEmpty
            ? Text(emptyText, style: const TextStyle(color: AppColors.gray500))
            : Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final region in regions)
                    Chip(
                      label: Text(_regionChipLabel(region)),
                      backgroundColor: AppColors.sky,
                      side: const BorderSide(color: AppColors.primaryBlue),
                      labelStyle: const TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w800,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
      ),
    );
  }
}

class _RegionPickerScreenState extends State<RegionPickerScreen> {
  static const _allDistricts = '전체';

  String? _selectedProvince;
  late final Set<String> _selectedRegions;

  @override
  void initState() {
    super.initState();
    _selectedRegions = {...widget.initialRegions};
    final initial = widget.initialRegions.firstOrNull;
    if (initial != null) {
      for (final province in _regions.keys) {
        if (initial.startsWith(province)) {
          _selectedProvince = province;
          break;
        }
      }
    }
    _selectedProvince ??= _regions.keys.first;
  }

  void _toggleRegion(String district) {
    final province = _selectedProvince!;
    final region = district == _allDistricts
        ? province
        : '$province > $district';
    final provincePrefix = '$_selectedProvince > ';
    setState(() {
      if (_selectedRegions.remove(region)) return;

      if (district == _allDistricts) {
        _selectedRegions.remove(province);
        _selectedRegions.removeWhere(
          (selectedRegion) => selectedRegion.startsWith(provincePrefix),
        );
      } else {
        _selectedRegions
          ..remove(province)
          ..remove('$province > $_allDistricts');
      }
      if (!_selectedRegions.contains(region)) {
        _selectedRegions.add(region);
      }
    });
  }

  void _removeRegion(String region) {
    setState(() => _selectedRegions.remove(region));
  }

  int _selectedCountForProvince(String province) => _selectedRegions
      .where(
        (region) => region == province || region.startsWith('$province > '),
      )
      .length;

  void _complete() {
    Navigator.of(context).pop(List<String>.unmodifiable(_selectedRegions));
  }

  @override
  Widget build(BuildContext context) {
    final sortedDistricts = _selectedProvince == null
        ? <String>[]
        : ([..._regions[_selectedProvince!]!]..sort());
    final districts = <String>[_allDistricts, ...sortedDistricts];

    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      appBar: AppBar(title: const Text('지역 선택')),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 66),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              alignment: Alignment.centerLeft,
              child: _selectedRegions.isEmpty
                  ? const Text(
                      '방문할 지역을 선택해 주세요.',
                      style: TextStyle(color: AppColors.gray500),
                    )
                  : SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedRegions.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final region = _selectedRegions.elementAt(index);
                          return InputChip(
                            label: Text(_regionChipLabel(region)),
                            onDeleted: () => _removeRegion(region),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            backgroundColor: AppColors.surface,
                            side: const BorderSide(
                              color: AppColors.primaryBlue,
                            ),
                            labelStyle: const TextStyle(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.w800,
                            ),
                            visualDensity: VisualDensity.compact,
                          );
                        },
                      ),
                    ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 122,
                    child: ColoredBox(
                      color: AppColors.gray50,
                      child: ListView(
                        children: [
                          for (final province in _regions.keys)
                            Builder(
                              builder: (context) {
                                final count = _selectedCountForProvince(
                                  province,
                                );
                                final selected = province == _selectedProvince;
                                return Material(
                                  color: selected
                                      ? AppColors.surface
                                      : Colors.transparent,
                                  child: InkWell(
                                    onTap: () => setState(
                                      () => _selectedProvince = province,
                                    ),
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minHeight: 52,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        border: selected
                                            ? const Border(
                                                left: BorderSide(
                                                  color: AppColors.primaryBlue,
                                                  width: 3,
                                                ),
                                              )
                                            : null,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _provinceLabel(province),
                                              style: TextStyle(
                                                color: selected
                                                    ? AppColors.ink
                                                    : AppColors.gray500,
                                                fontWeight: selected
                                                    ? FontWeight.w700
                                                    : FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          if (count > 0)
                                            Text(
                                              '$count',
                                              style: const TextStyle(
                                                color: AppColors.primaryBlue,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: _selectedProvince == null
                        ? const Center(child: Text('시·도를 선택해 주세요.'))
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: districts.length,
                            separatorBuilder: (_, _) => const Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                            ),
                            itemBuilder: (context, index) {
                              final district = districts[index];
                              final region = district == _allDistricts
                                  ? _selectedProvince!
                                  : '$_selectedProvince > $district';
                              final selected = _selectedRegions.contains(
                                region,
                              );
                              return Material(
                                color: selected
                                    ? AppColors.sky.withValues(alpha: 0.45)
                                    : AppColors.surface,
                                child: ListTile(
                                  minTileHeight: 52,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                  ),
                                  title: Text(
                                    district,
                                    style: TextStyle(
                                      color: selected
                                          ? AppColors.primaryBlue
                                          : AppColors.ink,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                    ),
                                  ),
                                  trailing: selected
                                      ? const Icon(
                                          Icons.check_circle,
                                          size: 20,
                                          color: AppColors.primaryBlue,
                                        )
                                      : null,
                                  onTap: () => _toggleRegion(district),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            AppStickyActionBar(
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selectedRegions.isEmpty ? null : _complete,
                  child: const Text('다음'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _regionChipLabel(String region) {
  return compactRegionLabel(region);
}

String _provinceLabel(String province) => compactRegionLabel(province);

const _regions = <String, List<String>>{
  '서울특별시': [
    '종로구',
    '중구',
    '용산구',
    '성동구',
    '광진구',
    '동대문구',
    '중랑구',
    '성북구',
    '강북구',
    '도봉구',
    '노원구',
    '은평구',
    '서대문구',
    '마포구',
    '양천구',
    '강서구',
    '구로구',
    '금천구',
    '영등포구',
    '동작구',
    '관악구',
    '서초구',
    '강남구',
    '송파구',
    '강동구',
  ],
  '부산광역시': [
    '중구',
    '서구',
    '동구',
    '영도구',
    '부산진구',
    '동래구',
    '남구',
    '북구',
    '해운대구',
    '사하구',
    '금정구',
    '강서구',
    '연제구',
    '수영구',
    '사상구',
    '기장군',
  ],
  '대구광역시': ['중구', '동구', '서구', '남구', '북구', '수성구', '달서구', '달성군', '군위군'],
  '인천광역시': ['중구', '동구', '미추홀구', '연수구', '남동구', '부평구', '계양구', '서구', '강화군', '옹진군'],
  '대전광역시': ['동구', '중구', '서구', '유성구', '대덕구'],
  '울산광역시': ['중구', '남구', '동구', '북구', '울주군'],
  '세종특별자치시': ['세종시'],
  '경기도': [
    '수원시',
    '성남시',
    '의정부시',
    '안양시',
    '부천시',
    '광명시',
    '평택시',
    '동두천시',
    '안산시',
    '고양시',
    '과천시',
    '구리시',
    '남양주시',
    '오산시',
    '시흥시',
    '군포시',
    '의왕시',
    '하남시',
    '용인시',
    '파주시',
    '이천시',
    '안성시',
    '김포시',
    '화성시',
    '광주시',
    '양주시',
    '포천시',
    '여주시',
    '연천군',
    '가평군',
    '양평군',
  ],
  '강원특별자치도': [
    '춘천시',
    '원주시',
    '강릉시',
    '동해시',
    '태백시',
    '속초시',
    '삼척시',
    '홍천군',
    '횡성군',
    '영월군',
    '평창군',
    '정선군',
    '철원군',
    '화천군',
    '양구군',
    '인제군',
    '고성군',
    '양양군',
  ],
  '충청북도': [
    '청주시',
    '충주시',
    '제천시',
    '보은군',
    '옥천군',
    '영동군',
    '증평군',
    '진천군',
    '괴산군',
    '음성군',
    '단양군',
  ],
  '충청남도': [
    '천안시',
    '공주시',
    '보령시',
    '아산시',
    '서산시',
    '논산시',
    '계룡시',
    '당진시',
    '금산군',
    '부여군',
    '서천군',
    '청양군',
    '홍성군',
    '예산군',
    '태안군',
  ],
  '전북특별자치도': [
    '전주시',
    '군산시',
    '익산시',
    '정읍시',
    '남원시',
    '김제시',
    '완주군',
    '진안군',
    '무주군',
    '장수군',
    '임실군',
    '순창군',
    '고창군',
    '부안군',
  ],
  '전남광주통합특별시': [
    '동구',
    '서구',
    '남구',
    '북구',
    '광산구',
    '목포시',
    '여수시',
    '순천시',
    '나주시',
    '광양시',
    '담양군',
    '곡성군',
    '구례군',
    '고흥군',
    '보성군',
    '화순군',
    '장흥군',
    '강진군',
    '해남군',
    '영암군',
    '무안군',
    '함평군',
    '영광군',
    '장성군',
    '완도군',
    '진도군',
    '신안군',
  ],
  '경상북도': [
    '포항시',
    '경주시',
    '김천시',
    '안동시',
    '구미시',
    '영주시',
    '영천시',
    '상주시',
    '문경시',
    '경산시',
    '의성군',
    '청송군',
    '영양군',
    '영덕군',
    '청도군',
    '고령군',
    '성주군',
    '칠곡군',
    '예천군',
    '봉화군',
    '울진군',
    '울릉군',
  ],
  '경상남도': [
    '창원시',
    '진주시',
    '통영시',
    '사천시',
    '김해시',
    '밀양시',
    '거제시',
    '양산시',
    '의령군',
    '함안군',
    '창녕군',
    '고성군',
    '남해군',
    '하동군',
    '산청군',
    '함양군',
    '거창군',
    '합천군',
  ],
  '제주특별자치도': ['제주시', '서귀포시'],
};
