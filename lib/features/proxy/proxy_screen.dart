import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterswift/core/theme.dart';
import 'package:flutterswift/features/proxy/proxies_notifier.dart';
import 'package:flutterswift/models/proxy_config.dart';

class ProxyScreen extends ConsumerWidget {
  const ProxyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final proxies = ref.watch(proxiesProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            title: Text(
              'Proxy Manager',
              style: AppTypography.title1(context,
                  color: isDark ? AppColors.darkLabel : AppColors.lightLabel),
            ),
            actions: [
              CupertinoButton(
                child: const Icon(CupertinoIcons.plus_circle),
                onPressed: () => _showAddProxySheet(context, ref, isDark),
              ),
            ],
          ),
          if (proxies.isEmpty)
            SliverFillRemaining(child: _EmptyProxies(isDark: isDark))
          else ...[
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _ProxyRow(
                  proxy: proxies[i],
                  isDark: isDark,
                  onActivate: () =>
                      ref.read(proxiesProvider.notifier).activateProxy(proxies[i].id),
                  onDeactivate: () =>
                      ref.read(proxiesProvider.notifier).deactivateAll(),
                  onTest: () =>
                      ref.read(proxiesProvider.notifier).testProxy(proxies[i].id),
                  onDelete: () =>
                      ref.read(proxiesProvider.notifier).removeProxy(proxies[i].id),
                ).animate().fadeIn(duration: 250.ms).slideX(begin: 0.04, end: 0),
                childCount: proxies.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ],
      ),
    );
  }

  void _showAddProxySheet(BuildContext context, WidgetRef ref, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _AddProxySheet(
          isDark: isDark,
          scrollController: scrollController,
          onAdd: (proxy) =>
              ref.read(proxiesProvider.notifier).addProxy(proxy),
        ),
      ),
    );
  }
}

class _EmptyProxies extends StatelessWidget {
  final bool isDark;
  const _EmptyProxies({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.shield,
              size: 72,
              color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel),
          const SizedBox(height: 16),
          Text('No Proxies',
              style: AppTypography.headline(context,
                  color: isDark ? AppColors.darkLabel : AppColors.lightLabel)),
          const SizedBox(height: 8),
          Text('Tap + to add HTTP, HTTPS, SOCKS4 or SOCKS5 proxies.',
              textAlign: TextAlign.center,
              style: AppTypography.footnote(context,
                  color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel)),
        ],
      ),
    );
  }
}

class _ProxyRow extends StatelessWidget {
  final ProxyConfig proxy;
  final bool isDark;
  final VoidCallback onActivate;
  final VoidCallback onDeactivate;
  final VoidCallback onTest;
  final VoidCallback onDelete;

