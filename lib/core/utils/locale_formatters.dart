import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Locale-aware date and number formatting utilities
/// 
/// This class provides formatting methods that automatically adapt to the
/// current application locale for dates, numbers, and currency.
class LocaleFormatters {
  LocaleFormatters._();

  // ============================================================================
  // DATE FORMATTING
  // ============================================================================

  /// Format date as "3 Şubat 2026" (TR) or "February 3, 2026" (EN)
  static String formatDate(DateTime date, Locale locale) {
    final format = DateFormat.yMMMMd(locale.languageCode);
    return format.format(date);
  }

  /// Format date as "3 Şub 2026" (TR) or "Feb 3, 2026" (EN)
  static String formatDateShort(DateTime date, Locale locale) {
    final format = DateFormat.yMMMd(locale.languageCode);
    return format.format(date);
  }

  /// Format date as "03.02.2026" (TR) or "02/03/2026" (EN)
  static String formatDateNumeric(DateTime date, Locale locale) {
    final format = DateFormat.yMd(locale.languageCode);
    return format.format(date);
  }

  /// Format time as "14:30"
  static String formatTime(DateTime time, Locale locale) {
    final format = DateFormat.Hm(locale.languageCode);
    return format.format(time);
  }

  /// Format date and time as "3 Şubat 2026 14:30" (TR) or "February 3, 2026 2:30 PM" (EN)
  static String formatDateTime(DateTime dateTime, Locale locale) {
    final format = DateFormat.yMMMMd(locale.languageCode).add_jm();
    return format.format(dateTime);
  }

  /// Format relative date (e.g., "2 gün önce", "2 days ago")
  static String formatRelativeDate(DateTime date, Locale locale) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (locale.languageCode == 'tr') {
      return _formatRelativeDateTurkish(difference);
    } else {
      return _formatRelativeDateEnglish(difference);
    }
  }

  static String _formatRelativeDateTurkish(Duration difference) {
    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'yıl' : 'yıl'} önce';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'ay' : 'ay'} önce';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'gün' : 'gün'} önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'saat' : 'saat'} önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'dakika' : 'dakika'} önce';
    } else {
      return 'Şimdi';
    }
  }

  static String _formatRelativeDateEnglish(Duration difference) {
    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  /// Format date range as "3-5 Şubat" (TR) or "Feb 3-5" (EN)
  static String formatDateRange(DateTimeRange range, Locale locale) {
    final start = range.start;
    final end = range.end;

    // Same day
    if (start.year == end.year && start.month == end.month && start.day == end.day) {
      return formatDateShort(start, locale);
    }

    // Same month
    if (start.year == end.year && start.month == end.month) {
      if (locale.languageCode == 'tr') {
        final monthFormat = DateFormat.MMMM(locale.languageCode);
        return '${start.day}-${end.day} ${monthFormat.format(start)}';
      } else {
        final monthFormat = DateFormat.MMM(locale.languageCode);
        return '${monthFormat.format(start)} ${start.day}-${end.day}';
      }
    }

    // Different months
    return '${formatDateShort(start, locale)} - ${formatDateShort(end, locale)}';
  }

  /// Format day of week as "Pazartesi" (TR) or "Monday" (EN)
  static String formatDayOfWeek(DateTime date, Locale locale) {
    final format = DateFormat.EEEE(locale.languageCode);
    return format.format(date);
  }

  /// Format month as "Şubat" (TR) or "February" (EN)
  static String formatMonth(DateTime date, Locale locale) {
    final format = DateFormat.MMMM(locale.languageCode);
    return format.format(date);
  }

  // ============================================================================
  // NUMBER FORMATTING
  // ============================================================================

  /// Format number with locale-specific separators
  /// TR: 1.234,56
  /// EN: 1,234.56
  static String formatNumber(num number, Locale locale) {
    final format = NumberFormat.decimalPattern(locale.languageCode);
    return format.format(number);
  }

  /// Format number with specific decimal places
  static String formatNumberWithDecimals(num number, int decimals, Locale locale) {
    final format = NumberFormat.decimalPatternDigits(
      locale: locale.languageCode,
      decimalDigits: decimals,
    );
    return format.format(number);
  }

  /// Format as percentage (e.g., "75%")
  static String formatPercentage(num number, Locale locale) {
    final format = NumberFormat.percentPattern(locale.languageCode);
    return format.format(number / 100);
  }

  /// Format as compact number (e.g., "1.2K", "1.2B")
  static String formatCompactNumber(num number, Locale locale) {
    final format = NumberFormat.compact(locale: locale.languageCode);
    return format.format(number);
  }

  // ============================================================================
  // CURRENCY FORMATTING
  // ============================================================================

  /// Format as Turkish Lira
  /// TR: ₺1.234,56
  /// EN: ₺1,234.56
  static String formatCurrency(num amount, Locale locale) {
    final format = NumberFormat.currency(
      locale: locale.languageCode,
      symbol: '₺',
      decimalDigits: 2,
    );
    return format.format(amount);
  }

  /// Format as currency without symbol
  static String formatCurrencyNoSymbol(num amount, Locale locale) {
    final format = NumberFormat.currency(
      locale: locale.languageCode,
      symbol: '',
      decimalDigits: 2,
    );
    return format.format(amount).trim();
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Check if date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  /// Check if date is tomorrow
  static bool isTomorrow(DateTime date) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return date.year == tomorrow.year && 
           date.month == tomorrow.month && 
           date.day == tomorrow.day;
  }

  /// Check if date is this week
  static bool isThisWeek(DateTime date) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    return date.isAfter(startOfWeek) && date.isBefore(endOfWeek);
  }
}
