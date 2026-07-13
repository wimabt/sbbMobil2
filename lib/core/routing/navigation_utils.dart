import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Merkezî geri navigasyon politikası.
///
/// Uygulama '/' (ana sayfa) üzerinden açılır; geri hareketi kullanıcıyı
/// hiçbir zaman boş yığında bırakıp uygulamayı kapatmamalı:
///  1. Yığında pop edilecek sayfa varsa pop et,
///  2. yoksa ana sayfaya dön.
/// Ana sayfadan çıkış ise [ScaffoldShell] içindeki PopScope tarafından
/// (standart davranış olarak) sisteme bırakılır.
extension SafeBackNavigation on BuildContext {
  void popOrHome() {
    if (canPop()) {
      pop();
    } else {
      go('/');
    }
  }
}

/// Shell içindeki üst seviye rotalar için sistem geri hareketi koruması.
///
/// ÖNEMLİ: Bu widget rotanın KENDİ sayfasının içinde olmalı (app_router'da
/// route builder'ı sarar). Android predictive back, geri jestini uygulamaya
/// iletip iletmemeye en içteki navigator'ın SON SAYFASININ PopScope durumuna
/// bakarak karar verir; shell/kök seviyesindeki bir PopScope bu karara
/// katılmaz ve uygulama doğrudan kapanır (bkz. Navigator._handleHistoryChanged).
///
/// Davranış: yığında sayfa varsa normal pop (iOS swipe dahil), yoksa geri
/// hareketi uygulamayı kapatmak yerine ana sayfaya döndürür. Ana sayfa ('/')
/// bilinçli olarak sarılmaz — oradan geri, standart şekilde uygulamadan çıkar.
class PopOrHomeScope extends StatelessWidget {
  const PopOrHomeScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // context.canPop() DEĞİL: o, üstteki sayfaları da sayar ve build anında
    // donar (örn. derin bağlantıyla [liste, detay] kurulup detay pop edilince
    // bayat true kalır → geri, uygulamayı kapatır). ModalRoute.canPop ise
    // "bu rotanın ALTINDA sayfa var mı?" sorusuna bakar, üstten bağımsızdır
    // ve inherited bağımlılık sayesinde değişimde yeniden build tetikler.
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.popOrHome();
      },
      child: child,
    );
  }
}
