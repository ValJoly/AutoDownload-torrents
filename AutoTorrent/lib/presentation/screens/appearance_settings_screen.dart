import 'package:flutter/material.dart';

import '../../core/app_preferences.dart';
import '../../core/auth_session.dart';
import '../../data/api/bridge_api.dart';

class AppearanceSettingsScreen extends StatefulWidget {
  const AppearanceSettingsScreen({this.preferences, this.session, super.key});

  final AppPreferences? preferences;
  final AuthSession? session;

  @override
  State<AppearanceSettingsScreen> createState() =>
      _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends State<AppearanceSettingsScreen> {
  bool _checkingConnectivity = false;
  String? _connectivityMessage;
  bool _connectivitySucceeded = false;

  static const _accents = [
    _AccentOption('Rose', Color(0xFFEAA4BD)),
    _AccentOption('Blue', Color(0xFF4F78C4)),
    _AccentOption('Teal', Color(0xFF368B83)),
    _AccentOption('Green', Color(0xFF6F8F4E)),
    _AccentOption('Amber', Color(0xFFC28A36)),
    _AccentOption('Coral', Color(0xFFCB665B)),
    _AccentOption('Violet', Color(0xFF8167B6)),
  ];

  @override
  Widget build(BuildContext context) {
    final preferences = widget.preferences ?? appPreferences;
    return AnimatedBuilder(
      animation: preferences,
      builder: (context, _) {
        final theme = Theme.of(context);
        final selectedAccent = preferences.accentColor;
        final isPreset = _accents.any(
          (option) => option.color == selectedAccent,
        );

        return Scaffold(
          appBar: AppBar(title: const Text('Appearance')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              if (widget.session != null) ...[
                Text('Server connection', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Check whether your saved bridge server is reachable.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('check-server-connectivity'),
                  onPressed:
                      _checkingConnectivity || widget.session!.bridgeUrl.isEmpty
                      ? null
                      : _checkConnectivity,
                  icon: _checkingConnectivity
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_find_outlined),
                  label: Text(
                    _checkingConnectivity ? 'Checking…' : 'Check connection',
                  ),
                ),
                if (widget.session!.bridgeUrl.isEmpty)
                  Text(
                    'No saved bridge address.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (_connectivityMessage case final message?)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _connectivitySucceeded
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 28),
              ],
              Text('Theme', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('System'),
                    icon: Icon(Icons.settings_brightness_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode_outlined),
                  ),
                ],
                selected: {preferences.themeMode},
                onSelectionChanged: (selection) =>
                    _saveTheme(context, preferences, selection.first),
              ),
              const SizedBox(height: 28),
              Text('Accent color', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Choose a preset or adjust a custom color.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in _accents)
                    ChoiceChip(
                      avatar: CircleAvatar(
                        backgroundColor: option.color,
                        radius: 8,
                      ),
                      label: Text(option.label),
                      selected: selectedAccent == option.color,
                      onSelected: (_) =>
                          _saveAccentColor(context, preferences, option.color),
                    ),
                  ChoiceChip(
                    avatar: CircleAvatar(
                      backgroundColor: selectedAccent,
                      radius: 8,
                    ),
                    label: const Text('Custom'),
                    selected: !isPreset,
                    onSelected: (_) async {
                      final color = await showDialog<Color>(
                        context: context,
                        builder: (_) =>
                            _CustomAccentDialog(initialColor: selectedAccent),
                      );
                      if (!context.mounted) return;
                      if (color != null) {
                        await _saveAccentColor(context, preferences, color);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest,
                child: ListTile(
                  leading: Icon(
                    Icons.palette_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text('Accent preview'),
                  subtitle: const Text('Buttons and controls use this color.'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Aa',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _checkConnectivity() async {
    final session = widget.session;
    if (session == null || session.bridgeUrl.isEmpty) return;

    setState(() {
      _checkingConnectivity = true;
      _connectivityMessage = null;
    });
    try {
      await session.api.checkConnectivity(session.bridgeUrl);
      if (!mounted) return;
      setState(() {
        _connectivitySucceeded = true;
        _connectivityMessage = 'Server is reachable.';
      });
    } catch (error) {
      if (!mounted) return;
      final details = error is BridgeException ? error.message : error;
      setState(() {
        _connectivitySucceeded = false;
        _connectivityMessage = 'Could not connect: $details';
      });
    } finally {
      if (mounted) {
        setState(() => _checkingConnectivity = false);
      }
    }
  }

  Future<void> _saveTheme(
    BuildContext context,
    AppPreferences preferences,
    ThemeMode mode,
  ) async {
    try {
      await preferences.setThemeMode(mode);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save theme setting: $error')),
        );
      }
    }
  }

  Future<void> _saveAccentColor(
    BuildContext context,
    AppPreferences preferences,
    Color color,
  ) async {
    try {
      await preferences.setAccentColor(color);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save accent color: $error')),
        );
      }
    }
  }
}

class _CustomAccentDialog extends StatefulWidget {
  const _CustomAccentDialog({required this.initialColor});

  final Color initialColor;

  @override
  State<_CustomAccentDialog> createState() => _CustomAccentDialogState();
}

class _CustomAccentDialogState extends State<_CustomAccentDialog> {
  late HSLColor _color = HSLColor.fromColor(widget.initialColor);

  @override
  Widget build(BuildContext context) {
    final previewColor = _color.toColor();
    return AlertDialog(
      title: const Text('Custom accent color'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: previewColor,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 16),
            _ColorSlider(
              label: 'Hue',
              value: _color.hue,
              max: 360,
              activeColor: HSLColor.fromAHSL(1, _color.hue, 1, .5).toColor(),
              onChanged: (value) =>
                  setState(() => _color = _color.withHue(value)),
            ),
            _ColorSlider(
              label: 'Saturation',
              value: _color.saturation,
              max: 1,
              divisions: 100,
              activeColor: previewColor,
              onChanged: (value) =>
                  setState(() => _color = _color.withSaturation(value)),
            ),
            _ColorSlider(
              label: 'Lightness',
              value: _color.lightness,
              min: .15,
              max: .85,
              divisions: 70,
              activeColor: previewColor,
              onChanged: (value) =>
                  setState(() => _color = _color.withLightness(value)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, previewColor),
          child: const Text('Use color'),
        ),
      ],
    );
  }
}

class _ColorSlider extends StatelessWidget {
  const _ColorSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.activeColor,
    required this.onChanged,
    this.min = 0,
    this.divisions,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final Color activeColor;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 76, child: Text(label)),
      Expanded(
        child: Slider(
          label: label,
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          divisions: divisions,
          activeColor: activeColor,
          onChanged: onChanged,
        ),
      ),
    ],
  );
}

class _AccentOption {
  const _AccentOption(this.label, this.color);

  final String label;
  final Color color;
}
