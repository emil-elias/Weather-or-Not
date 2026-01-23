import 'dart:io';
import 'package:flutter/material.dart';
import 'package:weatherornot/models/outfit.dart';
import 'package:weatherornot/models/wardrobe_item.dart';

/// Show a reusable outfit details bottom sheet. Items can be either
/// `WardrobeItem` (from wardrobe storage) or `ClothingItem` (runtime items).
Future<void> showOutfitDetailsSheet(
  BuildContext context, {
  required String title,
  DateTime? date,
  required List<dynamic> items,
  double? score,
}) async {
  String formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    return '${d.day}/${d.month}/${d.year}';
  }

  final theme = Theme.of(context);

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (date != null) ...[
                        Text(
                          'Saved ${formatDate(date)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      ...items.map((item) {
                        String? imagePath;
                        String titleText = '';
                        String subtitle = '';

                        if (item == null) {
                          titleText = '-';
                        } else if (item is Map) {
                          imagePath = (item['imagePath'] as String?);
                          titleText = (item['name'] as String?) ?? (item['subtype'] as String?) ?? '-';
                          subtitle = '${item['category'] ?? ''} • ${item['subcategory'] ?? ''}';
                        } else if (item is WardrobeItem) {
                          imagePath = item.imagePath;
                          titleText = item.name;
                          subtitle = '${item.category} • ${item.subcategory}';
                        } else if (item is ClothingItem) {
                          imagePath = item.metadata != null ? item.metadata!['imagePath'] as String? : null;
                          titleText = (item.metadata != null && item.metadata!['name'] != null) ? item.metadata!['name'].toString() : item.subtype;
                          subtitle = '${item.category} • ${item.subtype}';
                        } else {
                          // Defensive fallback: try to read common fields, otherwise toString()
                          try {
                            imagePath = (item.imagePath ?? (item.metadata != null ? item.metadata['imagePath'] as String? : null));
                            titleText = (item.metadata != null && item.metadata['name'] != null) ? item.metadata['name'].toString() : (item.subtype ?? item.toString()).toString();
                            subtitle = ((item.category ?? '') + ' • ' + (item.subtype ?? '')).replaceAll(' • ', ' • ');
                          } catch (_) {
                            titleText = item.toString();
                          }
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: item.color != '' ? Color(int.parse('0xFF${item.color != null ? item.color!.substring(1) : 'CCCCCC'}')) : theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: imagePath != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        File(imagePath),
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Icon(
                                      Icons.checkroom_rounded,
                                      color: theme.colorScheme.onPrimaryContainer
                              .withOpacity(0.5),
                                    ),
                            ),
                            title: Text(titleText),
                            subtitle: Text(subtitle),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
