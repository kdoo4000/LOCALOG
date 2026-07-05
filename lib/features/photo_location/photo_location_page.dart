import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/photo_metadata.dart';
import '../../services/exif_metadata_reader.dart';
import '../../services/naver_static_map_service.dart';

class PhotoLocationPage extends StatefulWidget {
  const PhotoLocationPage({super.key});

  @override
  State<PhotoLocationPage> createState() => _PhotoLocationPageState();
}

class _PhotoLocationPageState extends State<PhotoLocationPage> {
  final _picker = ImagePicker();
  final _metadataReader = ExifMetadataReader();
  final _staticMapService = const NaverStaticMapService();

  XFile? _photo;
  PhotoMetadata? _metadata;
  bool _isReading = false;
  String? _errorMessage;

  Future<void> _pickPhoto() async {
    setState(() {
      _isReading = true;
      _errorMessage = null;
    });

    try {
      final photo = await _picker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: true,
      );

      if (photo == null) {
        setState(() {
          _isReading = false;
        });
        return;
      }

      final metadata = await _metadataReader.read(photo);
      setState(() {
        _photo = photo;
        _metadata = metadata;
        _isReading = false;
      });
    } catch (error) {
      setState(() {
        _isReading = false;
        _errorMessage = 'Could not read photo metadata. $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final metadata = _metadata;

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
              'Load travel location from a photo',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a photo, read its EXIF date and GPS coordinates, then show the spot on a Naver Static Map.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isReading ? null : _pickPhoto,
              icon: _isReading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_isReading ? 'Reading' : 'Choose photo'),
            ),
            const SizedBox(height: 20),
            if (_errorMessage != null) _MessagePanel(message: _errorMessage!),
            if (_photo != null) ...[
              _PhotoPreview(photo: _photo!),
              const SizedBox(height: 16),
            ],
            if (metadata != null) ...[
              _MetadataPanel(metadata: metadata),
              const SizedBox(height: 16),
              _MapPanel(
                metadata: metadata,
                staticMapService: _staticMapService,
              ),
            ] else
              const _EmptyState(),
          ],
        ),
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.photo});

  final XFile photo;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: photo.readAsBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 220,
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
            height: 220,
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
      title: 'Photo metadata',
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

  String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}.${two(date.month)}.${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
  }
}

class _MapPanel extends StatelessWidget {
  const _MapPanel({
    required this.metadata,
    required this.staticMapService,
  });

  final PhotoMetadata metadata;
  final NaverStaticMapService staticMapService;

  @override
  Widget build(BuildContext context) {
    if (!metadata.hasLocation) {
      return const _MessagePanel(
        message: 'This photo has no GPS metadata. Add a manual location fallback next.',
      );
    }

    if (!staticMapService.isConfigured) {
      return const _MessagePanel(
        message: 'Naver Static Map keys are not configured. Run the app with NAVER_MAP_CLIENT_ID and NAVER_MAP_CLIENT_SECRET.',
      );
    }

    return _Panel(
      title: 'Naver Static Map',
      children: [
        FutureBuilder(
          future: staticMapService.fetchMap(
            latitude: metadata.latitude!,
            longitude: metadata.longitude!,
          ),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Container(
                height: 220,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const CircularProgressIndicator(),
              );
            }

            final result = snapshot.data!;
            if (!result.hasImage) {
              return _MapError(message: result.errorMessage ?? 'Unknown map error.');
            }

            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                result.bytes!,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _MapError extends StatelessWidget {
  const _MapError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
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
      message: 'Choose a photo to show its taken date, GPS coordinates, and map preview.',
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
