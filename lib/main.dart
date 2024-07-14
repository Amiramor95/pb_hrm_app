import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pb_hrsystem/splash/splashscreen.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/home/home_page.dart';
import 'package:pb_hrsystem/home/attendance_screen.dart';
import 'package:pb_hrsystem/home/profile_screen.dart';
import 'package:pb_hrsystem/nav/custom_buttom_nav_bar.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => LanguageNotifier()), // Add LanguageNotifier
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeNotifier, LanguageNotifier>(
      builder: (context, themeNotifier, languageNotifier, child) {
        return MaterialApp(
          title: 'PBHR',
          theme: ThemeData(
            primarySwatch: Colors.green,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.green,
              ),
            ),
          ),
          darkTheme: ThemeData.dark().copyWith(
            // Customize dark theme colors here
            primaryColor: Colors.green,
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.green,
              ),
            ),
          ),
          themeMode: themeNotifier.currentTheme,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [
            const Locale('en'),
            const Locale('lo'),
            const Locale('zh'),
          ],
          locale: languageNotifier.currentLocale,
          home: const SplashScreen(),
        );
      },
    );
  }
}


// LanguageNotifier class to manage language changes


class LanguageNotifier with ChangeNotifier {
  Locale _currentLocale = const Locale('en'); // Default locale

  Locale get currentLocale => _currentLocale;

  void changeLanguage(String languageCode) {
    switch (languageCode) {
      case 'English':
        _currentLocale = const Locale('en');
        break;
      case 'Laos':
        _currentLocale = const Locale('lo');
        break;
      case 'Chinese':
        _currentLocale = const Locale('zh');
        break;
      default:
        _currentLocale = const Locale('en'); // Default to English
    }
    notifyListeners();
  }
}


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 1; // Default to HomePage

  static final List<Widget> _widgetOptions = <Widget>[
    const AttendanceScreen(),
    const HomePage(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
