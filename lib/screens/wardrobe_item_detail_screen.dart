import 'dart:io';
import 'package:flutter/material.dart';
import '../models/wardrobe_item.dart';
import '../services/wardrobe_service.dart';

class WardrobeItemDetailScreen extends StatefulWidget {
  final WardrobeItem item;
  final VoidCallback onUpdate;

  const WardrobeItemDetailScreen({
    super.key,
    required this.item,
    required this.onUpdate,
  });

  @override
  State<WardrobeItemDetailScreen> createState() =>
      _WardrobeItemDetailScreenState();
}

class _WardrobeItemDetailScreenState extends State<WardrobeItemDetailScreen> {
  final WardrobeService _wardrobeService = WardrobeService();
  late WardrobeItem _currentItem;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
  }

  Future<void> _toggleFavorite() async {
    final updatedItem = WardrobeItem(
      id: _currentItem.id,
      name: _currentItem.name,
      description: _currentItem.description,
      category: _currentItem.category,
      subcategory: _currentItem.subcategory,
      color: _currentItem.color,
      formalityLevel: _currentItem.formalityLevel,
      tags: _currentItem.tags,
      imagePath: _currentItem.imagePath,
      createdAt: _currentItem.createdAt,
      isFavorite: !_currentItem.isFavorite,
    );

    await _wardrobeService.updateWardrobeItem(updatedItem);
    setState(() {
      _currentItem = updatedItem;
    });
    widget.onUpdate();
  }

  Future<void> _deleteItem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _wardrobeService.deleteWardrobeItem(_currentItem.id);
      if (mounted) {
        widget.onUpdate();
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: size.height * 0.5,
            pinned: true,
            backgroundColor: theme.colorScheme.surface,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    _currentItem.isFavorite
                        ? Icons.favorite
                        : Icons.favorite_outline,
                  ),
                  color: _currentItem.isFavorite
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurface,
                  onPressed: _toggleFavorite,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: theme.colorScheme.error,
                  onPressed: _deleteItem,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _currentItem.imagePath != null
                  ? Hero(
                      tag: 'item_${_currentItem.id}',
                      child: Image.file(
                        File(_currentItem.imagePath!),
                        fit: BoxFit.cover,
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.primaryContainer,
                            theme.colorScheme.secondaryContainer,
                          ],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.checkroom_rounded,
                          size: 120,
                          color: theme.colorScheme.onPrimaryContainer
                              .withOpacity(0.3),
                        ),
                      ),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _currentItem.name,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_currentItem.description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          _currentItem.description,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _buildInfoSection(
                        theme: theme,
                        title: 'Details',
                        icon: Icons.info_outline_rounded,
                        children: [
                          _buildInfoRow(
                            theme: theme,
                            icon: Icons.category_outlined,
                            label: 'Category',
                            value: _currentItem.category,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            theme: theme,
                            icon: Icons.label_outline_rounded,
                            label: 'Subcategory',
                            value: _currentItem.subcategory,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            theme: theme,
                            icon: Icons.palette_outlined,
                            label: 'Color',
                            value: _currentItem.color,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            theme: theme,
                            icon: Icons.star_outline_rounded,
                            label: 'Formality',
                            value: _currentItem.formalityLevel,
                          ),
                        ],
                      ),
                      if (_currentItem.tags.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildInfoSection(
                          theme: theme,
                          title: 'Tags',
                          icon: Icons.local_offer_outlined,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _currentItem.tags.map((tag) {
                                return Chip(
                                  label: Text(tag),
                                  avatar: Icon(
                                    Icons.tag_rounded,
                                    size: 18,
                                    color: theme.colorScheme.primary,
                                  ),
                                  backgroundColor:
                                      theme.colorScheme.primaryContainer,
                                  labelStyle: TextStyle(
                                    color:
                                        theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      _buildInfoSection(
                        theme: theme,
                        title: 'Additional Info',
                        icon: Icons.calendar_today_outlined,
                        children: [
                          _buildInfoRow(
                            theme: theme,
                            icon: Icons.access_time_rounded,
                            label: 'Added on',
                            value: _formatDate(_currentItem.createdAt),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection({
    required ThemeData theme,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
