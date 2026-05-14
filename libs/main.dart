import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/garage_screen.dart';
import 'screens/main_menu_screen.dart';
import 'screens/map_screen.dart';
import 'screens/play_screen.dart';
import 'screens/settings_screen.dart';
import 'services/save_service.dart';
import 'services/sfx_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final saveService = SaveService();
  await saveService.init();

  final sfxService = SfxService(saveService: saveService);
  await sfxService.preload();

  runApp(HillRiderApp(saveService: saveService, sfxService: sfxService));
}

class HillRiderApp extends StatelessWidget {
  const HillRiderApp({
    required this.saveService,
    required this.sfxService,
    super.key,
  });

  final SaveService saveService;
  final SfxService sfxService;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFFFB703);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hill Rider',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFF030712),
      ),
      routes: {
        '/': (_) =>
            MainMenuScreen(saveService: saveService, sfxService: sfxService),
        '/play': (_) =>
            PlayScreen(saveService: saveService, sfxService: sfxService),
        '/garage': (_) =>
            GarageScreen(saveService: saveService, sfxService: sfxService),
        '/map': (_) =>
            MapScreen(saveService: saveService, sfxService: sfxService),
        '/settings': (_) =>
            SettingsScreen(saveService: saveService, sfxService: sfxService),
      },
    );
  }
}
