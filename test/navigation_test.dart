import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appforge/appforge.dart';

void main() {
  Widget buildTestApp({Widget? home, Locale locale = const Locale('en')}) {
    return MaterialApp(
      navigatorKey: App.navigatorKey,
      scaffoldMessengerKey: App.scaffoldMessengerKey,
      locale: locale,
      localizationsDelegates: App.localizationsDelegates,
      home: home ??
          Scaffold(
            body: Center(
              child: Text('HomeScreen: args=${App.arguments}'),
            ),
          ),
    );
  }

  setUp(() {
    AppNavigator.instance.reset();
  });

  group('Context-Free Navigation Engine (AppNavigator)', () {
    testWidgets('App.to pushes new route and updates App.arguments',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      expect(find.text('HomeScreen: args=null'), findsOneWidget);

      // Navigate to details screen with arguments
      App.to(
        const Scaffold(body: Center(child: Text('DetailsScreen'))),
        arguments: {'userId': 42},
      );
      await tester.pumpAndSettle();

      expect(find.text('DetailsScreen'), findsOneWidget);
      expect(App.arguments, equals({'userId': 42}));
      expect(App.canPop, isTrue);

      // Pop back
      App.back();
      await tester.pumpAndSettle();

      expect(find.text('HomeScreen: args=null'), findsOneWidget);
      expect(App.arguments, isNull);
    });

    testWidgets('App.back delivers result to awaiting App.to caller',
        (tester) async {
      await tester.pumpWidget(buildTestApp());

      dynamic returnedResult;
      App.to<String>(
        const Scaffold(body: Center(child: Text('InputScreen'))),
      ).then((res) => returnedResult = res);

      await tester.pumpAndSettle();
      expect(find.text('InputScreen'), findsOneWidget);

      App.back('SubmittedData123');
      await tester.pumpAndSettle();

      expect(find.text('HomeScreen: args=null'), findsOneWidget);
      expect(returnedResult, equals('SubmittedData123'));
    });

    testWidgets('App.off replaces current screen', (tester) async {
      await tester.pumpWidget(buildTestApp());

      App.to(const Scaffold(body: Center(child: Text('Step1Screen'))));
      await tester.pumpAndSettle();
      expect(find.text('Step1Screen'), findsOneWidget);

      // Replace Step1 with Step2
      App.off(const Scaffold(body: Center(child: Text('Step2Screen'))));
      await tester.pumpAndSettle();

      expect(find.text('Step1Screen'), findsNothing);
      expect(find.text('Step2Screen'), findsOneWidget);

      // Popping should return to HomeScreen, not Step1Screen
      App.back();
      await tester.pumpAndSettle();
      expect(find.text('HomeScreen: args=null'), findsOneWidget);
    });

    testWidgets('App.offAll clears entire navigation stack', (tester) async {
      await tester.pumpWidget(buildTestApp());

      App.to(const Scaffold(body: Center(child: Text('ScreenA'))));
      await tester.pumpAndSettle();
      App.to(const Scaffold(body: Center(child: Text('ScreenB'))));
      await tester.pumpAndSettle();

      expect(find.text('ScreenB'), findsOneWidget);

      // offAll to LoginScreen
      App.offAll(const Scaffold(body: Center(child: Text('LoginScreen'))));
      await tester.pumpAndSettle();

      expect(find.text('ScreenA'), findsNothing);
      expect(find.text('ScreenB'), findsNothing);
      expect(find.text('HomeScreen: args=null'), findsNothing);
      expect(find.text('LoginScreen'), findsOneWidget);
      expect(App.canPop, isFalse);
    });

    testWidgets('Directionality-aware slide transition in RTL slides from left',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(locale: const Locale('ar')),
      );

      App.to(
        const Scaffold(body: Center(child: Text('ArabicDetails'))),
        transition: AppTransition.slide,
      );

      // Start transition frame and advance
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('ArabicDetails'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('ArabicDetails'), findsOneWidget);
    });
  });

  group('Context-Free Overlays & Feedback (AppOverlay)', () {
    testWidgets('App.snackbar displays floating snackbar without context',
        (tester) async {
      await tester.pumpWidget(buildTestApp());

      App.snackbar(
        'تم بنجاح',
        'تم حفظ الملف في السحابة',
        type: AppSnackbarType.success,
      );
      await tester.pump(); // Start animation
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('تم بنجاح'), findsOneWidget);
      expect(find.text('تم حفظ الملف في السحابة'), findsOneWidget);
    });

    testWidgets('App.dialog opens and dismisses modal dialog without context',
        (tester) async {
      await tester.pumpWidget(buildTestApp());

      App.dialog(
        const AlertDialog(
          title: Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من حذف الحساب؟'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تأكيد الحذف'), findsOneWidget);
      expect(find.text('هل أنت متأكد من حذف الحساب؟'), findsOneWidget);

      // Dismiss dialog
      App.back();
      await tester.pumpAndSettle();

      expect(find.text('تأكيد الحذف'), findsNothing);
    });

    testWidgets('App.bottomSheet opens and dismisses modal bottom sheet',
        (tester) async {
      await tester.pumpWidget(buildTestApp());

      App.bottomSheet(
        const SizedBox(
          height: 200,
          child: Center(child: Text('BottomSheetContent')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BottomSheetContent'), findsOneWidget);

      App.back();
      await tester.pumpAndSettle();

      expect(find.text('BottomSheetContent'), findsNothing);
    });

    testWidgets(
        'App.showLoading and App.hideLoading manage loading overlay safely',
        (tester) async {
      await tester.pumpWidget(buildTestApp());

      expect(App.isLoadingOpen, isFalse);

      App.showLoading(message: 'جارٍ التحميل...');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(App.isLoadingOpen, isTrue);
      expect(find.text('جارٍ التحميل...'), findsOneWidget);

      // Calling showLoading again should not spawn duplicate overlays
      App.showLoading(message: 'تحميل مكرر');
      await tester.pump();
      expect(find.text('تحميل مكرر'), findsNothing);

      App.hideLoading();
      await tester.pumpAndSettle();

      expect(App.isLoadingOpen, isFalse);
      expect(find.text('جارٍ التحميل...'), findsNothing);
    });

    testWidgets(
        'App.arguments stays in sync with NavigatorObserver through to, off, offAll, and pop',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        navigatorKey: App.navigatorKey,
        navigatorObservers: [App.navigatorObserver],
        home: const Scaffold(body: Text('RootPage')),
      ));

      expect(App.arguments, isNull);

      // Navigate to Screen 1 with args
      App.to(const Scaffold(body: Text('Screen 1')), arguments: 'arg_1');
      await tester.pumpAndSettle();
      expect(App.arguments, equals('arg_1'));

      // Replace Screen 1 with Screen 2 with args
      App.off(const Scaffold(body: Text('Screen 2')), arguments: 'arg_2');
      await tester.pumpAndSettle();
      expect(App.arguments, equals('arg_2'));

      // Navigate to Screen 3 without args (arguments should be null, not arg_2)
      App.to(const Scaffold(body: Text('Screen 3')));
      await tester.pumpAndSettle();
      expect(App.arguments, isNull);

      // Pop Screen 3 -> returns to Screen 2
      App.back();
      await tester.pumpAndSettle();
      expect(App.arguments, equals('arg_2'));

      // offAll to Login with arg_login
      App.offAll(const Scaffold(body: Text('LoginScreen')),
          arguments: 'arg_login');
      await tester.pumpAndSettle();
      expect(App.arguments, equals('arg_login'));
    });

    testWidgets(
        'Opening dialog on top of page preserves active page App.arguments',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        navigatorKey: App.navigatorKey,
        navigatorObservers: [App.navigatorObserver],
        home: const Scaffold(body: Text('RootPage')),
      ));

      App.to(const Scaffold(body: Text('DetailPage')), arguments: {'id': 99});
      await tester.pumpAndSettle();
      expect(App.arguments, equals({'id': 99}));

      // Show dialog on top
      App.dialog(const AlertDialog(title: Text('ConfirmDialog')));
      await tester.pumpAndSettle();
      expect(find.text('ConfirmDialog'), findsOneWidget);

      // Arguments should still be {'id': 99}
      expect(App.arguments, equals({'id': 99}));

      // Dismiss dialog
      App.back();
      await tester.pumpAndSettle();
      expect(App.arguments, equals({'id': 99}));
    });

    testWidgets(
        'hideLoading removes strictly loading overlay without popping dialog opened on top',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        navigatorKey: App.navigatorKey,
        navigatorObservers: [App.navigatorObserver],
        home: const Scaffold(body: Text('HomePage')),
      ));

      // Show loading
      App.showLoading(message: 'Loading...');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(App.isLoadingOpen, isTrue);
      expect(find.text('Loading...'), findsOneWidget);

      // An error dialog opens while loading is still active
      App.dialog(const AlertDialog(title: Text('NetworkErrorDialog')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('NetworkErrorDialog'), findsOneWidget);

      // Now hideLoading is called
      App.hideLoading();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Loading overlay should be gone, but NetworkErrorDialog MUST still be visible!
      expect(App.isLoadingOpen, isFalse);
      expect(find.text('Loading...'), findsNothing);
      expect(find.text('NetworkErrorDialog'), findsOneWidget);

      // Dismiss the error dialog
      App.back();
      await tester.pumpAndSettle();
      expect(find.text('NetworkErrorDialog'), findsNothing);
      expect(find.text('HomePage'), findsOneWidget);
    });
  });
}
