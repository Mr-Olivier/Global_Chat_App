// import 'package:flutter/material.dart';
// import 'package:flutter/src/widgets/framework.dart';
// import 'package:flutter/src/widgets/placeholder.dart';
// import 'package:globalchat/providers/userProvider.dart';
// import 'package:globalchat/screens/dashboard_screen.dart';
// import 'package:globalchat/screens/login_screen.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:provider/provider.dart';

// class SplashScreen extends StatefulWidget {
//   const SplashScreen({super.key});

//   @override
//   State<SplashScreen> createState() => _SplashScreenState();
// }

// class _SplashScreenState extends State<SplashScreen> {
//   var user = FirebaseAuth.instance.currentUser;

//   @override
//   void initState() {
// // Check for user login status..

//     Future.delayed(Duration(seconds: 2), () {
//       if (user == null) {
//         openLogin();
//       } else {
//         openDashboard();
//       }
//     });

//     // TODO: implement initState
//     super.initState();
//   }

//   void openDashboard() {
//     Provider.of<UserProvider>(context, listen: false).getUserDetails();

//     Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) {
//       return DashboardScreen();
//     }));
//   }

//   void openLogin() {
//     Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) {
//       return LoginScreen();
//     }));
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//         body: Center(
//             child: SizedBox(
//                 height: 100,
//                 width: 100,
//                 child: Image.asset("assets/images/logo.png"))));
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:globalchat/providers/userProvider.dart';
import 'package:globalchat/screens/dashboard_screen.dart';
import 'package:globalchat/screens/landing_page.dart';
import 'package:globalchat/screens/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  late AnimationController _animationController;
  bool _hasCheckedAuth = false;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Start the animation
    _animationController.forward();

    // Listen for animation completion to check authentication
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_hasCheckedAuth) {
        _checkAuthStatus();
        _hasCheckedAuth = true;
      }
    });

    // Set status bar color
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    // Add a small delay to show animation
    await Future.delayed(const Duration(milliseconds: 500));

    if (user == null) {
      _navigateToLandingPage();
    } else {
      _loadUserDataAndNavigate();
    }
  }

  void _navigateToLandingPage() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => const LandingPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  void _loadUserDataAndNavigate() {
    // Get user details from provider
    Provider.of<UserProvider>(context, listen: false).getUserDetails();

    // Navigate to dashboard
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => const DashboardScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo animation
            Hero(
              tag: 'app_logo',
              child: SizedBox(
                height: 140,
                width: 140,
                child: Image.asset("assets/images/logo.png"),
              ),
            ),

            const SizedBox(height: 40),

            // Text with animated fade in
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Opacity(
                  opacity: _animationController.value,
                  child: child,
                );
              },
              child: const Column(
                children: [
                  Text(
                    "GlobalChat",
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurpleAccent,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Connect with the world",
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 60),

            // Loading animation
            SizedBox(
              height: 100,
              width: 100,
              child: Lottie.asset(
                'assets/animations/loading_dots.json',
                fit: BoxFit.contain,
                controller: _animationController,
                onLoaded: (composition) {
                  // Configure the animation controller
                  _animationController.duration = composition.duration;
                  _animationController.forward();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
