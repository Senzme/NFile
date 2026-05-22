import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:media_kit/media_kit.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'core/theme.dart';
import 'core/icon_fonts/broken_icons.dart';
import 'providers/file_manager_provider.dart';
import 'providers/media_provider.dart';
import 'services/preferences_service.dart';
import 'ui/screens/home_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await PreferencesService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FileManagerProvider()),
        ChangeNotifierProvider(create: (_) => MediaProvider()),
      ],
      child: const NFileApp(),
    ),
  );
}

class NFileApp extends StatefulWidget {
  const NFileApp({super.key});

  @override
  State<NFileApp> createState() => _NFileAppState();
}

class _NFileAppState extends State<NFileApp> {
  ThemeMode _themeMode = ThemeMode.system;
  bool? _hasPermission;
  bool _sharingObserverSetup = false;
  StreamSubscription<List<SharedMediaFile>>? _sharingIntentSubscription;

  @override
  void initState() {
    super.initState();
    _themeMode = PreferencesService.getThemeMode();
    _initializeApplication();
  }

  @override
  void dispose() {
    _sharingIntentSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeApplication() async {
    await _checkStoragePermission();
    if (_hasPermission == true) {
      _setupSharingIntentObserver();
    }
  }

  Future<void> _checkStoragePermission() async {
    if (Platform.isAndroid) {
      final manageStorageGranted = await Permission.manageExternalStorage.isGranted;
      final standardStorageGranted = await Permission.storage.isGranted;

      if (mounted) {
        setState(() {
          _hasPermission = manageStorageGranted || standardStorageGranted;
        });
      }
    } else {
      if (mounted) {
        setState(() => _hasPermission = true);
      }
    }
  }

  Future<void> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final manageStorageGranted = await Permission.manageExternalStorage.request().isGranted;
      final standardStorageGranted = await Permission.storage.request().isGranted;

      if (mounted) {
        setState(() {
          _hasPermission = manageStorageGranted || standardStorageGranted;
        });
        if (_hasPermission == true) {
          _setupSharingIntentObserver();
        }
      }
    } else {
      if (mounted) {
        setState(() => _hasPermission = true);
        _setupSharingIntentObserver();
      }
    }
  }

  void _setupSharingIntentObserver() {
    if (_sharingObserverSetup) return;
    _sharingObserverSetup = true;
    _sharingIntentSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> incomingFiles) {
        if (incomingFiles.isNotEmpty) {
          _dispatchExternalMediaOpen(incomingFiles.first.path);
        }
      },
      onError: (_) {},
    );

    ReceiveSharingIntent.instance.getInitialMedia().then(
      (List<SharedMediaFile> initialFiles) {
        if (initialFiles.isNotEmpty) {
          _dispatchExternalMediaOpen(initialFiles.first.path);
          ReceiveSharingIntent.instance.reset();
        }
      },
      onError: (_) {},
    );
  }

  void _dispatchExternalMediaOpen(String absoluteFilePath) {
    if (absoluteFilePath.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final primaryContext = navigatorKey.currentContext;
      if (primaryContext != null && primaryContext.mounted) {
        primaryContext.read<FileManagerProvider>().openFile(primaryContext, absoluteFilePath);
      } else {
        Future.delayed(const Duration(milliseconds: 500), () {
          final fallbackContext = navigatorKey.currentContext;
          if (fallbackContext != null && fallbackContext.mounted) {
            fallbackContext.read<FileManagerProvider>().openFile(fallbackContext, absoluteFilePath);
          }
        });
      }
    });
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
    PreferencesService.saveThemeMode(_themeMode);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FileManagerProvider>(
      builder: (context, fileManager, _) {
        final currentAccentOption = fileManager.accentColorOption;
        final baseSeedColor = PreferencesService.getSeedColor(currentAccentOption);

        return DynamicColorBuilder(
          builder: (ColorScheme? dynamicLight, ColorScheme? dynamicDark) {
            final activeLightScheme = currentAccentOption == 'dynamic' ? dynamicLight : null;
            final activeDarkScheme = currentAccentOption == 'dynamic' ? dynamicDark : null;

            return MaterialApp(
              navigatorKey: navigatorKey,
              title: 'NFile',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.getAppTheme(light: true, seed: baseSeedColor, customScheme: activeLightScheme),
              darkTheme: AppTheme.getAppTheme(light: false, seed: baseSeedColor, customScheme: activeDarkScheme),
              themeMode: _themeMode,
              builder: (context, child) {
                final theme = Theme.of(context);
                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: theme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
                    statusBarBrightness: theme.brightness == Brightness.dark ? Brightness.dark : Brightness.light,
                    systemNavigationBarColor: theme.scaffoldBackgroundColor,
                    systemNavigationBarDividerColor: Colors.transparent,
                    systemNavigationBarIconBrightness: theme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
                  ),
                  child: child!,
                );
              },
              home: _hasPermission == null
                  ? const Scaffold()
                  : (_hasPermission == true
                      ? HomeScreen(toggleTheme: _toggleTheme)
                      : _StoragePermissionShield(onRequestPermission: _requestStoragePermission)),
            );
          },
        );
      },
    );
  }
}

class _StoragePermissionShield extends StatelessWidget {
  final VoidCallback onRequestPermission;

  const _StoragePermissionShield({required this.onRequestPermission});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Broken.folder_cross,
                  size: 72,
                  color: Theme.of(context).colorScheme.error.withOpacity(0.8),
                ),
                const SizedBox(height: 24),
                Text(
                  'Storage Access Required',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'NFile requires storage permission to manage, organize, and display your media files seamlessly.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: onRequestPermission,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Broken.shield_tick),
                  label: const Text('Grant Permission', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
