import 'dart:async';

import 'package:api_request/api_request.dart';
import 'package:flutter/material.dart';

import 'api_request_cache_manager.dart';

// Configuration class for default settings of ApiRequestBuilder
class _ApiRequestConfig {
  static bool defaultEnableCache = false;
  static bool defaultEnableBackgroundFetch = false;
  static Widget Function(BuildContext)? defaultLoadingBuilder;
  static Widget Function(BuildContext, Object)? defaultErrorBuilder;
  static Widget Function(BuildContext)? defaultEmptyBuilder;
}

// Typedef for the refresh function signature with mergeData option
typedef RefreshFuture<T> = Future<T> Function({
  void Function()? onStart,
  void Function()? onDone,
  Map<String, dynamic>? data,
  bool? mergeData,
});

/// A widget that simplifies API requests with caching, background fetching, and UI rendering.
class ApiRequestBuilder<T> extends StatefulWidget {
  /// Optional Future to fetch data directly.
  final Future<T> Function()? future;

  /// Optional action to fetch data using the api_request package.
  final ApiRequestAction<T>? action;

  /// Builder to render the UI with data and a refresh function.
  final Widget Function(BuildContext, RefreshFuture<T>, T) builder;

  /// Optional builder for the loading state.
  final Widget Function(BuildContext)? loadingBuilder;

  /// Optional builder for the error state, with access to the refresh function.
  final Widget Function(BuildContext, RefreshFuture<T>, Object)? errorBuilder;

  /// Optional builder for the empty state, with access to the refresh function.
  final Widget Function(BuildContext, RefreshFuture<T>)? emptyBuilder;

  /// Optional checker to determine if the data is considered empty.
  final bool Function(T)? isEmptyChecker;

  /// Whether to enable caching; falls back to default if null.
  final bool? enableCache;

  /// Whether to enable background fetching; falls back to default if null.
  final bool? enableBackgroundFetch;

  /// Custom cache key; auto-generated if null.
  final String? cacheKey;

  /// Initial request data to include in the request.
  final Map<String, dynamic> requestData;

  const ApiRequestBuilder({
    super.key,
    this.future,
    this.action,
    required this.builder,
    this.cacheKey,
    this.loadingBuilder,
    this.errorBuilder,
    this.emptyBuilder,
    this.isEmptyChecker, // New optional parameter
    this.enableCache,
    this.enableBackgroundFetch,
    this.requestData = const {},
  }) : assert(future != null || action != null,
            'Must provide either future or action');

  /// Configures default settings for all ApiRequestBuilder instances.
  /// Should be called early in the app lifecycle (e.g., in main.dart before runApp).
  static void config({
    bool? enableCache,
    bool? enableBackgroundFetch,
    Widget Function(BuildContext)? loadingBuilder,
    Widget Function(BuildContext, Object)? errorBuilder,
    Widget Function(BuildContext)? emptyBuilder,
  }) {
    if (enableCache != null) _ApiRequestConfig.defaultEnableCache = enableCache;
    if (enableBackgroundFetch != null) {
      _ApiRequestConfig.defaultEnableBackgroundFetch = enableBackgroundFetch;
    }
    if (loadingBuilder != null) {
      _ApiRequestConfig.defaultLoadingBuilder = loadingBuilder;
    }
    if (errorBuilder != null) {
      _ApiRequestConfig.defaultErrorBuilder = errorBuilder;
    }
    if (emptyBuilder != null) {
      _ApiRequestConfig.defaultEmptyBuilder = emptyBuilder;
    }
  }

  @override
  State<ApiRequestBuilder<T>> createState() => _ApiRequestBuilderState<T>();
}

class _ApiRequestBuilderState<T> extends State<ApiRequestBuilder<T>> {
  late Future<T> _future; // Holds the current Future for data fetching
  late String _cacheKey; // Unique key for caching the request

  @override
  void initState() {
    super.initState();
    _cacheKey = _getEffectiveCacheKey();
    _future = _getFuture(widget.requestData);
  }

  @override
  void didUpdateWidget(ApiRequestBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool shouldUpdate = _shouldUpdate(oldWidget);
    if (shouldUpdate) {
      _cacheKey = _getEffectiveCacheKey();
      _future = _getFuture(
          widget.requestData); // Re-fetch if widget properties change
    }
  }

  /// Determines if the widget needs to update based on changes in key properties.
  bool _shouldUpdate(ApiRequestBuilder<T> oldWidget) {
    final bool actionChanged = oldWidget.action != widget.action &&
        (oldWidget.action?.method != widget.action?.method ||
            oldWidget.action?.path != widget.action?.path);
    final bool futureChanged = oldWidget.future != widget.future;
    final bool requestDataChanged = oldWidget.requestData != widget.requestData;
    final bool cacheKeyChanged = oldWidget.cacheKey != widget.cacheKey;
    return actionChanged ||
        futureChanged ||
        requestDataChanged ||
        cacheKeyChanged;
  }

  /// Generates a unique cache key based on provided or derived values.
  String _getEffectiveCacheKey() {
    if (widget.cacheKey != null) return widget.cacheKey!;
    if (widget.future != null) {
      return 'future_${widget.future.hashCode}';
    }
    // Safe to use ! here as the constructor asserts action or future is non-null
    return '${widget.action!.method}_${widget.action!.path}';
  }

