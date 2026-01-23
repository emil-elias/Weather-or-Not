import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/wardrobe_item.dart';
import '../services/wardrobe_service.dart';
import 'add_item_screen.dart';

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
  Map<String, dynamic> _subtypesAttributes = {};
  Map<String, List<String>> _activityGroups = {};
  List<String> _activityGroupOrder = [];

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
    _loadSubtypeAttributes();
    _loadActivityOptions();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadSubtypeAttributes() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/subtypes_attributes.json');
      final Map<String, dynamic> jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      setState(() {
        _subtypesAttributes = jsonData;
      });
    } catch (e) {
      // ignore
      print('Failed to load subtype attributes: $e');
    }
  }

  Future<void> _loadActivityOptions() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/activities.json');
      final Map<String, dynamic> jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      final Map<String, List<String>> groups = {};
      if (jsonData.containsKey('activities')) {
        final activities = jsonData['activities'] as Map<String, dynamic>;
        activities.forEach((category, groupMap) {
          if (groupMap is Map<String, dynamic>) {
            groupMap.forEach((groupKey, subList) {
              if (subList is List) {
                groups.putIfAbsent(groupKey, () => []);
                groups[groupKey]!.addAll(subList.map((e) => e.toString()));
              }
            });
          }
        });
      }

      final cleaned = <String, List<String>>{};
      groups.forEach((k, v) {
        final unique = v.toSet().toList()..sort();
        cleaned[k] = unique;
      });

      setState(() {
        _activityGroups = cleaned;
        _activityGroupOrder = cleaned.keys.toList()..sort();
      });
    } catch (e) {
      print('Failed to load activities: $e');
    }
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
      attributes: _currentItem.attributes,
      usageConstraints: _currentItem.usageConstraints,
      createdAt: _currentItem.createdAt,
      isFavorite: !_currentItem.isFavorite,
      isInWash: _currentItem.isInWash,
    );

    await _wardrobeService.updateWardrobeItem(updatedItem);
    setState(() {
      _currentItem = updatedItem;
    });
    widget.onUpdate();
  }

  Future<void> _toggleInWash() async {
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
      attributes: _currentItem.attributes,
      usageConstraints: _currentItem.usageConstraints,
      createdAt: _currentItem.createdAt,
      isFavorite: _currentItem.isFavorite,
      isInWash: !_currentItem.isInWash,
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

  Future<void> _showEditItemDialog() async {
    // Open the AddItemScreen in edit mode and wait for a boolean result
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => AddItemScreen(
        onBack: () => Navigator.pop(context, true),
        initialItem: _currentItem,
      )),
    );

    if (result == true) {
      // reload updated item from storage
      final items = await _wardrobeService.getWardrobeItems();
      final updated = items.firstWhere((i) => i.id == _currentItem.id, orElse: () => _currentItem);
      setState(() {
        _currentItem = updated;
      });
      widget.onUpdate();
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

              // Washing machine button
              Container(
                margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    _currentItem.isInWash
                        ? Icons.local_laundry_service
                        : Icons.local_laundry_service_outlined,
                  ),
                  color: _currentItem.isInWash
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                  onPressed: _toggleInWash,
                ),
              ),

              // Edit button
              Container(
                margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  color: theme.colorScheme.onSurface,
                  onPressed: () => _showEditItemDialog(),
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
                        color: _currentItem.color != '' ? Color(int.parse('0xFF${_currentItem.color.substring(1)}')) : theme.colorScheme.primaryContainer,
                        /*gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.primaryContainer,
                            theme.colorScheme.secondaryContainer,
                          ],
                        ),*/
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

                      const SizedBox(height: 24),
                      // Attributes section
                      _buildAttributesSection(theme),

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

  Widget _buildAttributesSection(ThemeData theme) {
    // Determine defaults for current subcategory
    Map<String, dynamic> defaultAttrs = {};
    Map<String, dynamic> defaultUsage = {};

    if (_subtypesAttributes.isNotEmpty) {
      final key = _currentItem.subcategory;
      if (_subtypesAttributes.containsKey(key)) {
        final entry = _subtypesAttributes[key];
        if (entry is Map<String, dynamic>) {
          defaultAttrs = (entry['attributes'] as Map<String, dynamic>?) ?? {};
          defaultUsage = (entry['usage_constraints'] as Map<String, dynamic>?) ?? {};
        }
      } else {
        // try normalized key
        final normalized = key.replaceAll(' ', '_').replaceAll('-', '_');
        if (_subtypesAttributes.containsKey(normalized)) {
          final entry = _subtypesAttributes[normalized];
          if (entry is Map<String, dynamic>) {
            defaultAttrs = (entry['attributes'] as Map<String, dynamic>?) ?? {};
            defaultUsage = (entry['usage_constraints'] as Map<String, dynamic>?) ?? {};
          }
        }
      }
    }

    final mergedAttrs = {...defaultAttrs, ...?_currentItem.attributes};
    final mergedUsage = {...defaultUsage, ...?_currentItem.usageConstraints};

    // Helper to show list as chips
    Widget chipsFromList(List<dynamic>? list) {
      if (list == null || list.isEmpty) return const Text('-');
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: list.map((e) {
          return Chip(
            label: Text(e.toString()),
            backgroundColor: theme.colorScheme.primaryContainer,
            labelStyle: TextStyle(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          );
        }).toList(),
      );
    }

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
                Icons.tune,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Attributes',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Materials
          _buildInfoRow(
            theme: theme,
            icon: Icons.layers_outlined,
            label: 'Materials',
            valueWidget: chipsFromList(mergedAttrs['materials'] as List<dynamic>?),
          ),
          const SizedBox(height: 12),
          // Numeric attributes
          Row(
            children: [
              Expanded(
                child: _buildInfoRow(
                    theme: theme,
                    icon: Icons.thermostat_outlined,
                    label: 'Warmth',
                    value: (mergedAttrs['warmth_level']?.toString() ?? '-')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoRow(
                    theme: theme,
                    icon: Icons.opacity_outlined,
                    label: 'Water',
                    value: (mergedAttrs['water_resistance']?.toString() ?? '-')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoRow(
                    theme: theme,
                    icon: Icons.air_outlined,
                    label: 'Wind',
                    value: (mergedAttrs['wind_resistance']?.toString() ?? '-')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoRow(
                    theme: theme,
                    icon: Icons.bolt_outlined,
                    label: 'Breathability',
                    value: (mergedAttrs['breathability']?.toString() ?? '-')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            theme: theme,
            icon: Icons.straighten_outlined,
            label: 'Stretch',
            value: (mergedAttrs['stretch']?.toString() ?? '-'),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            theme: theme,
            icon: Icons.business_center_outlined,
            label: 'Formality',
            value: mergedAttrs['formality']?.toString() ?? _currentItem.formalityLevel,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            theme: theme,
            icon: Icons.category_outlined,
            label: 'Fit',
            value: mergedAttrs['fit']?.toString() ?? '-',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            theme: theme,
            icon: Icons.style_outlined,
            label: 'Style Tags',
            valueWidget: chipsFromList(mergedAttrs['style_tags'] as List<dynamic>?),
          ),
          const SizedBox(height: 12),
          Text(
            'Usage Constraints',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            theme: theme,
            icon: Icons.thermostat,
            label: 'Min/Max Temp',
            value: '${mergedUsage['weather_min_temp'] ?? '-'} / ${mergedUsage['weather_max_temp'] ?? '-'}',
          ),
          const SizedBox(height: 12),
          // Optimal Activities (grouped and collapsed)
          Builder(builder: (context) {
            final optimal = (mergedUsage['optimal_activities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
            // build a list of group children that have matching activities
            final children = _activityGroupOrder.map((group) {
              final acts = _activityGroups[group] ?? [];
              final matches = acts.where((a) => optimal.contains(a)).toList();
              final display = matches;
              if (display.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical:6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [Text(group.replaceAll('_', ' '), style: theme.textTheme.bodySmall), const SizedBox(width:8), Text('(${display.length})', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))]),
                    const SizedBox(height:8),
                    Wrap(spacing: 8, children: display.map((m) => Chip(label: Text(m), backgroundColor: theme.colorScheme.surfaceContainerHighest, labelStyle: TextStyle(color: theme.colorScheme.onSurface))).toList()),
                  ],
                ),
              );
            }).where((w) => w is! SizedBox).toList();

            if (children.isEmpty) {
              // fallback to empty row
              return _buildInfoRow(theme: theme, icon: Icons.fitness_center_outlined, label: 'Optimal Activities', value: '-');
            }

            return ExpansionTile(
              title: Row(children: [Icon(Icons.fitness_center_outlined, size:20, color: theme.colorScheme.primary), const SizedBox(width:8), Text('Optimal Activities')]),
              initiallyExpanded: false,
              childrenPadding: const EdgeInsets.symmetric(horizontal:0, vertical:8),
              children: children,
            );
          }),
          const SizedBox(height: 12),
          // Unsuitable For (grouped and collapsed)
          Builder(builder: (context) {
            final unsuitable = (mergedUsage['unsuitable_for'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
            final children = _activityGroupOrder.map((group) {
              final acts = _activityGroups[group] ?? [];
              final matches = acts.where((a) => unsuitable.contains(a)).toList();
              final display = matches;
              if (display.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical:6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [Text(group.replaceAll('_', ' '), style: theme.textTheme.bodySmall), const SizedBox(width:8), Text('(${display.length})', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))]),
                    const SizedBox(height:8),
                    Wrap(spacing: 8, children: display.map((m) => Chip(label: Text(m), backgroundColor: theme.colorScheme.surfaceContainerHighest, labelStyle: TextStyle(color: theme.colorScheme.onSurface))).toList()),
                  ],
                ),
              );
            }).where((w) => w is! SizedBox).toList();

            if (children.isEmpty) {
              return _buildInfoRow(theme: theme, icon: Icons.block_outlined, label: 'Unsuitable For', value: '-');
            }

            return ExpansionTile(
              title: Row(children: [Icon(Icons.block_outlined, size:20, color: theme.colorScheme.primary), const SizedBox(width:8), Text('Unsuitable For')]),
              initiallyExpanded: false,
              childrenPadding: const EdgeInsets.symmetric(horizontal:0, vertical:8),
              children: children,
            );
          }),
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
    String? value,
    Widget? valueWidget,
  }) {
    final content = valueWidget ?? (value != null ? Text(
      value,
      style: theme.textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ) : const SizedBox.shrink());

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
              content,
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
