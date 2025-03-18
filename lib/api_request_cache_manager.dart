import 'dart:async';

import 'package:api_request/api_request.dart';
import 'package:flutter/material.dart';

class _CacheEntry<T> {
  final T? data;
  final bool isFetching;
  final ValueNotifier<T?> notifier;

  _CacheEntry({this.data, this.isFetching = false})
      : notifier = ValueNotifier<T?>(data);
}

class ApiRequestCacheManager {
  static final Map<String, _CacheEntry> _cache = {};

  static void store<T>(String key, T data, {bool isFetching = false}) {
    if (_cache.containsKey(key)) {
      _cache[key]!.notifier.value = data;
      _cache[key] = _CacheEntry<T>(data: data, isFetching: isFetching);
    } else {
      _cache[key] = _CacheEntry<T>(data: data, isFetching: isFetching);
    }
  }

  static T? retrieveData<T>(String key) {
    return _cache[key]?.data as T?;
  }

  static bool isFetching(String key) {
    return _cache[key]?.isFetching ?? false;
  }

  static ValueNotifier<T?> getNotifier<T>(String key) {
    if (!_cache.containsKey(key)) {
      _cache[key] = _CacheEntry<T>(data: null);
    }
    return _cache[key]!.notifier as ValueNotifier<T?>;
  }

  static void clear(String key) {
    _cache.remove(key);
  }

  static void clearAll() {
    _cache.clear();
  }

  static Future<T> fetchAction<T>(
      String key,
      ApiRequestAction<T> action, {
        Map<String, dynamic> requestData = const {},
        bool enableCache = true,
        bool enableBackgroundFetch = true,
      }) async {
    if (enableCache && _cache.containsKey(key)) {
      final cachedData = retrieveData<T>(key);
      if (cachedData != null) {
        if (enableBackgroundFetch && !isFetching(key)) {
          _fetchActionInBackground(key, action, enableCache, requestData);
        }
        return cachedData;
      }
    }

    Completer<T> completer = Completer<T>();
    await action
        .listen(
      onStart: () {},
      onDone: () {},
      onSuccess: (response) {
        if (enableCache) {
          store(key, response);
        }
        completer.complete(response);
      },
      onError: (e) => completer.completeError(e),
    )
        .whereMap(requestData)
        .execute();

    final data = await completer.future;
    if (enableBackgroundFetch && !isFetching(key)) {
      _fetchActionInBackground(key, action, enableCache, requestData);
    }
    return data;
  }

  static Future<void> _fetchActionInBackground<T>(
      String key,
      ApiRequestAction<T> action,
      bool enableCache,
      Map<String, dynamic> requestData,
      ) async {
    store(key, retrieveData<T>(key), isFetching: true);
    await action
        .listen(
      onStart: () {},
      onDone: () {},
      onSuccess: (response) {
        if (enableCache) {
          store(key, response);
        }
      },
      onError: (e) {},
    )
        .whereMap(requestData)
        .execute();
  }

  static Future<T> fetchFuture<T>(
      String key,
      Future<T> Function() future, {
        bool enableCache = true,
        bool enableBackgroundFetch = true,
      }) async {
    if (enableCache && _cache.containsKey(key)) {
      final cachedData = retrieveData<T>(key);
      if (cachedData != null) {
        if (enableBackgroundFetch && !isFetching(key)) {
          _fetchFutureInBackground(key, future, enableCache);
        }
        return cachedData;
      }
    }

    try {
      final data = await future();
      if (enableCache) {
        store(key, data);
      }
      if (enableBackgroundFetch && !isFetching(key)) {
        _fetchFutureInBackground(key, future, enableCache);
      }
      return data;
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> _fetchFutureInBackground<T>(
      String key,
      Future<T> Function() future,
      bool enableCache,
      ) async {
    store(key, retrieveData<T>(key), isFetching: true);
    try {
      final newData = await future();
      if (enableCache) {
        store(key, newData);
      }
    } catch (e) {
      // Ignore errors in background
    }
  }
}