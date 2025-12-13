import 'package:flutter/material.dart';
import 'package:calendar_view/calendar_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser le logger au démarrage
  final logger = AppLogger();
  await logger.init();
  logger.info('🏉 Démarrage de l\'application XV Agenda');
  
  // Initialiser SharedPreferences et définir le flag de première exécution
  final prefs = await SharedPreferences.getInstance();
  final isFirstRun = prefs.getBool('has_launched') ?? true;
  
  if (isFirstRun) {
    await prefs.setBool('has_launched', true);
    logger.info('✨ Première exécution de l\'application');
  }
  
  runApp(const XVAgendaApp());
}

class XVAgendaApp extends StatelessWidget {
  const XVAgendaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CalendarControllerProvider(
      controller: EventController(),
      child: MaterialApp(
        title: 'XV de l\'Erdre',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
