import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:weatherornot/providers/main_provider.dart';
import 'package:weatherornot/services/location_service.dart';
import 'package:weatherornot/widgets/location_dropdown.dart';
import '../services/preferences_service.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  final PreferencesService _prefsService = PreferencesService();
  String _selectedTransportation = 'Bike';
  final TextEditingController _coldThresholdController = TextEditingController(
    text: '5',
  );
  final TextEditingController _warmThresholdController = TextEditingController(
    text: '20',
  );
  bool _isLoading = true;

  final Map<String, IconData> _transportationIcons = {
    'Bike': Icons.directions_bike,
    'on Foot': Icons.directions_walk,
    'Public Transit': Icons.directions_bus,
    'Car': Icons.directions_car,
    'E-Scooter': Icons.electric_scooter,
  };

  final List<String> _transportationModes = [
    'Bike',
    'on Foot',
    'Public Transit',
    'Car',
    'E-Scooter',
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final transportation = await _prefsService.getTransportation();
      final coldThreshold = await _prefsService.getColdThreshold();
      final warmThreshold = await _prefsService.getWarmThreshold();

      setState(() {
        _selectedTransportation = transportation;
        _coldThresholdController.text = coldThreshold.toString();
        _warmThresholdController.text = warmThreshold.toString();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _savePreferences() async {
    try {
      final coldThreshold =
          double.tryParse(_coldThresholdController.text) ?? 5.0;
      final warmThreshold =
          double.tryParse(_warmThresholdController.text) ?? 20.0;

      await _prefsService.saveAllPreferences(
        transportation: _selectedTransportation,
        coldThreshold: coldThreshold,
        warmThreshold: warmThreshold,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _coldThresholdController.dispose();
    _warmThresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final LocationService _locationService = LocationService();

    MainProvider _provider = context.watch<MainProvider>();

    void _onLocationChanged(Map<String, dynamic>? newLocation) async {
      if (newLocation != null && newLocation != _provider.selectedLocation) {
        _provider.setSelectedLocation(newLocation);

        final List<Map<String, dynamic>> closestList = await _locationService
            .findClosestLocation(newLocation['lat'], newLocation['lon']);
        _provider.loadWeather(
          newLocation["id"],
          newLocation["name"],
          fallbackStations: closestList
              .where((loc) => loc['name'] != newLocation["name"])
              .toList(),
        );
      }
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 12, left: 24, right: 24, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text(
                        "Settings",
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  LocationDropdown(
                    selectedLocation: _provider.selectedLocation,
                    onLocationChanged: _onLocationChanged,
                    closestLocations: _provider.closestLocations,
                    locationAccessDenied: _provider.locationAccessDenied,
                    onRequestLocationPermission: () =>
                        _provider.getClosestLocation(),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Transportation Mode
              Text(
                'Preferred/usual way of commuting',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedTransportation,
                isExpanded: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withOpacity(0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _transportationModes.map((String mode) {
                  return DropdownMenuItem<String>(
                    value: mode,
                    child: Row(
                      children: [
                        Icon(
                          _transportationIcons[mode] ?? Icons.help_outline,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Text(mode),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedTransportation = newValue;
                    });
                  }
                },
              ),
              const SizedBox(height: 32),

              // Weather Preferences
              Text(
                'Weather Preferences',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              // Cold Threshold
              TextField(
                controller: _coldThresholdController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
                ],
                decoration: InputDecoration(
                  labelText: 'Cold Threshold (°C)',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withOpacity(0.3),
                  prefixIcon: Icon(
                    Icons.ac_unit,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: Text(
                  'Anything below this temperature feels cold',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Warm Threshold
              TextField(
                controller: _warmThresholdController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
                ],
                decoration: InputDecoration(
                  labelText: 'Warm Threshold (°C)',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withOpacity(0.3),
                  prefixIcon: Icon(
                    Icons.wb_sunny,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: Text(
                  'Anything above this temperature feels warm',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _savePreferences,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Text('Save settings'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
