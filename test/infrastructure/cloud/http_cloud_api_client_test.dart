import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:asset_ledger/features/app_update/domain/version_gate_decision.dart';
import 'package:asset_ledger/features/app_update/domain/version_policy.dart';
import 'package:asset_ledger/infrastructure/cloud/api_client.dart';
import 'package:asset_ledger/infrastructure/cloud/http_cloud_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requires https for non-local endpoints', () {
    expect(
      () => HttpCloudApiClient(
        baseUrl: 'http://backup.example.com',
        accessTokenProvider: () async => null,
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('allows localhost http for development and widget tests', () {
    final client = HttpCloudApiClient(
      baseUrl: 'http://127.0.0.1:8080',
      accessTokenProvider: () async => null,
    );

    expect(client, isA<HttpCloudApiClient>());
  });

  test(
    'sends app version and platform headers and caches app version',
    () async {
      final httpClient = _FakeHttpClient()
        ..enqueueResponse(statusCode: 200, body: '{"ok":true}')
        ..enqueueResponse(statusCode: 200, body: '{"ok":true}');
      var versionReads = 0;
      final client = _client(
        httpClient,
        appVersionProvider: () async {
          versionReads++;
          return ' 1.4.0 ';
        },
        platform: 'android',
      );

      await client.send(
        const ApiRequest(
          method: 'POST',
          path: '/v1/items',
          headers: {'X-Custom': 'custom-value'},
          bodyJson: '{"hello":true}',
        ),
      );
      await client.send(const ApiRequest(method: 'GET', path: '/v1/items'));

      expect(versionReads, 1);
      expect(httpClient.requests, hasLength(2));
      expect(
        httpClient.requests.first.headers.value('authorization'),
        'Bearer token-1',
      );
      expect(httpClient.requests.first.headers.value('X-App-Version'), '1.4.0');
      expect(httpClient.requests.first.headers.value('X-Platform'), 'android');
      expect(
        httpClient.requests.first.headers.value('X-Custom'),
        'custom-value',
      );
      expect(
        utf8.decode(httpClient.requests.first.bodyBytes),
        '{"hello":true}',
      );
      expect(httpClient.requests.last.headers.value('X-App-Version'), '1.4.0');
    },
  );

  test(
    'skips app version header when provider fails or returns empty',
    () async {
      final throwingHttpClient = _FakeHttpClient()
        ..enqueueResponse(statusCode: 200);
      final throwingClient = _client(
        throwingHttpClient,
        appVersionProvider: () async {
          throw StateError('package info unavailable');
        },
        platform: 'ios',
      );

      await throwingClient.send(const ApiRequest(method: 'GET', path: '/v1/a'));

      expect(
        throwingHttpClient.requests.single.headers.value('X-App-Version'),
        isNull,
      );
      expect(
        throwingHttpClient.requests.single.headers.value('X-Platform'),
        'ios',
      );

      final emptyHttpClient = _FakeHttpClient()
        ..enqueueResponse(statusCode: 200);
      final emptyClient = _client(
        emptyHttpClient,
        appVersionProvider: () async => ' ',
        platform: null,
      );

      await emptyClient.send(const ApiRequest(method: 'GET', path: '/v1/b'));

      expect(
        emptyHttpClient.requests.single.headers.value('X-App-Version'),
        isNull,
      );
      expect(
        emptyHttpClient.requests.single.headers.value('X-Platform'),
        isNull,
      );
    },
  );

  test('keeps 200 and non-426 error response mapping unchanged', () async {
    final httpClient = _FakeHttpClient()
      ..enqueueResponse(statusCode: 200, body: '{"data":true}')
      ..enqueueResponse(statusCode: 404, body: '{"error":"missing"}')
      ..enqueueResponse(statusCode: 503, body: '{"error":"busy"}');
    final client = _client(httpClient);

    final ok = await client.send(const ApiRequest(method: 'GET', path: '/ok'));
    final notFound = await client.send(
      const ApiRequest(method: 'GET', path: '/missing'),
    );
    final unavailable = await client.send(
      const ApiRequest(method: 'GET', path: '/busy'),
    );

    expect(ok.isSuccess, isTrue);
    expect(ok.bodyJson, '{"data":true}');
    expect(notFound.error?.code, 'http_404');
    expect(notFound.error?.retryable, isFalse);
    expect(notFound.bodyJson, '{"error":"missing"}');
    expect(unavailable.error?.code, 'http_503');
    expect(unavailable.error?.retryable, isTrue);
    expect(unavailable.bodyJson, '{"error":"busy"}');
  });

  test('maps 426 to upgrade_required and signals forced decision', () async {
    final httpClient = _FakeHttpClient()
      ..enqueueResponse(
        statusCode: HttpStatus.upgradeRequired,
        body: jsonEncode({
          'updateUrl': 'https://example.com/download',
          'title': '必须更新',
          'content': '请更新后继续使用。',
        }),
      );
    final decisions = <VersionGateDecision>[];
    final client = _client(httpClient, onUpgradeRequired: decisions.add);

    final response = await client.send(
      const ApiRequest(method: 'GET', path: '/sync/changes'),
    );

    expect(response.statusCode, HttpStatus.upgradeRequired);
    expect(response.bodyJson, isNull);
    expect(response.error?.code, 'upgrade_required');
    expect(response.error?.message, '请更新后继续使用。');
    expect(response.error?.retryable, isFalse);
    expect(decisions, hasLength(1));
    expect(decisions.single.level, VersionGateLevel.forced);
    expect(decisions.single.updateUrl, 'https://example.com/download');
    expect(decisions.single.title, '必须更新');
    expect(decisions.single.content, '请更新后继续使用。');
  });

  test('uses fallback copy for malformed 426 body', () async {
    final httpClient = _FakeHttpClient()
      ..enqueueResponse(
        statusCode: HttpStatus.upgradeRequired,
        body: 'not json',
      );
    final decisions = <VersionGateDecision>[];
    final client = _client(httpClient, onUpgradeRequired: decisions.add);

    final response = await client.send(
      const ApiRequest(method: 'GET', path: '/sync/changes'),
    );

    expect(response.error?.code, 'upgrade_required');
    expect(decisions.single.updateUrl, '');
    expect(decisions.single.title, VersionPolicy.fallbackTitle);
    expect(decisions.single.content, VersionPolicy.fallbackContent);
  });
}

HttpCloudApiClient _client(
  _FakeHttpClient httpClient, {
  Future<String?> Function()? appVersionProvider,
  String? platform = 'android',
  void Function(VersionGateDecision decision)? onUpgradeRequired,
}) {
  return HttpCloudApiClient(
    baseUrl: 'http://127.0.0.1:8080',
    accessTokenProvider: () async => 'token-1',
    httpClient: httpClient,
    appVersionProvider: appVersionProvider,
    platform: platform,
    onUpgradeRequired: onUpgradeRequired,
  );
}

class _FakeHttpClient extends Fake implements HttpClient {
  final requests = <_FakeHttpClientRequest>[];
  final _responses = Queue<_FakeHttpClientResponse>();

  void enqueueResponse({required int statusCode, String body = ''}) {
    _responses.add(_FakeHttpClientResponse(statusCode: statusCode, body: body));
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (_responses.isEmpty) {
      throw StateError('No fake response queued for $method $url');
    }
    final request = _FakeHttpClientRequest(
      method: method,
      url: url,
      response: _responses.removeFirst(),
    );
    requests.add(request);
    return request;
  }
}

class _FakeHttpClientRequest extends Fake implements HttpClientRequest {
  _FakeHttpClientRequest({
    required this.method,
    required this.url,
    required _FakeHttpClientResponse response,
  }) : _response = response;

  @override
  final String method;
  final Uri url;
  final _FakeHttpClientResponse _response;
  final bodyBytes = <int>[];

  @override
  final _FakeHttpHeaders headers = _FakeHttpHeaders();

  @override
  void add(List<int> data) {
    bodyBytes.addAll(data);
  }

  @override
  Future<HttpClientResponse> close() async => _response;
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse({required this.statusCode, required String body})
    : _body = utf8.encode(body);

  @override
  final int statusCode;
  final List<int> _body;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final chunks = _body.isEmpty ? const <List<int>>[] : <List<int>>[_body];
    return Stream<List<int>>.fromIterable(chunks).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders extends Fake implements HttpHeaders {
  final _values = <String, String>{};
  ContentType? _contentType;

  @override
  String? value(String name) => _values[name.toLowerCase()];

  @override
  ContentType? get contentType => _contentType;

  @override
  set contentType(ContentType? value) {
    _contentType = value;
    if (value != null) {
      set(HttpHeaders.contentTypeHeader, value.mimeType);
    }
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name.toLowerCase()] = value.toString();
  }
}
