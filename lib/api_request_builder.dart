import 'dart:async';

import 'package:api_request/api_request.dart';
import 'package:flutter/material.dart';

import 'api_request_cache_manager.dart';

// كلاس جديد لتخزين الـ configuration العامة
class _ApiRequestConfig {
  static bool defaultEnableCache = false;
  static bool defaultEnableBackgroundFetch = false;
  static Widget Function(BuildContext)? defaultLoadingBuilder;
  static Widget Function(BuildContext, Object)? defaultErrorBuilder;
  static Widget Function(BuildContext)? defaultEmptyBuilder;
}

class ApiRequestBuilder<T> extends StatefulWidget {
  final Future<T> Function()? future;
  final ApiRequestAction<T>? action;
  final Widget Function(BuildContext, T) builder;
  final Widget Function(BuildContext)? loadingBuilder;
  final Widget Function(BuildContext, Object)? errorBuilder;
  final Widget Function(BuildContext)? emptyBuilder;
  final bool? enableCache; // nullable عشان يستخدم الـ default لو null
  final bool? enableBackgroundFetch; // nullable عشان يستخدم الـ default لو null
  final String? cacheKey;
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
    this.enableCache,
    this.enableBackgroundFetch,
    this.requestData = const {},
  }) : assert(future != null || action != null,
            'Must provide either future or action');

  /// Configures default settings for all ApiRequestBuilder instances.
  /// Call this method early in your app (e.g., in main.dart before runApp).
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
  _ApiRequestBuilderState<T> createState() => _ApiRequestBuilderState<T>();
}

class _ApiRequestBuilderState<T> extends State<ApiRequestBuilder<T>> {
  late Future<T> _future;
  late String _cacheKey;

  @override
  void initState() {
    super.initState();
    _cacheKey = _getEffectiveCacheKey();
    _future = _getFuture();
  }

  @override
  void didUpdateWidget(ApiRequestBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool actionChanged = oldWidget.action != widget.action &&
        (oldWidget.action?.method != widget.action?.method ||
            oldWidget.action?.path != widget.action?.path);
    bool futureChanged = oldWidget.future != widget.future;
    bool requestDataChanged = oldWidget.requestData != widget.requestData;
    bool cacheKeyChanged = oldWidget.cacheKey != widget.cacheKey;

    if (actionChanged ||
        futureChanged ||
        requestDataChanged ||
        cacheKeyChanged) {
      _cacheKey = _getEffectiveCacheKey();
      _future = _getFuture();
    }
  }

  String _getEffectiveCacheKey() {
    if (widget.cacheKey != null) return widget.cacheKey!;
    if (widget.future != null) {
      return 'future_${widget.future.hashCode}';
    } else {
      return '${widget.action!.method}_${widget.action!.path}';
    }
  }

  Future<T> _getFuture() {
    final effectiveEnableCache =
        widget.enableCache ?? _ApiRequestConfig.defaultEnableCache;
    final effectiveEnableBackgroundFetch = widget.enableBackgroundFetch ??
        _ApiRequestConfig.defaultEnableBackgroundFetch;

    if (widget.action != null) {
      return ApiRequestCacheManager.fetchAction<T>(
        _cacheKey,
        widget.action!,
        enableCache: effectiveEnableCache,
        requestData: widget.requestData,
        enableBackgroundFetch: effectiveEnableBackgroundFetch,
      );
    } else {
      return ApiRequestCacheManager.fetchFuture<T>(
        _cacheKey,
        widget.future!,
        enableCache: effectiveEnableCache,
        enableBackgroundFetch: effectiveEnableBackgroundFetch,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveEnableCache =
        widget.enableCache ?? _ApiRequestConfig.defaultEnableCache;
    final effectiveLoadingBuilder =
        widget.loadingBuilder ?? _ApiRequestConfig.defaultLoadingBuilder;
    final effectiveErrorBuilder =
        widget.errorBuilder ?? _ApiRequestConfig.defaultErrorBuilder;
    final effectiveEmptyBuilder =
        widget.emptyBuilder ?? _ApiRequestConfig.defaultEmptyBuilder;

    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return effectiveLoadingBuilder?.call(context) ??
              const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return effectiveErrorBuilder?.call(context, snapshot.error!) ??
              Center(child: Text('Error: ${snapshot.error}'));
        } else if (snapshot.hasData) {
          if (!effectiveEnableCache) {
            final T data = snapshot.data!;
            if (_isEmpty(data) && effectiveEmptyBuilder != null) {
              return effectiveEmptyBuilder(context);
            }
            return widget.builder(context, data);
          }
          return ValueListenableBuilder<T?>(
            valueListenable: ApiRequestCacheManager.getNotifier<T>(_cacheKey),
            builder: (context, data, child) {
              if (data == null) {
                final snapshotData = snapshot.data!;
                if (_isEmpty(snapshotData) && effectiveEmptyBuilder != null) {
                  return effectiveEmptyBuilder(context);
                }
                return widget.builder(context, snapshotData);
              }
              if (_isEmpty(data) && effectiveEmptyBuilder != null) {
                return effectiveEmptyBuilder(context);
              }
              return Stack(
                children: [
                  widget.builder(context, data),
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
        return const SizedBox.shrink();
      },
    );
  }

  bool _isEmpty(T data) {
    if (data == null) return true;
    if (data is List && (data as List).isEmpty) return true;
    if (data is String && (data as String).isEmpty) return true;
    return false;
  }

  // static void refresh<T>({
  //   String? cacheKey,
  //   Future<T> Function()? future,
  //   ApiRequestAction<T>? action,
  //   Map<String, dynamic> requestData = const {},
  // }) {
  //   assert(future != null || action != null,
  //       'Must provide either future or action');
  //   final key = cacheKey ??
  //       (future != null
  //           ? 'future_${future.hashCode}'
  //           : 'action_${action.runtimeType.toString()}_${action!.path}');
  //   ApiRequestCacheManager.clear(key);
  //   if (action != null) {
  //     ApiRequestCacheManager.fetchAction<T>(key, action,
  //         requestData: requestData);
  //   } else {
  //     ApiRequestCacheManager.fetchFuture<T>(key, future!);
  //   }
  // }
}
