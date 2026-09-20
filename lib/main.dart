import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/ads.dart';
import 'services/feedback.dart';
import 'services/level_repository.dart';
import 'services/progress_store.dart';
import 'theme.dart';
import 'ui/play_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final ads = AdMobAds();
  final feedback = DeviceFeedback();
  await feedback.load();

  final progress = await ProgressStore.load();
  await progress.resetOnce('start_at_level_1');

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Color Arrows',
      theme: buildTheme(),
      home: PlayScreen(
        services: Services(
          progress: progress,
          feedback: feedback,
          ads: ads,
          levels: LevelRepository(),
        ),
      ),
    ),
  );
}
