import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/photo_metadata.dart';
import '../../services/exif_metadata_reader.dart';
import '../../services/naver_static_map_service.dart';
import 'naver_dynamic_map.dart';

class PhotoLocationPage extends StatefulWidget {
  const PhotoLocationPage({super.key});

  @override
  State<PhotoLocationPage> createState() => _PhotoLocationPageState();
}

class _PhotoLocationPageState extends State<PhotoLocationPage> {
  final _picker = ImagePicker();
  final _metadataReader = ExifMetadataReader();

  List<_PhotoEntry> _entries = const [];
  String? _selectedDateKey;
  bool _isReading = false;
  String? _errorMessage;

  List<_PhotoDateGroup> get _dateGroups {
    final groupsByKey = <String, List<_PhotoEntry>>{};
    for (final entry in _entries) {
      groupsByKey.putIfAbsent(entry.dateKey, () => []).add(entry);
    }

    final groups = groupsByKey.entries.map((entry) {
      final photos = [...entry.value]..sort(_compareEntriesByTime);
      return _PhotoDateGroup(
        key: entry.key,
        label: photos.first.dateLabel,
        photos: photos,
      );
    }).toList();

    groups.sort((a, b) {
      if (a.key == _unknownDateKey) return 1;
      if (b.key == _unknownDateKey) return -1;
      return a.key.compareTo(b.key);
    });
    return groups;
  }

  _PhotoDateGroup? get _selectedGroup {
    final groups = _dateGroups;
    if (groups.isEmpty) {
      return null;
    }

    for (final group in groups) {
      if (group.key == _selectedDateKey) {
        return group;
      }
    }

    return groups.first;
  }

  Future<void> _pickPhotos() async {
    setState(() {
      _isReading = true;
      _errorMessage = null;
    });

    try {
      final photos = await _picker.pickMultiImage(requestFullMetadata: true);
      if (photos.isEmpty) {
        setState(() {
          _isReading = false;
        });
        return;
      }

      final entries = <_PhotoEntry>[];
      for (final photo in photos) {
        final metadata = await _metadataReader.read(photo);
        entries.add(_PhotoEntry(photo: photo, metadata: metadata));
      }
      entries.sort(_compareEntriesByTime);

      final firstGroupKey = entries.isEmpty ? null : entries.first.dateKey;
      setState(() {
        _entries = entries;
        _selectedDateKey = firstGroupKey;
        _isReading = false;
      });
    } catch (error) {
      setState(() {
        _isReading = false;
        _errorMessage = 'Could not read photo metadata. $error';
      });
    }
  }

  void _selectDate(String key) {
    setState(() {
      _selectedDateKey = key;
    });
  }

  void _showDetails(_PhotoEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.94,
          builder: (context, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                _PhotoPreview(photo: entry.photo, height: 320),
                const SizedBox(height: 16),
                _MetadataPanel(metadata: entry.metadata),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedGroup = _selectedGroup;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LIKE LOCAL'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Build a travel log from photos',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select multiple photos to group them by date, sort them by time, and show each day on a Naver Dynamic Map.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isReading ? null : _pickPhotos,
              icon: _isReading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_library_outlined),
              label: Text(_isReading ? 'Reading photos' : 'Choose photos'),
            ),
            const SizedBox(height: 20),
            if (_errorMessage != null) _MessagePanel(message: _errorMessage!),
            if (_entries.isEmpty)
              const _EmptyState()
            else ...[
              _SummaryPanel(entries: _entries),
              const SizedBox(height: 16),
              _DateSelector(
                groups: _dateGroups,
                selectedKey: selectedGroup?.key,
                onSelected: _selectDate,
              ),
              const SizedBox(height: 16),
              if (selectedGroup != null) ...[
                _MultiMapPanel(
                  group: selectedGroup,
                ),
                const SizedBox(height: 16),
                _PhotoGrid(
                  group: selectedGroup,
                  onPhotoTap: _showDetails,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.entries});

  final List<_PhotoEntry> entries;

  @override
  Widget build(BuildContext context) {
    final locatedCount = entries.where((entry) => entry.metadata.hasLocation).length;
    return _Panel(
      title: 'Selected photos',
      children: [
        _InfoRow(label: 'Photos', value: '${entries.length}'),
        _InfoRow(label: 'With GPS', value: '$locatedCount'),
        _InfoRow(label: 'Without GPS', value: '${entries.length - locatedCount}'),
      ],
    );
  }
}

class _DateSelector extends StatelessWidget {
  const _DateSelector({
    required this.groups,
    required this.selectedKey,
    required this.onSelected,
  });

