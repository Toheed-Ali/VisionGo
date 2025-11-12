import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visiongo/main.dart'; // <-- replace with your actual app package

void main() {
  testWidgets('App loads and shows Login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Verify Login screen shows up
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Signup'), findsOneWidget);
  });

  testWidgets('Navigate to Signup screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Tap "Signup" button
    await tester.tap(find.text('Signup'));
    await tester.pumpAndSettle();

    // Verify signup screen loaded
    expect(find.text('Create Account'), findsOneWidget);
  });

  testWidgets('Navigate to Gallery screen after login', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Tap "Login" button
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    // Verify gallery/home screen
    expect(find.text('Gallery'), findsOneWidget);
  });

  testWidgets('Open Live Detection screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Go to login -> gallery
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    // Tap Live Detection icon/button
    final liveButton = find.byIcon(Icons.camera_alt);
    expect(liveButton, findsOneWidget);

    await tester.tap(liveButton);
    await tester.pumpAndSettle();

    // Verify Live Detection screen
    expect(find.text('LIVE'), findsOneWidget);
  });
}
