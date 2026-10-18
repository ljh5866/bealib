import 'dart:io';

import 'package:dio/dio.dart';
import 'package:bealib/request/core/dio_factory.dart';
import 'package:bealib/request/core/network_error_mapper.dart';
import 'package:bealib/request/core/network_exception.dart';

class DownloadHttpClient {
  DownloadHttpClient._();

  static final DownloadHttpClient instance = DownloadHttpClient._();

  Future<Response<ResponseBody>> getStream(
    String url, {
    Map<String, dynamic> headers = const {},
    Duration? receiveTimeout,
    CancelToken? cancelToken,
  }) async {
    try {
      return await DioFactory.downloadDio.get<ResponseBody>(
        url,
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
          receiveTimeout: receiveTimeout,
        ),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw await NetworkErrorMapper.mapException(e);
    }
  }

  Future<String> getPlain(
    String url, {
    Map<String, dynamic> headers = const {},
    Duration? receiveTimeout,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await DioFactory.downloadDio.get<String>(
        url,
        options: Options(
          headers: headers,
          responseType: ResponseType.plain,
          receiveTimeout: receiveTimeout,
        ),
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      return response.data ?? '';
    } on DioException catch (e) {
      throw await NetworkErrorMapper.mapException(e);
    }
  }

  /// 手动流式下载：比 Dio.download 更可控（长超时 + 明确分块写入），
  /// 避免部分 Android 网络下 download() 提前断流。
  Future<void> download(
    String url,
    String savePath, {
    Map<String, dynamic> headers = const {},
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    File? target;
    IOSink? sink;
    try {
      final response = await DioFactory.downloadDio.get<ResponseBody>(
        url,
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(seconds: 180),
        ),
        cancelToken: cancelToken,
      );
      final body = response.data;
      if (body == null) {
        throw const NetworkException(
          type: NetworkExceptionType.parseError,
          message: '空的下载响应',
        );
      }
      target = File(savePath);
      sink = target.openWrite();
      final int total = int.tryParse(
            response.headers.value(Headers.contentLengthHeader) ?? '',
          ) ??
          -1;
      int received = 0;
      await for (final chunk in body.stream) {
        if (cancelToken?.isCancelled ?? false) {
          throw cancelToken!.cancelError!;
        }
        sink.add(chunk);
        received += chunk.length;
        onReceiveProgress?.call(received, total);
      }
      await sink.flush();
      await sink.close();
      sink = null;
    } on DioException catch (e) {
      throw await NetworkErrorMapper.mapException(e);
    } finally {
      try {
        await sink?.close();
      } catch (_) {}
    }
  }
}
