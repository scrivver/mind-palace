import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mind_palace/main.dart';
import 'package:mind_palace/providers/service_providers.dart';
import 'package:mind_palace/providers/theme_provider.dart';
import 'package:mind_palace/services/theme_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('MindPalaceApp renders with ProviderScope', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeServiceProvider.overrideWithValue(ThemeService()),
          authServiceProvider.overrideWith(
            (ref) => throw UnimplementedError('stub'),
          ),
        ],
        child: const MindPalaceApp(),
      ),
    );
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
