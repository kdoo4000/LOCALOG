import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../route_search/presentation/region_picker_screen.dart';
import '../data/travel_plan_repository_provider.dart';
import '../domain/travel_plan.dart';

class TravelPlanCreateScreen extends StatefulWidget {
  const TravelPlanCreateScreen({super.key, this.plan});

  final TravelPlan? plan;

  @override
  State<TravelPlanCreateScreen> createState() => _TravelPlanCreateScreenState();
}

class _TravelPlanCreateScreenState extends State<TravelPlanCreateScreen> {
  late final TextEditingController _titleController;
  final _repository = travelPlanRepository;
  DateTimeRange? _dateRange;
  List<String> _regions = const [];
  bool _saving = false;

  bool get _isEditing => widget.plan != null;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    _titleController = TextEditingController(text: plan?.title);
    _regions = plan?.effectiveRegions ?? const [];
    if (plan != null) {
      _dateRange = DateTimeRange(start: plan.startDate, end: plan.endDate);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _selectRegion() async {
    final selected = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => RegionPickerScreen(initialRegions: _regions),
      ),
    );
    if (selected != null && mounted) setState(() => _regions = selected);
  }

  Future<void> _selectDates() async {
    final now = DateTime.now();
    final existingRange = _dateRange;
    final defaultFirstDate = DateTime(now.year - 1);
    final defaultLastDate = DateTime(now.year + 3);
    final firstDate =
        existingRange != null && existingRange.start.isBefore(defaultFirstDate)
        ? existingRange.start
        : defaultFirstDate;
    final lastDate =
        existingRange != null && existingRange.end.isAfter(defaultLastDate)
        ? existingRange.end
        : defaultLastDate;
    final selected = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: _dateRange,
      helpText: '여행 날짜 선택',
      saveText: '선택',
    );
    if (selected == null || !mounted) return;
    if (selected.duration.inDays > 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('여행 계획은 최대 31일까지 만들 수 있어요.')),
      );
      return;
    }
    setState(() => _dateRange = selected);
  }

  Future<void> _save() async {
    final range = _dateRange;
    if (_regions.isEmpty || range == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('여행 지역과 날짜를 모두 선택해 주세요.')));
      return;
    }
    final primaryProvince = _regions.first.split(' > ').first;
    final title = _titleController.text.trim().isEmpty
        ? _regions.length == 1
              ? '$primaryProvince 여행'
              : '$primaryProvince 외 ${_regions.length - 1}곳 여행'
        : _titleController.text.trim();
    setState(() => _saving = true);
    try {
      final existingPlan = widget.plan;
      final plan = existingPlan == null
          ? await _repository.createPlan(
              title: title,
              regions: _regions,
              startDate: range.start,
              endDate: range.end,
            )
          : await _repository.updatePlan(
              planId: existingPlan.id,
              title: title,
              regions: _regions,
              startDate: range.start,
              endDate: range.end,
            );
      if (mounted) Navigator.of(context).pop(plan);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('여행 계획을 ${_isEditing ? '수정' : '만들'}지 못했습니다: $error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = _dateRange;
    final dayCount = range == null ? null : range.duration.inDays + 1;
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? '여행 계획 수정' : '새 여행 계획')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              _isEditing ? '여행 계획을 다듬어볼까요?' : '어디에서 며칠을 보낼까요?',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              _isEditing
                  ? '기간을 줄이면 범위 밖 일정과 루트는 삭제돼요.'
                  : '선택한 날짜마다 하루치 루트를 하나씩 계획할 수 있어요.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.gray500),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '여행 이름',
                hintText: '예: 부산 여름 여행',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            RegionSelectionField(
              regions: _regions,
              onTap: _selectRegion,
              helperText: _regions.isEmpty
                  ? '여러 시·도와 시·군·구를 선택할 수 있어요.'
                  : '${_regions.length}개 지역 선택됨',
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: AppColors.gray200),
                borderRadius: BorderRadius.circular(8),
              ),
              leading: const Icon(Icons.calendar_month_outlined),
              title: Text(
                range == null
                    ? '여행 날짜 선택'
                    : '${_dateLabel(range.start)} ~ ${_dateLabel(range.end)}',
              ),
              subtitle: dayCount == null
                  ? const Text('시작일과 종료일')
                  : Text('${dayCount - 1}박 $dayCount일'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _selectDates,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text(_isEditing ? '변경사항 저장' : '여행 계획 만들기'),
            ),
          ],
        ),
      ),
    );
  }
}

String _dateLabel(DateTime value) => '${value.month}월 ${value.day}일';
