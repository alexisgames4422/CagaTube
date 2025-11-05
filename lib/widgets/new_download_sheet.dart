import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/download_models.dart';

class NewDownloadSheet extends StatefulWidget {
  const NewDownloadSheet({
    super.key,
    required this.onSubmit,
  });

  final Future<void> Function(String url, DownloadOptions options) onSubmit;

  @override
  State<NewDownloadSheet> createState() => _NewDownloadSheetState();
}

class _NewDownloadSheetState extends State<NewDownloadSheet> {
  final TextEditingController _urlController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  DownloadCategory _category = DownloadCategory.audio;
  AudioFormat _audioFormat = AudioFormat.mp3;
  VideoFormat _videoFormat = VideoFormat.mp4;
  QualityOption _quality = QualityOption.audio320;
  bool _embedMetadata = true;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
    });

    final url = _urlController.text.trim();
    final options = DownloadOptions(
      category: _category,
      quality: _quality,
      audioFormat: _audioFormat,
      videoFormat: _videoFormat,
      embedMetadata: _embedMetadata,
    );

    try {
      await widget.onSubmit(url, options);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Descarga añadida a la cola'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _onCategoryChanged(DownloadCategory category) {
    setState(() {
      _category = category;
      _quality = QualityOption.byCategory(category).first;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    final qualityOptions = QualityOption.byCategory(_category);

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.outlineVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nueva descarga',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'URL de YouTube o playlist',
                      hintText: 'https://youtube.com/... ',
                      prefixIcon: Icon(Icons.link),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Introduce una URL válida';
                      }
                      if (!value.contains('http')) {
                        return 'La URL debe contener http o https';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Tipo de contenido',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _ChoiceButton(
                        label: 'Audio',
                        icon: Icons.music_note_rounded,
                        selected: _category == DownloadCategory.audio,
                        onTap: () => _onCategoryChanged(DownloadCategory.audio),
                      ),
                      const SizedBox(width: 12),
                      _ChoiceButton(
                        label: 'Video',
                        icon: Icons.movie_rounded,
                        selected: _category == DownloadCategory.video,
                        onTap: () => _onCategoryChanged(DownloadCategory.video),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Calidad',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in qualityOptions)
                        ChoiceChip(
                          label: Text(option.label),
                          selected: _quality == option,
                          onSelected: (_) {
                            setState(() {
                              _quality = option;
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_category == DownloadCategory.audio)
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<AudioFormat>(
                            value: _audioFormat,
                            decoration: const InputDecoration(
                              labelText: 'Formato de audio',
                            ),
                            items: AudioFormat.values
                                .map(
                                  (format) => DropdownMenuItem(
                                    value: format,
                                    child: Text(format.name.toUpperCase()),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _audioFormat = value);
                              }
                            },
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<VideoFormat>(
                            value: _videoFormat,
                            decoration: const InputDecoration(
                              labelText: 'Formato de video',
                            ),
                            items: VideoFormat.values
                                .map(
                                  (format) => DropdownMenuItem(
                                    value: format,
                                    child: Text(format.name.toUpperCase()),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _videoFormat = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    value: _embedMetadata,
                    onChanged: (value) => setState(() => _embedMetadata = value),
                    title: const Text('Incrustar metadatos y miniatura'),
                    subtitle: const Text('Utiliza ffmpeg para insertar información ID3/MP4'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded),
                      label: Text(_isSubmitting ? 'Añadiendo...' : 'Añadir a la cola'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: selected ? colors.primaryContainer : colors.surfaceVariant,
            border: Border.all(
              color: selected
                  ? colors.primary
                  : colors.outlineVariant.withOpacity(0.4),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: selected ? colors.onPrimaryContainer : colors.onSurfaceVariant),
              const SizedBox(height: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected
                          ? colors.onPrimaryContainer
                          : colors.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
