import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/staff_api_service.dart';
import 'staff_auth_provider.dart';

final staffTransactionsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final auth = ref.watch(staffAuthProvider);
  final isLoggedIn = auth.status == StaffAuthStatus.authenticated;
  if (!isLoggedIn) {
    return const <String, dynamic>{'success': false, 'data': <dynamic>[]};
  }
  final api = ref.watch(staffApiServiceProvider);
  return api.getTransactions(page: 1, limit: 20);
});

