import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'core/downloads.dart';
import 'core/library_store.dart';
import 'core/theme.dart';
import 'screens/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  if (!kIsWeb) {
    // Lock screen, notification, headset and car controls for audio.
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.baptisthub.audio',
      androidNotificationChannelName: 'Playback',
      androidNotificationChannelDescription: 'Controls for sermons and music',
      androidNotificationOngoing: true,
      notificationColor: AppColors.gold,
      rewindInterval: const Duration(seconds: 15),
      fastForwardInterval: const Duration(seconds: 30),
    );
  }
  await LibraryStore.instance.init();
  // Not awaited: the UI shouldn't wait on re-attaching to downloads.
  DownloadManager.instance.init();
  runApp(const BaptistHubApp());
}

class BaptistHubApp extends StatelessWidget {
  const BaptistHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BaptistHub',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      darkTheme: buildTheme(),
      themeMode: ThemeMode.dark,
      home: const Shell(),
    );
  }
}
