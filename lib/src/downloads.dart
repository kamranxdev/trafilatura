/// All functions needed to steer and execute downloads of web documents.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'settings.dart';

/// Default user agent string
const String userAgent = 'trafilatura/2.0.0 (+https://github.com/adbar/trafilatura)';

/// Default headers for HTTP requests
final Map<String, String> defaultHeaders = {
  'User-Agent': userAgent,
  'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  'Accept-Encoding': 'gzip, deflate',
  'Accept-Language': 'en-US,en;q=0.5',
};

/// HTTP status codes that should trigger retry
const List<int> forceStatus = [
  429, 499, 500, 502, 503, 504, 509, 520, 521, 522, 523, 524, 525, 526, 527, 530, 598,
];

/// Store information gathered in a HTTP response object.
class Response {
  /// Raw response data as bytes
  Uint8List? data;
  
  /// Response headers
  Map<String, String>? headers;
  
  /// Decoded HTML content
  String? html;
  
  /// HTTP status code
  final int status;
  
  /// Final URL after redirects
  final String url;
  
  /// Create a new Response object.
  Response(this.data, this.status, this.url);
  
  /// Check if response has data.
  bool get hasData => data != null && data!.isNotEmpty;
  
  @override
  String toString() => html ?? (data != null ? decodeFile(data!) : '');
  
  /// Store response headers.
  void storeHeaders(Map<String, String> headerdict) {
    headers = {
      for (final entry in headerdict.entries)
        entry.key.toLowerCase(): entry.value,
    };
  }
  
  /// Decode the bytestring in data and store a string in html.
  void decodeData(bool decode) {
    if (decode && data != null && data!.isNotEmpty) {
      html = decodeFile(data!);
    }
  }
  
  /// Convert the response object to a dictionary.
  Map<String, dynamic> asDict() {
    return {
      'data': data,
      'headers': headers,
      'html': html,
      'status': status,
      'url': url,
    };
  }
}

/// Parse configuration for HTTP headers.
(List<String>?, String?) _parseConfig(Map<String, dynamic> config) {
  final myagents = config['USER_AGENTS'] as String? ?? '';
  final agentList = myagents.trim().isNotEmpty
      ? myagents.trim().split('\n')
      : null;
  final mycookie = config['COOKIE'] as String?;
  return (agentList, mycookie);
}

/// Determine headers based on configuration.
Map<String, String> _determineHeaders(Map<String, dynamic>? config) {
  if (config != null) {
    final (myagents, mycookie) = _parseConfig(config);
    final headers = <String, String>{};
    if (myagents != null && myagents.isNotEmpty) {
      final randomIndex = DateTime.now().millisecondsSinceEpoch % myagents.length;
      headers['User-Agent'] = myagents[randomIndex];
    }
    if (mycookie != null && mycookie.isNotEmpty) {
      headers['Cookie'] = mycookie;
    }
    if (headers.isNotEmpty) {
      return {...defaultHeaders, ...headers};
    }
  }
  return defaultHeaders;
}

/// Internal function to robustly send a request and return its result.
Future<Response?> _sendRequest(
  String url, {
  bool noSsl = false,
  bool withHeaders = false,
  Map<String, dynamic>? config,
}) async {
  try {
    final uri = Uri.parse(url);
    final client = http.Client();
    
    try {
      final request = http.Request('GET', uri);
      request.headers.addAll(_determineHeaders(config));
      
      final response = await client.send(request).timeout(
        Duration(seconds: config?['DOWNLOAD_TIMEOUT'] as int? ?? 30),
      );
      
      // Check max file size
      final maxFileSize = config?['MAX_FILE_SIZE'] as int? ?? 20000000;
      final contentLength = response.contentLength ?? 0;
      if (contentLength > maxFileSize) {
        throw Exception('MAX_FILE_SIZE exceeded');
      }
      
      // Read response body
      final bytes = await response.stream.toBytes();
      
      // Check size again after reading
      if (bytes.length > maxFileSize) {
        throw Exception('MAX_FILE_SIZE exceeded');
      }
      
      final resp = Response(
        bytes,
        response.statusCode,
        response.request?.url.toString() ?? url,
      );
      
      if (withHeaders) {
        resp.storeHeaders(response.headers);
      }
      
      return resp;
    } finally {
      client.close();
    }
  } catch (e) {
    if (e.toString().contains('SSL') || e.toString().contains('TLS')) {
      // Retry without SSL verification (not possible in Dart http package directly)
      // This would require a custom HttpClient
    }
    return null;
  }
}

