import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_palace/auth_service.dart';
import 'package:mind_palace/engram_service.dart';
import 'package:mind_palace/models/engram_file.dart';
import 'package:mind_palace/providers/service_providers.dart';
import 'package:mind_palace/screens/gallery_screen.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService()
    : super(
        issuer: 'test',
        clientId: 'test',
        mobileRedirectUrl: 'test://callback',
        engramBaseUrl: 'http://localhost:2080/api/engram/',
      );
}

/// Answers every listing with nothing, so the gallery renders its chrome (the
/// search field included) without reaching the network.
class _EmptyEngram extends EngramService {
  _EmptyEngram()
    : super(auth: _FakeAuthService(), baseUrl: 'http://localhost:2080');

  @override
  Future<List<EngramFile>> listFiles({
    int offset = 0,
    int limit = 50,
    String? query,
    List<String> tags = const [],
    String? fileType,
    DateTime? from,
    DateTime? to,
    String? sort,
    String? scope,
    String? path,
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> listFolders({
    String path = '',
    String? query,
    List<String> tags = const [],
    String? fileType,
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> listTags() async => [];
}

/// Mirrors what the router does with the gallery: the debounced search term is
/// written to `?q=`, and the rebuilt route feeds it straight back in as
/// [GalleryScreen.initialSearchQuery].
class _RouteRoundTrip extends StatefulWidget {
  const _RouteRoundTrip();

  @override
  State<_RouteRoundTrip> createState() => _RouteRoundTripState();
}

class _RouteRoundTripState extends State<_RouteRoundTrip> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return GalleryScreen(
      initialSearchQuery: _query,
      onOpenDetail: (_) {},
      refreshTrigger: 0,
      onRouteStateChanged:
          ({
            required searchQuery,
            required selectedType,
            required selectedTags,
            required viewMode,
            required groupingMode,
            required folderPath,
          }) {
            if (searchQuery == _query) return;
            setState(() => _query = searchQuery);
          },
    );
  }
}

Finder get _searchField => find.byType(TextField).first;

TextEditingController _controllerOf(WidgetTester tester) =>
    tester.widget<TextField>(_searchField).controller!;

Future<void> _pumpGallery(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        engramServiceProvider.overrideWith((ref) async => _EmptyEngram()),
      ],
      child: const MaterialApp(home: Scaffold(body: _RouteRoundTrip())),
    ),
  );
  await tester.pump();
}

/// Runs [body] as web/desktop, where `EditableText.selectAllOnFocus` defaults
/// to true. flutter_test reports Android unless told otherwise, and on Android
/// an invalid selection recovers to a collapsed caret instead — so without this
/// these tests pass even against the unfixed code.
///
/// The override is cleared inside the body because flutter_test asserts that
/// foundation debug variables are unset before the test body returns.
Future<void> asDesktop(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  // Regression: the debounced query round-tripped through the route and landed
  // in `didUpdateWidget`, which assigned `TextEditingController.text`. That
  // setter resets the selection to offset -1, and EditableText answers an
  // invalid selection on a focused field by re-applying selectAllOnFocus — so
  // the whole query came back selected and the next character the user typed
  // replaced it instead of extending it.
  testWidgets('route round-trip does not select the whole query', (
    tester,
  ) async {
    await asDesktop(() async {
      await _pumpGallery(tester);

      await tester.enterText(_searchField, 'bank');
      // Past the 300ms debounce, so the query reaches the route and comes back.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      final controller = _controllerOf(tester);
      expect(controller.text, 'bank');
      expect(
        controller.selection,
        isNot(const TextSelection(baseOffset: 0, extentOffset: 4)),
        reason: 'the field must not select itself while the user is typing',
      );
      expect(controller.selection.isCollapsed, isTrue);
      expect(controller.selection.baseOffset, 'bank'.length);
    });
  });

  testWidgets('a trailing space the user just typed survives the round-trip', (
    tester,
  ) async {
    await asDesktop(() async {
      await _pumpGallery(tester);

      // The route only ever carries the trimmed query, so a naive text-equality
      // guard would clip this space back out mid-word.
      await tester.enterText(_searchField, 'bank ');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(_controllerOf(tester).text, 'bank ');
    });
  });

  // Regression: the clear button read `_searchCtrl.text` during build without
  // listening to the controller, so it only appeared when something else
  // rebuilt the gallery — the debounced provider update, 300ms later. It has
  // to track the keystroke.
  testWidgets(
    'clear button appears and clears without waiting for the debounce',
    (tester) async {
      await asDesktop(() async {
        await _pumpGallery(tester);
        expect(find.byIcon(Icons.clear), findsNothing);

        await tester.enterText(_searchField, 'bank');
        // Deliberately short of the 300ms debounce.
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          find.byIcon(Icons.clear),
          findsOneWidget,
          reason: 'the button must not wait for the debounced provider update',
        );

        await tester.tap(find.byIcon(Icons.clear));
        await tester.pump(const Duration(milliseconds: 50));
        expect(_controllerOf(tester).text, isEmpty);
        expect(
          find.byIcon(Icons.clear),
          findsNothing,
          reason: 'and must not linger a debounce past the last character',
        );

        // Drain the debounce so no timer outlives the test.
        await tester.pump(const Duration(milliseconds: 400));
      });
    },
  );
}
