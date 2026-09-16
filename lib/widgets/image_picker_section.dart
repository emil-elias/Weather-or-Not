import 'dart:io';
import 'package:flutter/material.dart';

class ImagePickerSection extends StatelessWidget {
  final VoidCallback onCameraPressed;
  final VoidCallback onGalleryPressed;
  final String? imagePath;

  const ImagePickerSection({
    super.key,
    required this.onCameraPressed,
    required this.onGalleryPressed,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          gradient: imagePath == null
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primaryContainer,
                    theme.colorScheme.secondaryContainer,
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: imagePath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(imagePath!),
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Row(
                        children: [
                          FloatingActionButton.small(
                            heroTag: 'camera',
                            onPressed: onCameraPressed,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Icon(
                              Icons.camera_alt_rounded,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FloatingActionButton.small(
                            heroTag: 'gallery',
                            onPressed: onGalleryPressed,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Icon(
                              Icons.photo_library_rounded,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: onCameraPressed,
                        icon: const Icon(Icons.camera_alt_rounded, size: 24),
                        label: const Text('Camera'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.tonalIcon(
                        onPressed: onGalleryPressed,
                        icon: const Icon(Icons.photo_library_rounded, size: 24),
                        label: const Text('Gallery'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Add a photo of your clothing item',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
