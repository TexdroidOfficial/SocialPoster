import 'package:dio/dio.dart';

class SafeHttpClient {
  SafeHttpClient({Dio? dio}) : dio = dio ?? Dio() {
    this.dio.interceptors.add(_RedactingInterceptor());
  }

  final Dio dio;
}

class _RedactingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final safe = err.requestOptions.copyWith(
      headers: {
        for (final entry in err.requestOptions.headers.entries)
          entry.key.toLowerCase() == 'authorization'
              ? entry.key
              : entry.key: entry.key.toLowerCase() == 'authorization'
              ? '[REDACTED]'
              : entry.value,
      },
      queryParameters: {
        for (final entry in err.requestOptions.queryParameters.entries)
          entry.key.toLowerCase().contains('token') ||
                      entry.key.toLowerCase().contains('secret')
                  ? entry.key
                  : entry.key:
              entry.key.toLowerCase().contains('token') ||
                  entry.key.toLowerCase().contains('secret')
              ? '[REDACTED]'
              : entry.value,
      },
    );
    handler.next(err.copyWith(requestOptions: safe));
  }
}
