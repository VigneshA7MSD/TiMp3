import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/settings.dart' as app_settings;
import 'services/database_service.dart';
import 'services/audio_service.dart';
import 'services/file_scanner_service.dart';
import 'services/online_music_service.dart';
import 'providers/audio_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/online_library_screen.dart';
import 'screens/playlist_screen.dart';
import 'screens/search_screen.dart';
import 'screens/now_playing_screen.dart';
import 'screens/queue_screen.dart';
import 'screens/equalizer_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/mini_player.dart';

const _supabaseUrl = 'https://teujoixcqrijzivyhbth.supabase.co';
const _supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRldWpvaXhjcXJpanppdnloYnRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MjUxNDgsImV4cCI6MjA4OTUwMTE0OH0.YK-uHQdRW-az6A4XZZd7WLQhv1as1f7xI9kug6eA3BE';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
    if (details.stack != null) {
      debugPrint('FlutterError stack: ${details.stack}');
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('PlatformDispatcher error: $error');
    debugPrint('PlatformDispatcher stack: $stack');
    return true;
  };
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.timp3player.channel.audio',
    androidNotificationChannelName: 'TiMp3player Playback',
    androidNotificationOngoing: true,
  );

  // Initialize services
  SupabaseClient? supabaseClient;
  if (_supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
    supabaseClient = Supabase.instance.client;
  }

  final databaseService = DatabaseService();
  await databaseService.init();

  final audioService = AudioPlayerService(databaseService);
  final fileScannerService = FileScannerService();
  final onlineMusicService = OnlineMusicService(
    client: supabaseClient,
    projectUrl: _supabaseUrl,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: databaseService),
        Provider<AudioPlayerService>.value(value: audioService),
        Provider<FileScannerService>.value(value: fileScannerService),
        Provider<OnlineMusicService>.value(value: onlineMusicService),
        ChangeNotifierProvider(
          create: (context) => AudioProvider(audioService, databaseService),
        ),
      ],
      child: const MyApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_runBackgroundStartup(fileScannerService, databaseService));
  });
}

