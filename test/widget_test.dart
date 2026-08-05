// Basic smoke test for the SmartSpend app.
//
// BUG FIX: this file used to be the untouched default Flutter counter demo
// test. It imported a non-existent `MyApp` from the `shimmer` package
// (`package:shimmer/main.dart show MyApp` — shimmer has no such file/class)
// and then tried to pump `MyApp()`, which doesn't exist anywhere in this
// project either (the real root widget is `SmartSpendApp`). That made the
// whole test file fail to compile, which is almost certainly what showed up
// in your IDE as confusing "isn't a class" errors — a broken test file can
// make the analyzer report unrelated-looking errors elsewhere in the
// project. This rewrite actually tests the real app.
//
// Firebase.initializeApp() needs platform channels that aren't available in
// the plain `flutter test` environment, so this test stubs Firebase using
// firebase_core's test hooks instead of calling main(). It only checks that
// the splash screen renders, which is a safe, dependency-free smoke test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';

import 'package:smartfundmanagement/screens/splash_screen.dart';

class MockFirebaseCorePlatform extends FirebasePlatform {
  MockFirebaseCorePlatform() : super();

  final FirebaseAppPlatform _app = _MockFirebaseAppPlatform();

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) => _app;

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    return _app;
  }

  @override
  List<FirebaseAppPlatform> get apps => [_app];
}

class _MockFirebaseAppPlatform extends FirebaseAppPlatform {
  _MockFirebaseAppPlatform()
      : super(
          defaultFirebaseAppName,
          const FirebaseOptions(
            apiKey: 'test-api-key',
            appId: 'test-app-id',
            messagingSenderId: 'test-sender-id',
            projectId: 'test-project',
          ),
        );
}

void main() {
  setupFirebaseCoreMocks();

  setUpAll(() async {
    FirebasePlatform.instance = MockFirebaseCorePlatform();
    await Firebase.initializeApp();
  });

  testWidgets('SplashScreen renders the app name', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    // Verify the splash screen shows the app branding.
    expect(find.text('SmartSpend'), findsOneWidget);
    expect(find.text('AI-Powered Finance Tracker'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

/// Minimal method-channel mock so `Firebase.initializeApp()` doesn't try to
/// talk to a real native platform during `flutter test`.
void setupFirebaseCoreMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();
}