  final List<_PhotoDateGroup> groups;
  final String? selectedKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: groups.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final group = groups[index];
          return ChoiceChip(
            label: Text('${group.label} (${group.photos.length})'),
            selected: group.key == selectedKey,
            onSelected: (_) => onSelected(group.key),
          );
        },
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.group,
    required this.onPhotoTap,
  });

  final _PhotoDateGroup group;
  final ValueChanged<_PhotoEntry> onPhotoTap;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '${group.label} timeline',
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: group.photos.length,
          itemBuilder: (context, index) {
            final entry = group.photos[index];
            return _PhotoTile(
              entry: entry,
              onTap: () => onPhotoTap(entry),
            );
          },
        ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.entry,
    required this.onTap,
  });

  final _PhotoEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black12,
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder(
              future: entry.photo.readAsBytes(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }

                return Image.memory(
                  snapshot.data!,
                  fit: BoxFit.cover,
                );
              },
            ),
            Positioned(
              left: 4,
              right: 4,
              bottom: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x8F000000),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    entry.timeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
            ),
            if (!entry.metadata.hasLocation)
              const Positioned(
                top: 4,
                right: 4,
                child: Icon(
                  Icons.location_off,
                  color: Colors.white,
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({
    required this.photo,
    this.height = 220,
  });

  final XFile photo;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: photo.readAsBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const CircularProgressIndicator(),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            snapshot.data!,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }
}

class _MetadataPanel extends StatelessWidget {
  const _MetadataPanel({required this.metadata});

  final PhotoMetadata metadata;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Photo details',
      children: [
        _InfoRow(label: 'File', value: metadata.fileName),
        _InfoRow(
          label: 'Taken at',
          value: metadata.hasTakenAt ? _formatDate(metadata.takenAt!) : 'None',
        ),
        _InfoRow(
          label: 'Latitude',
          value: metadata.latitude?.toStringAsFixed(6) ?? 'None',
        ),
        _InfoRow(
          label: 'Longitude',
          value: metadata.longitude?.toStringAsFixed(6) ?? 'None',
        ),
        _InfoRow(
          label: 'Camera',
          value: [metadata.cameraMake, metadata.cameraModel]
              .whereType<String>()
              .where((value) => value.isNotEmpty)
              .join(' ')
              .ifEmpty('None'),
        ),
      ],
    );
  }
}

class _MultiMapPanel extends StatelessWidget {
  const _MultiMapPanel({
    required this.group,
  });

  final _PhotoDateGroup group;

  @override
  Widget build(BuildContext context) {
    final points = group.photos
        .where((entry) => entry.metadata.hasLocation)
        .map(
          (entry) => MapPoint(
            latitude: entry.metadata.latitude!,
            longitude: entry.metadata.longitude!,
          ),
        )
        .toList();

    if (points.isEmpty) {
      return const _MessagePanel(
        message: 'No GPS metadata is available for this date.',
      );
    }

    return _Panel(
      title: '${group.label} dynamic map',
      children: [
        Text(
          '${points.length} marker(s), connected in taken-time order.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black54,
              ),
        ),
        const SizedBox(height: 12),
        NaverDynamicMap(points: points),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        border: Border.all(color: const Color(0xFFFFD54F)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const _MessagePanel(
      message: 'Choose multiple photos to build a date-grouped grid and map.',
    );
  }
}

class _PhotoEntry {
  const _PhotoEntry({
    required this.photo,
    required this.metadata,
  });

  final XFile photo;
  final PhotoMetadata metadata;

  String get dateKey {
    final takenAt = metadata.takenAt;
    if (takenAt == null) {
      return _unknownDateKey;
    }

    return '${takenAt.year}-${_two(takenAt.month)}-${_two(takenAt.day)}';
  }

  String get dateLabel {
    final takenAt = metadata.takenAt;
    if (takenAt == null) {
      return 'Unknown date';
    }

    return '${takenAt.year}.${_two(takenAt.month)}.${_two(takenAt.day)}';
  }

  String get timeLabel {
    final takenAt = metadata.takenAt;
    if (takenAt == null) {
      return '--:--';
    }

    return '${_two(takenAt.hour)}:${_two(takenAt.minute)}';
  }
}

class _PhotoDateGroup {
  const _PhotoDateGroup({
    required this.key,
    required this.label,
    required this.photos,
  });

  final String key;
  final String label;
  final List<_PhotoEntry> photos;
}

const _unknownDateKey = 'unknown';

int _compareEntriesByTime(_PhotoEntry a, _PhotoEntry b) {
  final aTime = a.metadata.takenAt;
  final bTime = b.metadata.takenAt;
  if (aTime == null && bTime == null) {
    return a.metadata.fileName.compareTo(b.metadata.fileName);
  }
  if (aTime == null) return 1;
  if (bTime == null) return -1;
  return aTime.compareTo(bTime);
}

String _formatDate(DateTime date) {
  return '${date.year}.${_two(date.month)}.${_two(date.day)} '
      '${_two(date.hour)}:${_two(date.minute)}';
}

String _two(int value) => value.toString().padLeft(2, '0');

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