Future<void> _runBackgroundStartup(
  FileScannerService fileScannerService,
  DatabaseService databaseService,
) async {
  try {
    final hasPermission = await fileScannerService.requestStoragePermission();
    if (!hasPermission) {
      debugPrint('Audio/storage permission denied');
      return;
    }

    final scannedTracks = await fileScannerService.scanForMusicFiles();
    await databaseService.saveTracks(scannedTracks);
    debugPrint('Auto scan completed: ${scannedTracks.length} tracks found');
  } catch (e) {
    debugPrint('Background startup task failed: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final databaseService = context.read<DatabaseService>();

    return ValueListenableBuilder<Box<app_settings.AppSettings>>(
      valueListenable: databaseService.getSettingsListenable(),
      builder: (context, box, child) {
        final settings = databaseService.getSettings();
        return MaterialApp(
          title: 'TiMp3player',
          theme: _buildNeonTheme(brightness: Brightness.light),
          darkTheme: _buildNeonTheme(brightness: Brightness.dark),
          themeMode: _mapThemeMode(settings.themeMode),
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/home': (context) => const MainScreen(),
            '/now-playing': (context) => const NowPlayingScreen(),
            '/queue': (context) => const QueueScreen(),
            '/equalizer': (context) => const EqualizerScreen(),
            '/search': (context) => const SearchScreen(),
          },
        );
      },
    );
  }

  ThemeMode _mapThemeMode(app_settings.ThemeMode mode) {
    switch (mode) {
      case app_settings.ThemeMode.system:
        return ThemeMode.system;
      case app_settings.ThemeMode.light:
        return ThemeMode.light;
      case app_settings.ThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  ThemeData _buildNeonTheme({required Brightness brightness}) {
    const neonPink = Color(0xFFFF3AAE);
    const neonRose = Color(0xFFFF5A7A);
    const neonMagenta = Color(0xFFFF1DCE);
    const darkBg = Color(0xFF120212);
    const darkSurface = Color(0xFF220A24);
    const lightBg = Color(0xFFFFF5F9);
    const lightSurface = Color(0xFFFFEAF3);
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? darkBg : lightBg;
    final surface = isDark ? darkSurface : lightSurface;
    final headerBg = isDark
        ? const Color(0xFF2B1530).withValues(alpha: 0.96)
        : const Color(0xFFFFFFFF).withValues(alpha: 0.96);
    final headerFg = isDark ? const Color(0xFFF5DCEA) : const Color(0xFF5C3B4E);
    final snackBg = isDark ? const Color(0xFF2A1424) : const Color(0xFFFCEFF6);
    final snackFg = isDark ? const Color(0xFFFFF1F8) : const Color(0xFF2C1423);

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      fontFamily: 'Poppins',
      textTheme: ThemeData(
        brightness: brightness,
        useMaterial3: true,
      ).textTheme.apply(fontFamily: 'Poppins'),
      primaryTextTheme: ThemeData(
        brightness: brightness,
        useMaterial3: true,
      ).primaryTextTheme.apply(fontFamily: 'Poppins'),
      colorScheme: isDark
          ? const ColorScheme.dark(
              primary: neonPink,
              secondary: neonRose,
              tertiary: neonMagenta,
              surface: darkSurface,
              onSurface: Colors.white,
            )
          : const ColorScheme.light(
              primary: neonPink,
              secondary: neonRose,
              tertiary: neonMagenta,
              surface: lightSurface,
              onSurface: Color(0xFF1A0D16),
            ),
      canvasColor: surface,
      scaffoldBackgroundColor: bg,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: AppBarTheme(
        elevation: 2,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: headerBg,
        foregroundColor: headerFg,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: const Color(0xFFE06A9F),
        unselectedItemColor: const Color(0xFFB88AA6),
        type: BottomNavigationBarType.fixed,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: neonPink),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: snackBg,
        contentTextStyle: TextStyle(
          color: snackFg,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: isDark
            ? const Color(0xFFFF8CC1)
            : const Color(0xFFB33A74),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    HomeScreen(),
    LibraryScreen(),
    OnlineLibraryScreen(),
    PlaylistScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _openNowPlayingIfNeeded();
    }
  }

  void _openNowPlayingIfNeeded() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return;
    final audioProvider = context.read<AudioProvider>();
    if (audioProvider.currentTrack == null) return;
    Navigator.of(context).pushNamed('/now-playing');
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBarColor = isDark
        ? const Color(0xFF2B1530)
        : const Color(0xFFFFFFFF);
    final navBackgroundColor = isDark
        ? const Color(0xFF120212)
        : const Color(0xFFF7EDF2);
    final navButtonColor = isDark
        ? const Color(0xFFE06A9F)
        : const Color(0xFFD65B90);
    final navIconColor = isDark
        ? const Color(0xFFF5DCEA)
        : const Color(0xFF5C3B4E);

    return Scaffold(
      body: Stack(
        children: [
          _screens[_selectedIndex],
          if (_selectedIndex != 4)
            const Positioned(bottom: 0, left: 0, right: 0, child: MiniPlayer()),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.12),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: CurvedNavigationBar(
          index: _selectedIndex,
          height: 64,
          backgroundColor: navBackgroundColor,
          color: navBarColor,
          buttonBackgroundColor: navButtonColor,
          animationCurve: Curves.easeOutCubic,
          animationDuration: const Duration(milliseconds: 420),
          items: [
            Icon(
              _selectedIndex == 0 ? Icons.home : Icons.home_outlined,
              color: navIconColor,
            ),
            Icon(
              _selectedIndex == 1
                  ? Icons.library_music
                  : Icons.library_music_outlined,
              color: navIconColor,
            ),
            Icon(
              _selectedIndex == 2 ? Icons.cloud : Icons.cloud_outlined,
              color: navIconColor,
            ),
            Icon(
              _selectedIndex == 3
                  ? Icons.playlist_play
                  : Icons.queue_music_outlined,
              color: navIconColor,
            ),
            Icon(
              _selectedIndex == 4 ? Icons.settings : Icons.settings_outlined,
              color: navIconColor,
            ),
          ],
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
