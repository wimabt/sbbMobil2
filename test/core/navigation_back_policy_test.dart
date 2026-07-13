import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:sbb_mobile/core/routing/navigation_utils.dart';

/// Geri navigasyon politikası testleri.
///
/// Uygulamadaki yapının küçültülmüş kopyası: ShellRoute + sekmeler.
/// Politika: sekmedeyken sistem geri → ana sayfa; detay açıkken → normal pop;
/// ana sayfada → pop edilecek bir şey yok (uygulama kapanışı sisteme kalır).
void main() {
  GoRouter buildRouter() {
    return GoRouter(
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (context, state, child) => Scaffold(body: child),
          routes: [
            GoRoute(
              path: '/',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: Text('home')),
            ),
            GoRoute(
              path: '/map',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: PopOrHomeScope(child: Text('map')),
              ),
              routes: [
                GoRoute(
                  path: 'detail',
                  builder: (context, state) => const Text('map-detail'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<GoRouter> pumpApp(WidgetTester tester) async {
    final router = buildRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('sekmede sistem geri ana sayfaya döner, uygulamadan çıkmaz',
      (tester) async {
    final router = await pumpApp(tester);

    router.go('/map');
    await tester.pumpAndSettle();
    expect(find.text('map'), findsOneWidget);

    // Sistem geri hareketi (Android geri jesti / tuşu)
    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue,
        reason: 'Geri olayı framework içinde işlenmeli (uygulama kapanmamalı)');
    expect(router.state.uri.path, '/');
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('detay açıkken sistem geri normal pop yapar', (tester) async {
    final router = await pumpApp(tester);

    router.go('/map/detail');
    await tester.pumpAndSettle();
    expect(find.text('map-detail'), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(router.state.uri.path, '/map');

    // Bir kez daha geri: sekmeden ana sayfaya
    final handled2 = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(handled2, isTrue);
    expect(router.state.uri.path, '/');
  });

  testWidgets('ana sayfada sistem geri framework tarafından işlenmez (çıkış)',
      (tester) async {
    final router = await pumpApp(tester);
    expect(router.state.uri.path, '/');

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // Ana sayfada pop edilecek bir şey yok: false döner, çıkışı sistem yapar.
    expect(handled, isFalse);
  });

  testWidgets(
      'Android predictive back: sekmedeyken framework "geri işlerim" bildirir',
      (tester) async {
    // Android 13+ geri jesti, framework setFrameworkHandlesBack(false) derse
    // uygulamaya hiç iletilmez ve aktivite doğrudan kapanır. Sekmedeyken bu
    // bildirimin true olması, "geri → ana sayfa" politikasının ön koşuludur.
    final frameworkHandlesBack = <bool>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
          frameworkHandlesBack.add(call.arguments as bool);
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    // WidgetsApp, lifecycle henüz bildirilmemişse OS'a geri bildirimi
    // göndermez; gerçek cihazdaki gibi "resumed" duruma getir.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    addTearDown(() => tester.binding.readTestInitialLifecycleStateFromNativeWindow());

    final router = await pumpApp(tester);

    router.go('/map');
    await tester.pumpAndSettle();

    expect(frameworkHandlesBack, isNotEmpty,
        reason: 'Navigasyon sonrası OS\'a geri bildirimi gönderilmeli');
    expect(frameworkHandlesBack.last, isTrue,
        reason: 'Sekmedeyken OS geri jestini uygulamaya iletmeli '
            '(false olsaydı uygulama doğrudan kapanırdı)');
  });
}
