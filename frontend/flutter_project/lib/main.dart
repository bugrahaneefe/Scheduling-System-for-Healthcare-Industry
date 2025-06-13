import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:project491/managers/auth_services.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'views/login_view.dart';
import 'views/home_view.dart';
import 'views/room_invitation_view.dart';
import 'package:firebase_core/firebase_core.dart';
import '/firebase_options.dart';
import 'utils/app_localizations.dart';
import 'dart:ui' as ui;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Global error handler: log errors instead of crashing silently
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    // You can also report errors via your error logging service here.
  };

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    initDeepLinks();
  }

  Future<void> initDeepLinks() async {
    _appLinks = AppLinks();

    // Handle incoming links when app is in foreground
    _appLinks.uriLinkStream.listen((uri) {
      handleDeepLink(uri);
    });

    // Handle initial URI if app was started by a deep link
    final uri = await _appLinks.getInitialLink();
    if (uri != null) {
      handleDeepLink(uri);
    }
  }

  void handleDeepLink(Uri uri) {
    if (uri.host == 'room') {
      final roomId = uri.pathSegments.last;

      // Check if user is logged in
      if (authService.value.currentUser == null) {
        // Store the room ID to redirect after login
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => LoginView(pendingRoomId: roomId),
          ),
        );
      } else {
        // User is already logged in, go directly to room invitation
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => RoomInvitationView(roomId: roomId),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthViewModel())],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Nöbetim',
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'), // English
          Locale('tr'), // Turkish
        ],
        locale: ui.window.locale,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: Colors.transparent,
          appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent),
        ),
        home: StreamBuilder<User?>(
          stream: authService.value.authStateChanges,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              );
            }

            if (snapshot.hasData && snapshot.data != null) {
              return FutureBuilder(
                future:
                    Provider.of<AuthViewModel>(
                      context,
                      listen: false,
                    ).loadCurrentUser(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    );
                  }

                  return const HomeView();
                },
              );
            }

            return const LoginView();
          },
        ),
      ),
    );
  }
}
