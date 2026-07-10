import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterswift/core/router.dart';
import 'package:flutterswift/core/theme.dart';

void main() {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    const ProviderScope(
      child: DirXploreApp(),
    ),
  );
}

class DirXploreApp extends StatelessWidget {
  const DirXploreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DirXplore Pro',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      // Light Theme
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.lightBackground,
        colorScheme: const ColorScheme.light(
          primary: AppColors.lightAccentBlue,
          secondary: AppColors.lightAccentBlue,
          surface: AppColors.lightSecondaryBackground,
          error: AppColors.systemRed,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontFamily: 'SF Pro'),
        ),
        cupertinoOverrideTheme: const CupertinoThemeData(
          primaryColor: AppColors.lightAccentBlue,
          brightness: Brightness.light,
        ),
      ),
      // Dark Theme
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBackground,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.darkAccentBlue,
          secondary: AppColors.darkAccentBlue,
          surface: AppColors.darkSecondaryBackground,
          error: AppColors.systemRed,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontFamily: 'SF Pro'),
        ),
        cupertinoOverrideTheme: const CupertinoThemeData(
          primaryColor: AppColors.darkAccentBlue,
          brightness: Brightness.dark,
        ),
      ),
      // Follow system brightness
      themeMode: ThemeMode.system,
    );
  }
}
