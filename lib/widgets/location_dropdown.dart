import 'package:flutter/material.dart';
import '../services/location_service.dart';

class LocationDropdown extends StatelessWidget {
  final Map<String, dynamic> selectedLocation;
  final Function(Map<String, dynamic>) onLocationChanged;
  final List<Map<String, dynamic>>? closestLocations;
  final bool locationAccessDenied;
  final VoidCallback? onRequestLocationPermission;

  const LocationDropdown({
    super.key,
    required this.selectedLocation,
    required this.onLocationChanged,
    this.closestLocations,
    this.locationAccessDenied = false,
    this.onRequestLocationPermission,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _showLocationPicker(context),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 200,
        ), // Set the maximum width here
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  selectedLocation["name"],
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLocationPicker(BuildContext context) {
    final service = LocationService();

    final TextEditingController controller = TextEditingController();
    List<Map<String, dynamic>> results = [];
    bool isLoading = false;
    bool _controllerListenerAdded = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: StatefulBuilder(
              builder: (context, setModalState) {
                if (!_controllerListenerAdded) {
                  controller.addListener(() => setModalState(() {}));
                  _controllerListenerAdded = true;
                }
                Future<void> doSearch(String q) async {
                  if (q.trim().isEmpty) {
                    setModalState(() {
                      results = [];
                      isLoading = false;
                    });
                    return;
                  }
                  setModalState(() => isLoading = true);
                  try {
                    final found = await service.searchLocationsByName(q);
                    setModalState(() {
                      results = found;
                      isLoading = false;
                    });
                  } catch (_) {
                    setModalState(() {
                      results = [];
                      isLoading = false;
                    });
                  }
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Change Location',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          filled: false,
                          hintText: 'Search by name',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: controller.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    controller.clear();
                                    doSearch('');
                                  },
                                )
                              : null,
                        ),
                        onChanged: (v) => doSearch(v),
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : (controller.text.trim().isEmpty || results.isEmpty)
                          ? SingleChildScrollView(
                              child: Column(
                                children: [
                                  // show selected location first (as a search-like list item)
                                  if (selectedLocation != null) ...[
                                    ListTile(
                                      leading: const Icon(Icons.location_on),
                                      title: Text(
                                        selectedLocation['name']?.toString() ??
                                            '',
                                      ),
                                      subtitle:
                                          (selectedLocation['lat'] != null &&
                                              selectedLocation['lon'] != null)
                                          ? Text(
                                              '${selectedLocation['lat']}, ${selectedLocation['lon']}',
                                            )
                                          : null,
                                      onTap: () {
                                        onLocationChanged(selectedLocation);
                                        Navigator.pop(context);
                                      },
                                    ),
                                    const Divider(height: 0),
                                  ],
                                  // then show closest location or CTA
                                  if (locationAccessDenied)
                                    ListTile(
                                      leading: const Icon(Icons.location_off),
                                      title: const Text('Enable location'),
                                      subtitle: const Text(
                                        'Allow location access to find nearby stations',
                                      ),
                                      trailing: TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          onRequestLocationPermission?.call();
                                        },
                                        child: const Text('Enable'),
                                      ),
                                      onTap: () {
                                        Navigator.pop(context);
                                        onRequestLocationPermission?.call();
                                      },
                                    )
                                  else if (closestLocations != null &&
                                      closestLocations!.isNotEmpty)
                                    ListTile(
                                      leading: const Icon(Icons.my_location),
                                      title: Text(
                                        closestLocations!.first['name']
                                                ?.toString() ??
                                            '',
                                      ),
                                      subtitle:
                                          closestLocations!.first['distance'] !=
                                              null
                                          ? Text(
                                              '${(closestLocations!.first['distance'] as double).toStringAsFixed(1)} km away',
                                            )
                                          : null,
                                      onTap: () {
                                        onLocationChanged(
                                          closestLocations!.first,
                                        );
                                        Navigator.pop(context);
                                      },
                                    )
                                  else
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 24.0,
                                      ),
                                      child: Center(
                                        child: Text('No nearby stations'),
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: results.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 0),
                              itemBuilder: (context, index) {
                                final loc = results[index];
                                final name = loc['name']?.toString() ?? '';
                                return ListTile(
                                  leading: const Icon(Icons.location_on),
                                  title: Text(name),
                                  subtitle:
                                      (loc['lat'] != null && loc['lon'] != null)
                                      ? Text('${loc['lat']}, ${loc['lon']}')
                                      : null,
                                  onTap: () {
                                    onLocationChanged(loc);
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    ).whenComplete(() {
      // Delay disposal to allow dismissal animation to complete
      Future.delayed(const Duration(milliseconds: 300), () {
        controller.dispose();
      });
    });
  }
}
