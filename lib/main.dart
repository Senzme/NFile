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
import 'services/network_connections_service.dart';
import 'services/intent_handler_service.dart';
import 'services/pin_service.dart';
import 'services/audio_background_handler.dart';
import 'package:audio_service/audio_service.dart';
import 'ui/screens/home_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await PreferencesService.init();
  await PinService.init();
  await NetworkConnectionsService.init();

  // Initialize audio_service for background media notification
  // Wrapped in try-catch — app must still launch even if this fails
  try {
    await AudioService.init(
      builder: () => getAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.rubex.nfile.audio',
        androidNotificationChannelName: 'NFile Audio Player',
        androidNotificationIcon: 'mipmap/ic_launcher',
        androidShowNotificationBadge: true,
        androidStopForegroundOnPause: false,
        notificationColor: Color(0xFF6200EE),
      ),
    );
  } catch (e) {
    // audio_service init failed – background playback unavailable but app continues
    debugPrint('[NFile] AudioService.init failed: $e');
  }

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
  bool _isResolvingIntent = false;
  StreamSubscription<List<SharedMediaFile>>? _sharingIntentSubscription;

  @override
  void initState() {
    super.initState();
    final hideNav = PreferencesService.getHideNavigationBar();
    if (hideNav) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.top]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    SystemChrome.setSystemUIChangeCallback((bool visible) async {
      if (visible) {
        if (PreferencesService.getHideNavigationBar()) {
          await Future.delayed(const Duration(milliseconds: 1500));
          if (PreferencesService.getHideNavigationBar()) {
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.top]);
          }
        }
      }
    });
    _themeMode = PreferencesService.getThemeMode();
    // Setup sharing observer immediately to catch incoming intents at the earliest possible frame!
    _setupSharingIntentObserver();
    _initializeApplication();
  }

  @override
  void dispose() {
    _sharingIntentSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeApplication() async {
    await _checkStoragePermission();
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
      }
    } else {
      if (mounted) {
        setState(() => _hasPermission = true);
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
          setState(() {
            _isResolvingIntent = true;
          });
          _dispatchExternalMediaOpen(initialFiles.first.path);
          ReceiveSharingIntent.instance.reset();
        }
      },
      onError: (_) {},
    );
  }

  void _dispatchExternalMediaOpen(String absoluteFilePath) {
    if (absoluteFilePath.isEmpty) {
      if (mounted && _isResolvingIntent) {
        setState(() => _isResolvingIntent = false);
      }
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final primaryContext = navigatorKey.currentContext;
      if (primaryContext != null && primaryContext.mounted) {
        try {
          await IntentHandlerService.handleIncomingIntent(primaryContext, absoluteFilePath);
        } finally {
          if (mounted) {
            setState(() {
              _isResolvingIntent = false;
            });
          }
        }
      } else {
        Future.delayed(const Duration(milliseconds: 300), () async {
          final fallbackContext = navigatorKey.currentContext;
          if (fallbackContext != null && fallbackContext.mounted) {
            try {
              await IntentHandlerService.handleIncomingIntent(fallbackContext, absoluteFilePath);
            } finally {
              if (mounted) {
                setState(() {
                  _isResolvingIntent = false;
                });
              }
            }
          } else {
            if (mounted) {
              setState(() {
                _isResolvingIntent = false;
              });
            }
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
              theme: AppTheme.getAppTheme(light: true, seed: baseSeedColor, customScheme: activeLightScheme, fontFamily: fileManager.fontFamilyOption),
              darkTheme: AppTheme.getAppTheme(light: false, pitchBlack: fileManager.amoledMode, seed: baseSeedColor, customScheme: activeDarkScheme, fontFamily: fileManager.fontFamilyOption),
              themeMode: _themeMode,
              builder: (context, child) {
                final isDark = _themeMode == ThemeMode.system
                    ? (MediaQuery.platformBrightnessOf(context) == Brightness.dark)
                    : (_themeMode == ThemeMode.dark);
                
                final theme = isDark
                    ? AppTheme.getAppTheme(light: false, pitchBlack: fileManager.amoledMode, seed: baseSeedColor, customScheme: activeDarkScheme, fontFamily: fileManager.fontFamilyOption)
                    : AppTheme.getAppTheme(light: true, seed: baseSeedColor, customScheme: activeLightScheme, fontFamily: fileManager.fontFamilyOption);

                final navBarColor = theme.scaffoldBackgroundColor ?? theme.colorScheme.surface;

                final style = SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                  statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
                  systemNavigationBarColor: navBarColor,
                  systemNavigationBarDividerColor: Colors.transparent,
                  systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                  systemNavigationBarContrastEnforced: false,
                  systemStatusBarContrastEnforced: false,
                );

                SystemChrome.setSystemUIOverlayStyle(style);

                if (fileManager.hideNavigationBar) {
                  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.top]);
                } else {
                  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                }

                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: style,
                  child: child!,
                );
              },
              home: _isResolvingIntent
                  ? const _IntentLoadingScreen()
                  : (_hasPermission == null
                      ? const Scaffold()
                      : (_hasPermission == true
                          ? HomeScreen(toggleTheme: _toggleTheme)
                          : _StoragePermissionShield(onRequestPermission: _requestStoragePermission))),
            );
          },
        );
      },
    );
  }
}

class _IntentLoadingScreen extends StatelessWidget {
  const _IntentLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D1A) : const Color(0xFFF9F9FF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Broken.document,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 48,
              child: LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                color: theme.colorScheme.primary,
                borderRadius: const BorderRadius.all(Radius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Opening shared document...',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Resolving secure content stream',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
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