  const _ProxyRow({
    required this.proxy,
    required this.isDark,
    required this.onActivate,
    required this.onDeactivate,
    required this.onTest,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = proxy.isActive;
    final border = isActive ? AppColors.darkAccentBlue : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: (isDark ? AppColors.darkSecondaryBackground : AppColors.lightSecondaryBackground)
                  .withAlpha(200),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border.withAlpha(isActive ? 120 : 0), width: 1.5),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkTertiaryBackground : AppColors.lightTertiaryBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(proxy.typeLabel,
                          style: AppTypography.footnote(context,
                              color: isDark ? AppColors.darkAccentBlue : AppColors.lightAccentBlue)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(proxy.name,
                          style: AppTypography.body(context,
                              color: isDark ? AppColors.darkLabel : AppColors.lightLabel),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.systemGreen.withAlpha(40),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Active',
                            style: AppTypography.footnote(context,
                                color: AppColors.systemGreen)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(proxy.address,
                    style: AppTypography.footnote(context,
                        color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel)),
                if (proxy.hasAuth)
                  Text('Authenticated',
                      style: AppTypography.footnote(context,
                          color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(proxy.latencyLabel,
                        style: AppTypography.footnote(context,
                            color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel)),
                    Row(
                      children: [
                        _SmallButton(label: 'Test', onTap: onTest),
                        const SizedBox(width: 8),
                        if (!isActive)
                          _SmallButton(label: 'Activate', onTap: onActivate, accent: true)
                        else
                          _SmallButton(label: 'Deactivate', onTap: onDeactivate),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onDelete,
                          child: const Icon(CupertinoIcons.trash,
                              size: 18, color: AppColors.systemRed),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool accent;

  const _SmallButton({required this.label, required this.onTap, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: accent
              ? AppColors.darkAccentBlue.withAlpha(30)
              : Colors.transparent,
          border: Border.all(
            color: accent ? AppColors.darkAccentBlue : AppColors.darkSecondaryLabel,
            width: 0.8,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: AppTypography.footnote(context,
                color: accent ? AppColors.darkAccentBlue : AppColors.darkSecondaryLabel)),
      ),
    );
  }
}

class _AddProxySheet extends StatefulWidget {
  final bool isDark;
  final ScrollController? scrollController;
  final void Function(ProxyConfig) onAdd;

  const _AddProxySheet({required this.isDark, this.scrollController, required this.onAdd});

  @override
  State<_AddProxySheet> createState() => _AddProxySheetState();
}

class _AddProxySheetState extends State<_AddProxySheet> {
  final _nameCtrl = TextEditingController();
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  ProxyType _type = ProxyType.http;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.glassBgDark : AppColors.glassBgLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
                width: 1.0,
              ),
            ),
          ),
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 36,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text('Add Proxy',
                    style: AppTypography.headline(context,
                        color: isDark ? AppColors.darkLabel : AppColors.lightLabel)),
                const SizedBox(height: 14),
                CupertinoSlidingSegmentedControl<ProxyType>(
                  groupValue: _type,
                  children: const {
                    ProxyType.http: Text('HTTP'),
                    ProxyType.https: Text('HTTPS'),
                    ProxyType.socks4: Text('SOCKS4'),
                    ProxyType.socks5: Text('SOCKS5'),
                  },
                  onValueChanged: (v) => setState(() => _type = v ?? ProxyType.http),
                ),
                const SizedBox(height: 14),
                _Field(controller: _nameCtrl, placeholder: 'Name', isDark: isDark),
                const SizedBox(height: 8),
                _Field(controller: _hostCtrl, placeholder: 'Host (e.g. 127.0.0.1)', isDark: isDark),
                const SizedBox(height: 8),
                _Field(controller: _portCtrl, placeholder: 'Port', isDark: isDark,
                    keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                _Field(controller: _userCtrl, placeholder: 'Username (optional)', isDark: isDark),
                const SizedBox(height: 8),
                _Field(controller: _passCtrl, placeholder: 'Password (optional)', isDark: isDark, obscure: true),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: _submit,
                    child: const Text('Add Proxy'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    final host = _hostCtrl.text.trim();
    final portStr = _portCtrl.text.trim();
    if (host.isEmpty || portStr.isEmpty) return;
    final port = int.tryParse(portStr) ?? 8080;
    final proxy = ProxyConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : '$host:$port',
      host: host,
      port: port,
      type: _type,
      username: _userCtrl.text.trim().isNotEmpty ? _userCtrl.text.trim() : null,
      password: _passCtrl.text.trim().isNotEmpty ? _passCtrl.text.trim() : null,
      createdAt: DateTime.now(),
    );
    widget.onAdd(proxy);
    Navigator.pop(context);
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final bool isDark;
  final TextInputType keyboardType;
  final bool obscure;

  const _Field({
    required this.controller,
    required this.placeholder,
    required this.isDark,
    this.keyboardType = TextInputType.text,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      obscureText: obscure,
      keyboardType: keyboardType,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkTertiaryBackground : AppColors.lightTertiaryBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      style: AppTypography.body(context,
          color: isDark ? AppColors.darkLabel : AppColors.lightLabel),
    );
  }
}