/// Check if the response conforms to formal criteria.
bool _isSuitableResponse(String url, Response response, Extractor options) {
  final lentest = (response.html ?? response.data?.toString() ?? '').length;
  
  if (response.status != 200) {
    return false;
  }
  
  if (!isAcceptableLength(lentest, options)) {
    return false;
  }
  
  return true;
}

/// Downloads a web page and seamlessly decodes the response.
/// 
/// Args:
///   url: URL of the page to fetch.
///   noSsl: Do not try to establish a secure connection.
///   config: Pass configuration values for output control.
///   options: Extraction options (supersedes config).
/// 
/// Returns:
///   Unicode string or null in case of failed downloads and invalid results.
Future<String?> fetchUrl(
  String url, {
  bool noSsl = false,
  Map<String, dynamic>? config,
  Extractor? options,
}) async {
  config = options?.config ?? config;
  final response = await fetchResponse(
    url,
    decode: true,
    noSsl: noSsl,
    config: config,
  );
  
  if (response != null && response.hasData) {
    options ??= Extractor(config: config);
    if (_isSuitableResponse(url, response, options)) {
      return response.html;
    }
  }
  
  return null;
}

/// Downloads a web page and returns a full response object.
/// 
/// Args:
///   url: URL of the page to fetch.
///   decode: Use html attribute to decode the data.
///   noSsl: Don't try to establish a secure connection.
///   withHeaders: Keep track of the response headers.
///   config: Pass configuration values for output control.
/// 
/// Returns:
///   Response object or null in case of failed downloads and invalid results.
Future<Response?> fetchResponse(
  String url, {
  bool decode = false,
  bool noSsl = false,
  bool withHeaders = false,
  Map<String, dynamic>? config,
}) async {
  final response = await _sendRequest(
    url,
    noSsl: noSsl,
    withHeaders: withHeaders,
    config: config,
  );
  
  if (response == null) {
    return null;
  }
  
  response.decodeData(decode);
  return response;
}

/// Send a HTTP HEAD request to check if a page exists.
Future<bool> isLivePage(String url) async {
  try {
    final uri = Uri.parse(url);
    final client = http.Client();
    
    try {
      final response = await client.head(uri).timeout(
        const Duration(seconds: 10),
      );
      return response.statusCode < 400;
    } finally {
      client.close();
    }
  } catch (e) {
    return false;
  }
}

/// URL store for download management.
class UrlStore {
  /// Stored URLs by domain
  final Map<String, List<String>> _urls = {};
  
  /// Downloaded URLs
  final Set<String> _downloaded = {};
  
  /// Whether all URLs have been processed
  bool done = false;
  
  /// Whether to use compression
  final bool compressed;
  
  /// Whether to use strict mode
  final bool strict;
  
  /// Verbose mode
  final bool verbose;
  
  /// Create a new URL store.
  UrlStore({
    this.compressed = false,
    this.strict = false,
    this.verbose = false,
  });
  
  /// Add URLs to the store.
  void addUrls(List<String> urls) {
    for (final url in urls) {
      try {
        final uri = Uri.parse(url);
        final domain = uri.host;
        _urls.putIfAbsent(domain, () => []).add(url);
      } catch (e) {
        // Invalid URL, skip
      }
    }
  }
  
