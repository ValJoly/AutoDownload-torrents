import 'package:flutter/material.dart';

import '../../core/app_preferences.dart';
import '../../core/auth_session.dart';
import '../../data/api/bridge_api.dart';
import '../widgets/brutal.dart';

class AppearanceSettingsScreen extends StatefulWidget {
  const AppearanceSettingsScreen({this.preferences, this.session, super.key});

  final AppPreferences? preferences;
  final AuthSession? session;

  @override
  State<AppearanceSettingsScreen> createState() =>
      _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends State<AppearanceSettingsScreen> {
  final _serverAddressFormKey = GlobalKey<FormState>();
  late final TextEditingController _serverAddressController;
  bool _checkingConnectivity = false;
  bool _savingServerAddress = false;
  String? _connectivityMessage;
  bool _connectivitySucceeded = false;
  String? _serverAddressMessage;
  bool _serverAddressSaveSucceeded = false;

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
  void initState() {
    super.initState();
    _serverAddressController = TextEditingController(
      text: widget.session?.bridgeUrl ?? '',
    );
  }

  @override
  void dispose() {
    _serverAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preferences = widget.preferences ?? appPreferences;
    return AnimatedBuilder(
      animation: Listenable.merge([
        preferences,
        if (widget.session != null) widget.session!,
      ]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final selectedAccent = preferences.accentColor;
        final providerAvailabilityError =
            widget.session?.providerAvailabilityError;
        final isPreset = _accents.any(
          (option) => option.color == selectedAccent,
        );

        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              if (widget.session != null) ...[
                BrutalCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Server address',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Changing servers signs you out of the current server.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Form(
                          key: _serverAddressFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              BrutalField(
                                child: TextFormField(
                                  key: const Key('server-address'),
                                  controller: _serverAddressController,
                                  keyboardType: TextInputType.url,
                                  textInputAction: TextInputAction.done,
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                      ? 'Bridge address is required.'
                                      : null,
                                  decoration: const InputDecoration(
                                    labelText: 'Bridge address',
                                    hintText: 'https://bridge.example.com',
                                    prefixIcon: Icon(Icons.link),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                key: const Key('save-server-address'),
                                onPressed: _savingServerAddress
                                    ? null
                                    : _saveServerAddress,
                                icon: _savingServerAddress
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: Text(
                                  _savingServerAddress
                                      ? 'Saving…'
                                      : 'Save server address',
                                ),
                              ),
                              if (_serverAddressMessage case final message?)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      message,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: _serverAddressSaveSucceeded
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme.error,
                                          ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                BrutalCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Server connection',
                          style: theme.textTheme.titleMedium,
                        ),
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
                              _checkingConnectivity ||
                                  widget.session!.bridgeUrl.isEmpty
                              ? null
                              : _checkConnectivity,
                          icon: _checkingConnectivity
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.wifi_find_outlined),
                          label: Text(
                            _checkingConnectivity
                                ? 'Checking…'
                                : 'Check connection',
                          ),
                        ),
                        if (_connectivityMessage == null &&
                            providerAvailabilityError != null)
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              'Provider availability could not be checked: '
                              '$providerAvailabilityError',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error,
                              ),
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
                      ],
                    ),
                  ),
                ),
              ],
              BrutalCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              BrutalCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                              onSelected: (_) => _saveAccentColor(
                                context,
                                preferences,
                                option.color,
                              ),
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
                                builder: (_) => _CustomAccentDialog(
                                  initialColor: selectedAccent,
                                ),
                              );
                              if (!context.mounted) return;
                              if (color != null) {
                                await _saveAccentColor(
                                  context,
                                  preferences,
                                  color,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      BrutalBox(
                        shadowOffset: const Offset(2, 2),
                        child: ListTile(
                          leading: Icon(
                            Icons.palette_outlined,
                            color: theme.colorScheme.primary,
                          ),
                          title: const Text('Accent preview'),
                          subtitle: const Text(
                            'Buttons and controls use this color.',
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(brutalRadius),
                              border: Border.all(
                                color: brutalInk(context),
                                width: brutalBorderWidth,
                              ),
                            ),
                            child: Text(
                              'Aa',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveServerAddress() async {
    if (!_serverAddressFormKey.currentState!.validate()) return;

    setState(() {
      _savingServerAddress = true;
      _serverAddressMessage = null;
    });
    try {
      final changed = await widget.session!.updateBridgeUrl(
        _serverAddressController.text,
      );
      if (!mounted) return;
      setState(() {
        _serverAddressSaveSucceeded = true;
        _serverAddressMessage = changed
            ? 'Server address saved. Sign in again to use this server.'
            : 'Server address is unchanged.';
      });
    } catch (error) {
      if (!mounted) return;
      final details = error is BridgeException ? error.message : error;
      setState(() {
        _serverAddressSaveSucceeded = false;
        _serverAddressMessage = 'Could not save server address: $details';
      });
    } finally {
      if (mounted) setState(() => _savingServerAddress = false);
    }
  }

  Future<void> _checkConnectivity() async {
    final session = widget.session;
    if (session == null || session.bridgeUrl.isEmpty) return;

    setState(() {
      _checkingConnectivity = true;
      _connectivityMessage = null;
    });
    var serverReachable = false;
    try {
      await session.api.checkConnectivity(session.bridgeUrl);
      serverReachable = true;
      await session.refreshProviderAvailability();
      if (!mounted) return;
      setState(() {
        _connectivitySucceeded = true;
        _connectivityMessage = 'Server is reachable and providers are updated.';
      });
    } catch (error) {
      if (!mounted) return;
      final details = error is BridgeException ? error.message : error;
      setState(() {
        _connectivitySucceeded = false;
        _connectivityMessage = serverReachable
            ? 'Server is reachable, but provider availability could not be checked: $details'
            : 'Could not connect: $details';
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
