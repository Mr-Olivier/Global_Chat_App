// import 'package:flutter/material.dart';
// import 'package:flutter/src/widgets/framework.dart';
// import 'package:flutter/src/widgets/placeholder.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:globalchat/firebase_options.dart';
// import 'package:globalchat/providers/userProvider.dart';
// import 'package:provider/provider.dart';
// import 'screens/splash_screen.dart';

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
//   runApp(ChangeNotifierProvider(
//       create: (context) => UserProvider(), child: MyApp()));
// }

// class MyApp extends StatefulWidget {
//   const MyApp({super.key});

//   @override
//   State<MyApp> createState() => _MyAppState();
// }

// class _MyAppState extends State<MyApp> {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       theme: ThemeData(
//           brightness: Brightness.light,
//           useMaterial3: true,
//           fontFamily: "Poppins"),
//       home: SplashScreen(),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:globalchat/firebase_options.dart';
import 'package:globalchat/providers/userProvider.dart';
import 'package:globalchat/screens/landing_page.dart';
import 'package:globalchat/screens/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  // Ensure widgets are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Keep native splash screen up until app is fully loaded
  FlutterNativeSplash.preserve(
    widgetsBinding: WidgetsFlutterBinding.ensureInitialized(),
  );

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize shared preferences
  await _initializePreferences();

  // Run app
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => UserProvider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => ConnectivityProvider()),
      ],
      child: const MyApp(),
    ),
  );

  // Remove splash screen when app is ready
  FlutterNativeSplash.remove();
}

Future<void> _initializePreferences() async {
  final prefs = await SharedPreferences.getInstance();

  // Check if first time launch
  final isFirstLaunch = prefs.getBool('first_launch') ?? true;

  if (isFirstLaunch) {
    // Set default preferences for first time users
    await prefs.setBool('first_launch', false);
    await prefs.setBool('notifications_enabled', true);
    await prefs.setBool('dark_mode', false);
    await prefs.setInt('theme_color_index', 0); // Default theme (purple)
  }
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    // Initialize connectivity monitoring
    final connectivityProvider = Provider.of<ConnectivityProvider>(
      context,
      listen: false,
    );
    connectivityProvider.initConnectivity();
  }

  @override
  Widget build(BuildContext context) {
    // Access theme provider
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Access connectivity provider to monitor network status
    final connectivityProvider = Provider.of<ConnectivityProvider>(context);

    return MaterialApp(
      title: 'GlobalChat',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.getThemeData(),
      home:
          connectivityProvider.hasConnection
              ? const SplashScreen()
              : const NoConnectionScreen(),
      routes: {
        '/landing': (context) => const LandingPage(),
        '/splash': (context) => const SplashScreen(),
      },
    );
  }
}

// Theme provider for app-wide theme management
class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  int _colorIndex = 0;

  // Primary colors options
  final List<Color> _primaryColors = [
    Colors.deepPurpleAccent, // Default
    Colors.blue,
    Colors.teal,
    Colors.red,
    Colors.amber,
    Colors.pink,
  ];

  ThemeProvider() {
    _loadPreferences();
  }

  bool get isDarkMode => _isDarkMode;
  int get colorIndex => _colorIndex;

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    _isDarkMode = prefs.getBool('dark_mode') ?? false;
    _colorIndex = prefs.getInt('theme_color_index') ?? 0;

    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _isDarkMode);

    notifyListeners();
  }

  Future<void> setColorIndex(int index) async {
    if (index >= 0 && index < _primaryColors.length) {
      _colorIndex = index;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('theme_color_index', _colorIndex);

      notifyListeners();
    }
  }

  Color get primaryColor => _primaryColors[_colorIndex];

  ThemeData getThemeData() {
    final primaryColor = _primaryColors[_colorIndex];

    if (_isDarkMode) {
      // Dark theme
      return ThemeData(
        brightness: Brightness.dark,
        primaryColor: primaryColor,
        colorScheme: ColorScheme.dark(
          primary: primaryColor,
          secondary: primaryColor,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[900],
          elevation: 4,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: primaryColor,
        ),
        fontFamily: 'Poppins',
        useMaterial3: true,
      );
    } else {
      // Light theme
      return ThemeData(
        brightness: Brightness.light,
        primaryColor: primaryColor,
        colorScheme: ColorScheme.light(
          primary: primaryColor,
          secondary: primaryColor,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black87),
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: primaryColor,
        ),
        fontFamily: 'Poppins',
        useMaterial3: true,
      );
    }
  }
}

// Network connectivity provider
class ConnectivityProvider extends ChangeNotifier {
  bool _hasConnection = true;

  bool get hasConnection => _hasConnection;

  void initConnectivity() {
    // Check initial connection status
    Connectivity().checkConnectivity().then((result) {
      _updateConnectionStatus(result.first);
    });

    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((result) {
      _updateConnectionStatus(result.first);
    });
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    if (result == ConnectivityResult.none) {
      _hasConnection = false;
    } else {
      _hasConnection = true;
    }

    notifyListeners();
  }
}

// No internet connection screen
class NoConnectionScreen extends StatelessWidget {
  const NoConnectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.signal_wifi_off, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 24),
              const Text(
                "No Internet Connection",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                "Please check your internet connection and try again.",
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.deepPurpleAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  // Check connection again
                  Connectivity().checkConnectivity().then((result) {
                    if (result != ConnectivityResult.none) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SplashScreen(),
                        ),
                      );
                    }
                  });
                },
                child: const Text("Try Again"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
