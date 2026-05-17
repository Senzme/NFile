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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
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
      if (mounted) {
        context.read<FileManagerProvider>().openFile(context, path);
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
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NFile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
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
  }
}
