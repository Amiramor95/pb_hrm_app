import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pb_hrsystem/home/dashboard/dashboard.dart';
import 'package:pb_hrsystem/nav/custom_buttom_nav_bar.dart';
import 'package:pb_hrsystem/user_model.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'services/notification_polling_service.dart';
import 'notifications/notification_model.dart';
import 'splash/splashscreen.dart';
import 'theme/theme.dart';
import 'home/home_calendar.dart';
import 'home/attendance_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeNotifier()),
          ChangeNotifierProvider(create: (_) => LanguageNotifier()),
          ChangeNotifierProvider(create: (_) => UserProvider()),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeNotifier, LanguageNotifier>(
      builder: (context, themeNotifier, languageNotifier, child) {
        return MaterialApp(
          builder: (context, child) {
            return EasyLoading.init()(context, child!); // Initialize EasyLoading here
          },
          title: 'PSBV',
          theme: ThemeData(
            primarySwatch: Colors.green,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            textTheme: GoogleFonts.oxaniumTextTheme(Theme.of(context).textTheme),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.green,
              ),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.green,
            scaffoldBackgroundColor: Colors.black,
            textTheme: GoogleFonts.oxaniumTextTheme(
              Theme.of(context).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
            ),
          ),
          themeMode: themeNotifier.currentTheme,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('lo'),
            Locale('zh'),
          ],
          locale: languageNotifier.currentLocale,
          home: const SplashScreen(),
        );
      },
    );
  }
}

class LanguageNotifier with ChangeNotifier {
  Locale _currentLocale = const Locale('en');

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
        _currentLocale = const Locale('en');
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
  int _selectedIndex = 1;
  final List<NotificationModel> _notifications = [];
  late NotificationPollingService _notificationPollingService;

  static final List<Widget> _widgetOptions = <Widget>[
    const AttendanceScreen(),
    const HomeCalendar(),
    const Dashboard(),
  ];

  @override
  void initState() {
    super.initState();
    _notificationPollingService = NotificationPollingService(
      apiUrl: 'https://demo-application-api.flexiflows.co/api/work-tracking/proj/notifications',
      onNewNotifications: (notifications) {
        setState(() {
          _notifications.addAll(notifications.map((n) => NotificationModel.fromJson(n as Map<String, dynamic>)));
        });
      },
    );
    _notificationPollingService.startPolling();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    _notificationPollingService.stopPolling();
    super.dispose();
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