  /// Get URLs for downloading.
  List<String> getDownloadUrls({double timeLimit = 5.0, int maxUrls = 100000}) {
    final result = <String>[];
    
    for (final entry in _urls.entries) {
      for (final url in entry.value) {
        if (!_downloaded.contains(url)) {
          result.add(url);
          _downloaded.add(url);
          if (result.length >= maxUrls) {
            break;
          }
        }
      }
      if (result.length >= maxUrls) {
        break;
      }
    }
    
    if (result.isEmpty) {
      done = true;
    }
    
    return result;
  }
}

/// Filter, convert input URLs and add them to domain-aware processing dictionary.
UrlStore addToCompressedDict(
  List<String> inputlist, {
  Set<String>? blacklist,
  String? urlFilter,
  UrlStore? urlStore,
  bool compression = false,
  bool verbose = false,
}) {
  urlStore ??= UrlStore(compressed: compression, strict: false, verbose: verbose);
  
  // Remove duplicates
  inputlist = inputlist.toSet().toList();
  
  // Apply blacklist
  if (blacklist != null && blacklist.isNotEmpty) {
    inputlist = inputlist.where((u) {
      final cleaned = u.replaceAll(urlBlacklistRegex, '');
      return !blacklist.contains(cleaned);
    }).toList();
  }
  
  // Apply URL filter
  if (urlFilter != null && urlFilter.isNotEmpty) {
    inputlist = inputlist.where((u) => u.contains(urlFilter)).toList();
  }
  
  urlStore.addUrls(inputlist);
  return urlStore;
}

/// Determine threading strategy and draw URLs respecting domain-based back-off rules.
Future<(List<String>, UrlStore)> loadDownloadBuffer(
  UrlStore urlStore, {
  double sleepTime = 5.0,
}) async {
  while (true) {
    final bufferlist = urlStore.getDownloadUrls(timeLimit: sleepTime, maxUrls: 100000);
    if (bufferlist.isNotEmpty || urlStore.done) {
      return (bufferlist, urlStore);
    }
    await Future.delayed(Duration(milliseconds: (sleepTime * 1000).toInt()));
  }
}

/// Download queue consumer, returns URL and result pairs.
Stream<(String, String?)> bufferedDownloads(
  List<String> bufferlist, {
  int downloadThreads = 5,
  Extractor? options,
}) async* {
  // Process URLs in parallel using isolates or futures
  final futures = <Future<(String, String?)>>[];
  
  for (final chunk in _makeChunks(bufferlist, 10)) {
    final chunkFutures = chunk.map((url) async {
      final result = await fetchUrl(url, options: options);
      return (url, result);
    });
    futures.addAll(chunkFutures);
  }
  
  for (final future in futures) {
    yield await future;
  }
}

/// Download queue consumer, returns full Response objects.
Stream<(String, Response?)> bufferedResponseDownloads(
  List<String> bufferlist, {
  int downloadThreads = 5,
  Extractor? options,
}) async* {
  final config = options?.config;
  
  for (final chunk in _makeChunks(bufferlist, 10)) {
    final futures = chunk.map((url) async {
      final result = await fetchResponse(url, config: config);
      return (url, result);
    });
    
    for (final future in futures) {
      yield await future;
    }
  }
}

/// Split a list into chunks.
Iterable<List<T>> _makeChunks<T>(List<T> list, int chunkSize) sync* {
  for (var i = 0; i < list.length; i += chunkSize) {
    yield list.sublist(i, i + chunkSize > list.length ? list.length : i + chunkSize);
  }
}

/// URL blacklist regex
final urlBlacklistRegex = RegExp(r'[?#].*$');

/// Check if length is acceptable based on options.
bool isAcceptableLength(int length, Extractor options) {
  if (length < options.minFileSize) {
    return false;
  }
  if (length > options.maxFileSize) {
    return false;
  }
  return true;
}

/// Decode bytes to string.
String decodeFile(Uint8List data) {
  // Try UTF-8 first
  try {
    return utf8.decode(data);
  } catch (e) {
    // Fall back to Latin-1
    try {
      return latin1.decode(data);
    } catch (e) {
      // Last resort: replace invalid characters
      return utf8.decode(data, allowMalformed: true);
    }
  }
}

/// Uint8List typedef for convenience
typedef Uint8List = List<int>;
