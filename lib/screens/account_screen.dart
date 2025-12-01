import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/preferences_service.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final PreferencesService _prefsService = PreferencesService();
  String _selectedTransportation = 'Fahrrad';
  final TextEditingController _coldThresholdController = TextEditingController(text: '5');
  final TextEditingController _warmThresholdController = TextEditingController(text: '20');
  bool _isLoading = true;

  final Map<String, IconData> _transportationIcons = {
    'Fahrrad': Icons.directions_bike,
    'zu Fuß': Icons.directions_walk,
    'Bus': Icons.directions_bus,
    'Auto': Icons.directions_car,
    'E-Roller': Icons.electric_scooter,
  };

  final List<String> _transportationModes = [
    'Fahrrad',
    'zu Fuß',
    'Bus',
    'Auto',
    'E-Roller',
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
      final coldThreshold = double.tryParse(_coldThresholdController.text) ?? 5.0;
      final warmThreshold = double.tryParse(_warmThresholdController.text) ?? 20.0;

      await _prefsService.saveAllPreferences(
        transportation: _selectedTransportation,
        coldThreshold: coldThreshold,
        warmThreshold: warmThreshold,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Einstellungen gespeichert'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
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

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Account'),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Transportation Mode
            Text(
              'Bevorzugtes Fortbewegungsmittel',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedTransportation,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
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
              'Wetterpräferenzen',
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
                labelText: 'Kalt-Schwellenwert (°C)',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
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
                'Unter dieser Temperatur ist es gefühlt kalt',
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
                labelText: 'Warm-Schwellenwert (°C)',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
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
                'Über dieser Temperatur ist es gefühlt warm',
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
                  child: Text('Einstellungen speichern'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