  /// Fetches data with the provided request data.
  Future<T> _getFuture(Map<String, dynamic> requestData) {
    final bool effectiveEnableCache =
        widget.enableCache ?? _ApiRequestConfig.defaultEnableCache;
    final bool effectiveEnableBackgroundFetch = widget.enableBackgroundFetch ??
        _ApiRequestConfig.defaultEnableBackgroundFetch;

    if (widget.action != null) {
      print('_getFuture data: $requestData');
      return ApiRequestCacheManager.fetchAction<T>(
        _cacheKey,
        widget.action!,
        enableCache: effectiveEnableCache,
        requestData: requestData,
        enableBackgroundFetch: effectiveEnableBackgroundFetch,
      );
    }
    // Safe to use ! here as the constructor asserts action or future is non-null
    return ApiRequestCacheManager.fetchFuture<T>(
      _cacheKey,
      widget.future!,
      enableCache: effectiveEnableCache,
      enableBackgroundFetch: effectiveEnableBackgroundFetch,
    );
  }

  /// Refreshes the data with optional callbacks and request data, with control over merging.
  Future<T> _refresh({
    void Function()? onStart,
    void Function()? onDone,
    Map<String, dynamic>? data,
    bool?
        mergeData, // Controls whether to merge with widget.requestData, defaults to true
  }) async {
    onStart?.call(); // Execute onStart callback if provided
    final bool effectiveEnableCache =
        widget.enableCache ?? _ApiRequestConfig.defaultEnableCache;
    if (effectiveEnableCache) {
      ApiRequestCacheManager.clear(
          _cacheKey); // Clear cache to force a new request
    }

    // Determine the effective request data based on mergeData flag, defaulting to true
    final Map<String, dynamic> effectiveRequestData =
        (mergeData ?? true) && data != null
            ? {
                ...widget.requestData,
                ...data
              } // Merge if mergeData is true (default) and data is provided
            : data ?? widget.requestData;
    print('mergeData: $mergeData');
    print('widget.requestData: ${widget.requestData}');
    print('data: $data');
    print('effectiveRequestData: $effectiveRequestData');

    final Future<T> newFuture =
        _getFuture(effectiveRequestData); // Fetch with effective data
    final T result = await newFuture; // Wait for the request to complete
    if (mounted) {
      setState(() {
        _future =
            newFuture; // Update the Future only after the request succeeds
      });
    }
    onDone?.call(); // Execute onDone callback if provided
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final bool effectiveEnableCache =
        widget.enableCache ?? _ApiRequestConfig.defaultEnableCache;
    final Widget Function(BuildContext)? effectiveLoadingBuilder =
        widget.loadingBuilder ?? _ApiRequestConfig.defaultLoadingBuilder;
    final Widget Function(BuildContext, RefreshFuture<T>, Object)?
        effectiveErrorBuilder = widget.errorBuilder ??
            (_ApiRequestConfig.defaultErrorBuilder != null
                ? (context, refresh, error) =>
                    _ApiRequestConfig.defaultErrorBuilder!(context, error)
                : null);
    final Widget Function(BuildContext, RefreshFuture<T>)?
        effectiveEmptyBuilder = widget.emptyBuilder ??
            (_ApiRequestConfig.defaultEmptyBuilder != null
                ? (context, refresh) =>
                    _ApiRequestConfig.defaultEmptyBuilder!(context)
                : null);

    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return effectiveLoadingBuilder?.call(context) ??
              const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return effectiveErrorBuilder?.call(
                  context, _refresh, snapshot.error!) ??
              Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.hasData) {
          final T data =
              snapshot.data as T; // Cast data to T, safe due to hasData check
          if (!effectiveEnableCache) {
            // Use custom isEmptyChecker if provided, otherwise fallback to _isEmpty
            if ((widget.isEmptyChecker?.call(data) ?? _isEmpty(data)) &&
                effectiveEmptyBuilder != null) {
              return effectiveEmptyBuilder(context, _refresh);
            }
            return widget.builder(context, _refresh, data);
          }
          return ValueListenableBuilder<T?>(
            valueListenable: ApiRequestCacheManager.getNotifier<T>(_cacheKey),
            builder: (context, cachedData, child) {
              final T effectiveData =
                  cachedData ?? data; // Use cached data if available
              // Use custom isEmptyChecker if provided, otherwise fallback to _isEmpty
              if ((widget.isEmptyChecker?.call(effectiveData) ??
                      _isEmpty(effectiveData)) &&
                  effectiveEmptyBuilder != null) {
                return effectiveEmptyBuilder(context, _refresh);
              }
              return Stack(
                children: [
                  widget.builder(context, _refresh, effectiveData),
                  if (ApiRequestCacheManager.isFetching(_cacheKey))
                    const Positioned(
                      top: 10,
                      right: 10,
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              );
            },
          );
        }
        return const SizedBox.shrink(); // Fallback for unexpected states
      },
    );
  }

  /// Default check if the data is considered empty (null, empty list, or empty string).
  bool _isEmpty(T data) {
    if (data == null) return true;
    if (data is List && (data as List).isEmpty) return true;
    if (data is String && (data as String).isEmpty) return true;
    return false;
  }
}
