import 'package:dio/dio.dart';

import '../../../../core/network/staff_api_service.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/pos_menu_item.dart';
import '../../domain/entities/staff_facility.dart';
import '../../domain/entities/validated_customer.dart';

/// Maps backend error codes (staff_mobile.md §4.3 & §4.4) to Turkish messages.
String _mapErrorCode(String? code, String fallback) {
  switch (code) {
    case 'MISSING_TOKEN':
      return 'QR kodu veya 6 haneli kod gerekli.';
    case 'INVALID_FORMAT':
      return 'Geçersiz token formatı.';
    case 'INVALID_SIGNATURE':
      return 'QR kodu doğrulanamadı.';
    case 'TOKEN_EXPIRED':
      return 'QR kodunun süresi dolmuş. Müşteriden yeni kod isteyin.';
    case 'TOKEN_NOT_ACTIVE':
      return 'QR kodu aktif değil.';
    case 'TOKEN_MISMATCH':
      return 'QR kodu eşleşmedi.';
    case 'TOKEN_VERSION_MISMATCH':
      return 'Eski QR formatı. Müşterinin uygulamayı güncellemesi gerekli.';
    case 'TOKEN_ALREADY_USED':
      return 'Bu QR kodu zaten kullanıldı.';
    case 'CODE_INVALID_OR_EXPIRED':
    case 'CODE_EXPIRED':
      return 'Girilen kodun süresi dolmuş veya geçersiz.';
    case 'USER_NOT_FOUND':
      return 'Kullanıcı bulunamadı.';
    case 'VALIDATION_ERROR':
      return 'Doğrulama sırasında hata oluştu. Tekrar deneyin.';
    case 'EMPTY_CART':
      return 'Sepet boş. En az bir ürün veya manuel tutar girin.';
    case 'INVALID_ITEM':
      return 'Geçersiz menü kalemi.';
    case 'INVALID_QUANTITY':
      return 'Ürün miktarı 1-99 arasında olmalı.';
    case 'INVALID_MANUAL_AMOUNT':
      return 'Manuel tutar 0-50000 puan arasında olmalı.';
    case 'AMOUNT_TOO_HIGH':
      return 'Tek işlemde en fazla 50.000 puan harcanabilir.';
    case 'MENU_ITEM_NOT_FOUND':
      return 'Menü kalemi bulunamadı.';
    case 'MENU_FACILITY_MISMATCH':
      return 'Bu menü kalemi tesise ait değil.';
    case 'FACILITY_REQUIRED':
    case 'MISSING_FACILITY':
      return 'İşlem için önce bir tesis seçmelisiniz.';
    case 'NO_FACILITY':
      return 'Size atanmış tesis bulunmuyor. Yöneticinizden tesis ataması isteyin.';
    case 'FACILITY_NOT_ALLOWED':
      return 'Bu tesis için işlem yetkiniz yok.';
    case 'INSUFFICIENT_POINTS':
      return 'Bakiye yetersiz. Sepeti düzenleyin veya müşteriden yeni kod isteyin.';
    case 'DUPLICATE_TRANSACTION':
      return 'Bu işlem zaten yapıldı.';
    default:
      return fallback;
  }
}

/// Extracts a user-friendly Turkish error message from a [DioException].
String staffDioErrorMessage(DioException e) {
  final data = e.response?.data;
  if (data is Map) {
    final code = data['error']?.toString();
    final msg = data['message']?.toString() ?? 'Bilinmeyen hata.';
    return _mapErrorCode(code, msg);
  }
  if (e.type == DioExceptionType.connectionTimeout) {
    return 'Sunucuya bağlanılamadı. Hotspot\'un açık olduğundan emin olun.';
  }
  if (e.type == DioExceptionType.receiveTimeout) {
    return 'Sunucu yanıt vermiyor. Tekrar deneyin.';
  }
  if (e.response?.statusCode == 401) {
    return 'Oturum süresi doldu. Tekrar giriş yapın.';
  }
  return e.message ?? 'Sunucuya bağlanılamadı.';
}

class StaffPosRepository {
  StaffPosRepository(this._api);

  final StaffApiService _api;

  Future<List<StaffFacility>> getFacilities() async {
    try {
      final json = await _api.getStaffFacilities();
      final raw = (json['facilities'] as List?) ?? const [];
      return raw
          .whereType<Map>()
          .map((e) => StaffFacility.fromJson(e.cast<String, dynamic>()))
          .where((f) => f.id.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (e) {
      throw Exception(staffDioErrorMessage(e));
    }
  }

  Future<List<PosMenuItem>> getMenu({String? facilityId}) async {
    try {
      final json = await _api.getPosMenu(facilityId: facilityId);
      final items = (json['items'] as List?) ?? const [];
      return items
          .whereType<Map>()
          .map((e) => PosMenuItem.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false);
    } on DioException catch (e) {
      throw Exception(staffDioErrorMessage(e));
    }
  }

  Future<ValidatedCustomer> validate({
    required String tokenOrCode,
    required int requestedAmount,
  }) async {
    try {
      final json = await _api.validateTokenOrCode(
        tokenOrCode: tokenOrCode,
        requestedAmount: requestedAmount,
      );
      return ValidatedCustomer.fromJson(json, tokenOrCode: tokenOrCode);
    } on DioException catch (e) {
      throw Exception(staffDioErrorMessage(e));
    }
  }

  Future<Map<String, dynamic>> checkout({
    required String tokenOrCode,
    required List<CartItem> cart,
    required int manualAmount,
    String? facilityId,
  }) async {
    final items = cart
        .map(
          (e) => <String, dynamic>{
            'id': e.menuItemId,
            'qty': e.quantity,
          },
        )
        .toList(growable: false);

    try {
      return await _api.checkout(
        tokenOrCode: tokenOrCode,
        items: items,
        manualAmount: manualAmount,
        facilityId: facilityId,
      );
    } on DioException catch (e) {
      // DUPLICATE_TRANSACTION is treated as success (idempotency)
      final code =
          e.response?.data is Map ? e.response?.data['error']?.toString() : null;
      if (code == 'DUPLICATE_TRANSACTION') {
        return {'success': true, 'data': e.response?.data};
      }
      throw Exception(staffDioErrorMessage(e));
    }
  }
}

