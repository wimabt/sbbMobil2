/// Handler'lar için ortak yardımcılar.
///
/// **Provider lazy-load problemi:**
/// Mevcut feature provider'ları (`eventsListProvider`, `placesProvider` vb.)
/// `build()` içinde `Future.microtask(() => load())` ile veriyi sonradan
/// çekiyor. Chatbot ekranı açılıp da o provider'a daha hiç dokunulmadıysa,
/// handler ilk read'inde state.isLoading=true ve liste boş geliyor.
/// Bu durumda kullanıcıya "etkinlik yok" demek yanlış — biraz beklemeli.
///
/// `waitForData` küçük bir polling helper'ı: en fazla [maxWait] kadar bekler,
/// arada [poll] aralıklarıyla [check] fonksiyonunu çağırır. `true` dönerse
/// veri hazırdır.
library;

import 'dart:async';

Future<bool> waitForData({
  required bool Function() check,
  Duration maxWait = const Duration(seconds: 2),
  Duration poll = const Duration(milliseconds: 150),
}) async {
  if (check()) return true;
  final deadline = DateTime.now().add(maxWait);
  while (DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(poll);
    if (check()) return true;
  }
  return check();
}
