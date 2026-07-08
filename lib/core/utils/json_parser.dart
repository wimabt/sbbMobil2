import 'package:flutter/foundation.dart';

/// JsonParser - Isolate-based JSON parsing utility
///
/// Moves heavy JSON parsing to background isolates using Flutter's compute().
/// This prevents UI jank caused by parsing large JSON responses on the main thread.
///
/// **IMPORTANT — Isolate Safety:**
/// `compute()` sends parameters via `SendPort`, which only supports
/// serializable data. Function references MUST be top-level or static
/// tear-offs (e.g., `Place.fromJson`). Closures and instance method
/// tear-offs will cause `Invalid argument(s)` at runtime.
///
/// As a safety net, all `compute()` calls are wrapped in try-catch:
/// if sending fails (e.g., closure passed), parsing falls back to
/// the main thread with a debug warning.
///
/// Usage:
/// ```dart
/// final places = await JsonParser.parseList(
///   jsonList,
///   Place.fromJson, // ← must be a static/top-level function
/// );
/// ```
class JsonParser {
  JsonParser._();

  /// Parse a list of JSON objects in a background isolate.
  ///
  /// Use this for large lists (>20 items) to avoid UI jank.
  /// [fromJson] MUST be a top-level or static function — not a closure.
  static Future<List<T>> parseList<T>(
    List<dynamic> jsonList,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    // For small lists, parse synchronously to avoid isolate overhead
    if (jsonList.length < 20) {
      return jsonList
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // For large lists, attempt background isolate parsing
    try {
      return await compute(
        _parseListInIsolate<T>,
        _ParseParams(jsonList: jsonList, fromJson: fromJson),
      );
    } catch (e) {
      // Fallback: if compute() fails (e.g., closure passed instead of
      // static tear-off), parse on main thread and log a warning.
      debugPrint(
        '⚠️ [JsonParser] compute() failed — falling back to main thread. '
        'Ensure fromJson is a top-level/static function, not a closure.\n'
        'Error: $e',
      );
      return jsonList
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  /// Parse a single JSON object (always synchronous — isolate overhead not worth it).
  static Future<T> parseSingle<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    return fromJson(json);
  }

  /// Parse JSON response with metadata in a background isolate.
  ///
  /// Returns both the parsed data and raw metadata.
  /// [parseData] MUST be a top-level or static function — not a closure.
  static Future<ParsedResponse<T>> parseResponse<T>(
    Map<String, dynamic> responseJson,
    List<T> Function(List<dynamic>) parseData,
  ) async {
    final data = responseJson['data'];
    if (data == null || data is! List) {
      return ParsedResponse(
        data: <T>[],
        meta: responseJson,
      );
    }

    // For large responses, attempt background isolate parsing
    if (data.length >= 20) {
      try {
        return await compute(
          _parseResponseInIsolate<T>,
          _ResponseParams(responseJson: responseJson, parseData: parseData),
        );
      } catch (e) {
        // Fallback: parse on main thread if compute() fails
        debugPrint(
          '⚠️ [JsonParser] compute() failed for parseResponse — '
          'falling back to main thread. '
          'Ensure parseData is a top-level/static function, not a closure.\n'
          'Error: $e',
        );
        return ParsedResponse(
          data: parseData(data),
          meta: responseJson,
        );
      }
    }

    return ParsedResponse(
      data: parseData(data),
      meta: responseJson,
    );
  }
}

/// Internal: Parse list in isolate (top-level function — required by compute())
List<T> _parseListInIsolate<T>(_ParseParams<T> params) {
  return params.jsonList
      .map((e) => params.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// Internal: Parse response in isolate (top-level function — required by compute())
ParsedResponse<T> _parseResponseInIsolate<T>(_ResponseParams<T> params) {
  final data = params.responseJson['data'] as List? ?? [];
  return ParsedResponse(
    data: params.parseData(data),
    meta: params.responseJson,
  );
}

/// Parameters for list parsing in isolate.
///
/// WARNING: [fromJson] must be a top-level or static function tear-off.
/// Closures capture variables from their enclosing scope and cannot be
/// sent across isolate boundaries via SendPort.
class _ParseParams<T> {
  final List<dynamic> jsonList;
  final T Function(Map<String, dynamic>) fromJson;

  _ParseParams({
    required this.jsonList,
    required this.fromJson,
  });
}

/// Parameters for response parsing in isolate.
///
/// WARNING: [parseData] must be a top-level or static function tear-off.
/// See [_ParseParams] for details.
class _ResponseParams<T> {
  final Map<String, dynamic> responseJson;
  final List<T> Function(List<dynamic>) parseData;

  _ResponseParams({
    required this.responseJson,
    required this.parseData,
  });
}

/// Parsed response with data and metadata
class ParsedResponse<T> {
  final List<T> data;
  final Map<String, dynamic> meta;

  ParsedResponse({
    required this.data,
    required this.meta,
  });
}
