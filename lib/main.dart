import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'core/theme.dart';
import 'providers/file_manager_provider.dart';
import 'ui/screens/home_screen.dart';
import 'core/icon_fonts/broken_icons.dart';

import 'package:media_kit/media_kit.dart';
import 'providers/media_provider.dart';
import 'services/preferences_service.dart';
import 'package:dynamic_color/dynamic_color.dart';

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
  bool _hasPermission = false;
  StreamSubscription? _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();
    _themeMode = PreferencesService.getThemeMode();
    _requestPermission().then((_) {
      if (_hasPermission) {
        _initSharingIntent();
      }
    });
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  void _initSharingIntent() {
    // For sharing or opening files when app is in memory
    _intentDataStreamSubscription =
        ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleOpenedMedia(value.first.path);
      }
    }, onError: (err) {});

    // For sharing or opening files when app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleOpenedMedia(value.first.path);
        ReceiveSharingIntent.instance.reset();
      }
    });
  }

  void _handleOpenedMedia(String path) {
    if (path.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navContext = navigatorKey.currentContext;
      if (navContext != null && navContext.mounted) {
        navContext.read<FileManagerProvider>().openFile(navContext, path);
      } else {
        // If navigator is not fully mounted yet, retry after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          final retryContext = navigatorKey.currentContext;
          if (retryContext != null && retryContext.mounted) {
            retryContext.read<FileManagerProvider>().openFile(retryContext, path);
          }
        });
      }
    });
  }

  Future<void> _requestPermission() async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.request().isGranted ||
          await Permission.storage.request().isGranted) {
        setState(() {
          _hasPermission = true;
        });
      } else {
        // Handle permission denied
      }
    } else {
      setState(() {
        _hasPermission = true;
      });
    }
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
      builder: (context, fm, child) {
        final option = fm.accentColorOption;
        final seed = PreferencesService.getSeedColor(option);

        return DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            final activeLight = option == 'dynamic' ? lightDynamic : null;
            final activeDark = option == 'dynamic' ? darkDynamic : null;

            return MaterialApp(
              navigatorKey: navigatorKey,
              title: 'NFile',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.getAppTheme(light: true, seed: seed, customScheme: activeLight),
              darkTheme: AppTheme.getAppTheme(light: false, seed: seed, customScheme: activeDark),
              themeMode: _themeMode,
              home: _hasPermission 
                  ? HomeScreen(toggleTheme: _toggleTheme)
                  : Scaffold(
                      body: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Broken.folder_cross, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text('Storage Permission Required', style: TextStyle(fontSize: 18)),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _requestPermission,
                              child: const Text('Grant Permission'),
                            ),
                          ],
                        ),
                      ),
                    ),
            );
          },
        );
      },
    );
  }
}
