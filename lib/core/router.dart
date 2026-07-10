import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:flutterswift/features/browser/browser_screen.dart';
import 'package:flutterswift/features/downloader/downloader_screen.dart';
import 'package:flutterswift/features/proxy/proxy_screen.dart';
import 'package:flutterswift/features/clipboard/clipboard_screen.dart';
import 'package:flutterswift/features/settings/settings_screen.dart';
import 'package:flutterswift/widgets/navigation_shell.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/browser',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return NavigationShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/browser',
              builder: (context, state) => const BrowserScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/downloader',
              builder: (context, state) => const DownloaderScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/proxy',
              builder: (context, state) => const ProxyScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/clipboard',
              builder: (context, state) => const ClipboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
