import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterswift/core/theme.dart';
import 'package:flutterswift/features/downloader/files_notifier.dart';

final _themeOverrideProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
final _downloadsLimitProvider = StateProvider<int>((ref) => 3);
final _jsEnabledProvider = StateProvider<bool>((ref) => true);
final _desktopModeProvider = StateProvider<bool>((ref) => false);
final _clipboardMonitorProvider = StateProvider<bool>((ref) => true);
final _notificationsEnabledProvider = StateProvider<bool>((ref) => true);
final _developerModeProvider = StateProvider<bool>((ref) => false);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final themeMode = ref.watch(_themeOverrideProvider);
    final downloadsLimit = ref.watch(_downloadsLimitProvider);
    final jsEnabled = ref.watch(_jsEnabledProvider);
    final desktopMode = ref.watch(_desktopModeProvider);
    final clipboardMonitor = ref.watch(_clipboardMonitorProvider);
    final notifications = ref.watch(_notificationsEnabledProvider);
    final developerMode = ref.watch(_developerModeProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            title: Text('Settings',
                style: AppTypography.title1(context,
                    color: isDark ? AppColors.darkLabel : AppColors.lightLabel)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // ─── Appearance ───────────────────────────────────
                  _SettingsGroup(
                    label: 'Appearance',
                    isDark: isDark,
                    children: [
                      _SegmentedRow(
                        label: 'Theme',
                        isDark: isDark,
                        value: themeMode,
                        segments: const {
                          ThemeMode.light: 'Light',
                          ThemeMode.dark: 'Dark',
                          ThemeMode.system: 'Auto',
                        },
                        onChanged: (v) =>
                            ref.read(_themeOverrideProvider.notifier).state = v,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ─── Browser ─────────────────────────────────────
                  _SettingsGroup(
                    label: 'Browser',
                    isDark: isDark,
                    children: [
                      _ToggleRow(
                        label: 'JavaScript',
                        subtitle: 'Enable JavaScript on web pages',
                        isDark: isDark,
                        value: jsEnabled,
                        onChanged: (v) =>
                            ref.read(_jsEnabledProvider.notifier).state = v,
                      ),
                      _Divider(isDark: isDark),
                      _ToggleRow(
                        label: 'Request Desktop Site',
                        isDark: isDark,
                        value: desktopMode,
                        onChanged: (v) =>
                            ref.read(_desktopModeProvider.notifier).state = v,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ─── Downloads ──────────────────────────────────
                  _SettingsGroup(
                    label: 'Downloads',
                    isDark: isDark,
                    children: [
                      _StepperRow(
                        label: 'Parallel Downloads',
                        subtitle: 'Max simultaneous downloads',
                        isDark: isDark,
                        value: downloadsLimit,
                        min: 1,
                        max: 10,
                        onChanged: (v) =>
                            ref.read(_downloadsLimitProvider.notifier).state = v,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ─── Clipboard ──────────────────────────────────
                  _SettingsGroup(
                    label: 'Clipboard',
                    isDark: isDark,
                    children: [
                      _ToggleRow(
                        label: 'Monitor Clipboard',
                        subtitle: 'Detect URLs and download links',
                        isDark: isDark,
                        value: clipboardMonitor,
                        onChanged: (v) =>
                            ref.read(_clipboardMonitorProvider.notifier).state = v,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ─── Notifications ──────────────────────────────
                  _SettingsGroup(
                    label: 'Notifications',
                    isDark: isDark,
                    children: [
                      _ToggleRow(
                        label: 'Download Notifications',
                        subtitle: 'Alerts for completions and errors',
                        isDark: isDark,
                        value: notifications,
                        onChanged: (v) =>
                            ref.read(_notificationsEnabledProvider.notifier).state = v,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ─── Advanced ───────────────────────────────────
                  _SettingsGroup(
                    label: 'Advanced',
                    isDark: isDark,
                    children: [
                      _ToggleRow(
                        label: 'Developer Mode',
                        subtitle: 'Show diagnostic logs and experimental features',
                        isDark: isDark,
                        value: developerMode,
                        onChanged: (v) =>
                            ref.read(_developerModeProvider.notifier).state = v,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ─── Storage ────────────────────────────────────
                  _StorageSection(isDark: isDark),
                  const SizedBox(height: 20),
                  // ─── Clear Data ─────────────────────────────────
                  _SettingsGroup(
                    label: 'Clear Data',
                    isDark: isDark,
                    children: [
                      _NavigationRow(
                        label: 'Clear Browser Cache',
                        isDark: isDark,
                        onTap: () {},
                        destructive: true,
                      ),
                      _Divider(isDark: isDark),
                      _NavigationRow(
                        label: 'Clear History',
                        isDark: isDark,
                        onTap: () {},
                        destructive: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ─── About ──────────────────────────────────────
                  _SettingsGroup(
                    label: 'About',
                    isDark: isDark,
                    children: [
                      _InfoRow(label: 'App', value: 'DirXplore Pro', isDark: isDark),
                      _Divider(isDark: isDark),
                      _InfoRow(label: 'Version', value: '1.0.0', isDark: isDark),
                      _Divider(isDark: isDark),
                      _InfoRow(label: 'Build', value: 'release', isDark: isDark),
                      _Divider(isDark: isDark),
                      _InfoRow(label: 'Bundle ID', value: 'com.dirxplorerakib.pro', isDark: isDark),
                    ],
                  ),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Reusable settings group container
// ─────────────────────────────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  final String label;
  final bool isDark;
  final List<Widget> children;

  const _SettingsGroup({
    required this.label,
    required this.isDark,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label.toUpperCase(),
            style: AppTypography.footnote(
              context,
              color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel,
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkSecondaryBackground : AppColors.lightSecondaryBackground)
                    .withAlpha(200),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
                  width: 0.8,
                ),
              ),
              child: Column(children: children),
            ),
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 16,
      color: isDark ? AppColors.darkSeparator : AppColors.lightSeparator,
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool isDark;
  final bool value;
  final void Function(bool) onChanged;

  const _ToggleRow({
    required this.label,
    required this.isDark,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.body(context,
                        color: isDark ? AppColors.darkLabel : AppColors.lightLabel)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: AppTypography.footnote(context,
                          color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel)),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: isDark ? AppColors.darkAccentBlue : AppColors.lightAccentBlue,
          ),
        ],
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool isDark;
  final int value;
  final int min;
  final int max;
  final void Function(int) onChanged;

  const _StepperRow({
    required this.label,
    required this.isDark,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.body(context,
                        color: isDark ? AppColors.darkLabel : AppColors.lightLabel)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: AppTypography.footnote(context,
                          color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel)),
              ],
            ),
          ),
          Row(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: value > min ? () => onChanged(value - 1) : null,
                child: const Icon(CupertinoIcons.minus_circle),
              ),
              Text('$value',
                  style: AppTypography.body(context,
                      color: isDark ? AppColors.darkLabel : AppColors.lightLabel)),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: value < max ? () => onChanged(value + 1) : null,
                child: const Icon(CupertinoIcons.plus_circle),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentedRow<T extends Object> extends StatelessWidget {
  final String label;
  final bool isDark;
  final T value;
  final Map<T, String> segments;
  final void Function(T) onChanged;

  const _SegmentedRow({
    required this.label,
    required this.isDark,
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTypography.body(context,
                  color: isDark ? AppColors.darkLabel : AppColors.lightLabel)),
          const SizedBox(height: 8),
          CupertinoSlidingSegmentedControl<T>(
            groupValue: value,
            children: {
              for (final e in segments.entries) e.key: Text(e.value),
            },
            onValueChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

class _NavigationRow extends StatelessWidget {
  final String label;
  final bool isDark;
  final VoidCallback onTap;
  final bool destructive;

  const _NavigationRow({
    required this.label,
    required this.isDark,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? AppColors.systemRed
        : (isDark ? AppColors.darkLabel : AppColors.lightLabel);
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onPressed: onTap,
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: AppTypography.body(context, color: color))),
          Icon(CupertinoIcons.chevron_right,
              size: 16,
              color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel),
        ],
      ),
    );
  }
}

// MARK: - Storage Section

class _StorageSection extends ConsumerWidget {
  final bool isDark;
  const _StorageSection({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storageAsync = ref.watch(storageInfoProvider);

    return _SettingsGroup(
      label: 'Storage',
      isDark: isDark,
      children: [
        storageAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CupertinoActivityIndicator()),
          ),
          error: (_, __) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Could not load storage info',
                style: AppTypography.footnote(context,
                    color: AppColors.systemRed)),
          ),
          data: (info) => Column(
            children: [
              _InfoRow(
                label: 'Used by DirXplore Pro',
                value: _fmtBytes(info['usedBytes'] as int? ?? 0),
                isDark: isDark,
              ),
              _Divider(isDark: isDark),
              _InfoRow(
                label: 'Files',
                value: '${info['fileCount'] ?? 0}',
                isDark: isDark,
              ),
              _Divider(isDark: isDark),
              _InfoRow(
                label: 'Folders',
                value: '${info['folderCount'] ?? 0}',
                isDark: isDark,
              ),
              _Divider(isDark: isDark),
              _InfoRow(
                label: 'Free Device Storage',
                value: _fmtBytes(info['freeDeviceBytes'] as int? ?? 0),
                isDark: isDark,
              ),
              _Divider(isDark: isDark),
              _NavigationRow(
                label: 'Recalculate Storage',
                isDark: isDark,
                onTap: () => ref.refresh(storageInfoProvider),
              ),
              _Divider(isDark: isDark),
              _NavigationRow(
                label: 'Browse Downloads in Files',
                isDark: isDark,
                onTap: () => _openFilesApp(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _fmtBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
  }

  void _openFilesApp(BuildContext context) {
    final bridge = ref.read(fileBridgeProvider);
    bridge.getRootDirectory().then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Open the Files app → On My iPhone → DirXplore Pro'),
          backgroundColor: AppColors.darkAccentBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    });
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _InfoRow({required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTypography.body(context,
                  color: isDark ? AppColors.darkLabel : AppColors.lightLabel)),
          Text(value,
              style: AppTypography.body(context,
                  color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel)),
        ],
      ),
    );
  }
}
