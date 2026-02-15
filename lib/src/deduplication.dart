/// Code parts dedicated to duplicate removal and text similarity.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:html/dom.dart' as dom;

import 'settings.dart';
import 'utils.dart';

/// Regex to strip filename extensions
final _stripExtension = RegExp(r'\.[^/?#]{2,63}$');

/// Translation table for punctuation to space
final _punctuationChars = RegExp(r'[\p{P}]', unicode: true);

/// Check similarity between two domain strings.
bool isSimilarDomain(String reference, String newString, {double threshold = 0.5}) {
  reference = reference.replaceAll(_stripExtension, '');
  newString = newString.replaceAll(_stripExtension, '');
  return _sequenceRatio(reference, newString) >= threshold;
}

/// Calculate sequence similarity ratio.
double _sequenceRatio(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 1.0;
  if (a.isEmpty || b.isEmpty) return 0.0;
  
  final matches = _countMatches(a, b);
  return (2.0 * matches) / (a.length + b.length);
}

/// Count matching characters between two strings.
int _countMatches(String a, String b) {
  final aChars = a.split('');
  final bChars = b.split('');
  final bSet = bChars.toSet();
  
  var matches = 0;
  for (final char in aChars) {
    if (bSet.contains(char)) {
      matches++;
    }
  }
  return matches;
}

/// Get a sample of tokens based on length criteria.
List<String> _getSampleByLength(List<String> tokens, int targetLength) {
  for (var i = 4; i >= 0; i--) {
    final sample = tokens.where((t) => t.length > i).toList();
    if (sample.length >= targetLength / 2) {
      return sample;
    }
  }
  return tokens.where((t) => t.isNotEmpty).toList();
}

/// Fallback token sampling for non-Latin languages.
List<String> sampleTokensFallback(String inputstring, {int length = 64}) {
  // Replace all punctuation with spaces
  final cleanText = inputstring.replaceAll(_punctuationChars, ' ');
  final tokens = cleanText.split(RegExp(r'\s+')).where((t) => _isAlphanumeric(t)).toList();
  return _getSampleByLength(tokens, length);
}

/// Check if string is alphanumeric.
bool _isAlphanumeric(String s) {
  if (s.isEmpty) return false;
  return s.codeUnits.every((c) =>
      (c >= 48 && c <= 57) ||  // 0-9
      (c >= 65 && c <= 90) ||  // A-Z
      (c >= 97 && c <= 122) || // a-z
      c > 127);  // extended characters
}

/// Split input into list of tokens and adjust length threshold.
List<String> sampleTokens(String inputstring, {int length = 64}) {
  final tokens = <String>[];
  
  for (var token in inputstring.split(RegExp(r'\s+'))) {
    // Strip punctuation from start and end
    token = token.replaceAll(RegExp(r'^[\p{P}]+|[\p{P}]+$', unicode: true), '');
    if (_isAlphanumeric(token)) {
      tokens.add(token);
    }
  }
  
  final sample = _getSampleByLength(tokens, length);
  
  if (sample.isEmpty) {
    return sampleTokensFallback(inputstring, length: length);
  }
  
  return sample;
}

/// Create a bag of words and generate a hash for a given string.
Uint8List generateBowHash(String inputstring, {int length = 24}) {
  final teststring = sampleTokens(inputstring).join(' ').trim();
  final bytes = utf8.encode(teststring);
  // Use SHA-256 and take first `length` bytes
  final digest = sha256.convert(bytes);
  return Uint8List.fromList(digest.bytes.take(length).toList());
}

/// Implement a basic Charikar hashing approach of string similarity.
class Simhash {
  /// Hash value
  late int hash;
  
  /// Hash length in bits
  final int length;
  
  /// Create a new Simhash from a string or existing hash.
  Simhash(String inputstring, {this.length = 64, String? existingHash}) {
    final validated = _validate(existingHash);
    hash = validated ?? _createHash(inputstring);
  }
  
  /// Create a numerical hash of a string token.
  int _hashToken(String inputstring) {
    final bytes = utf8.encode(inputstring);
    final digest = sha256.convert(bytes);
    // Take first 8 bytes as BigInt
    var result = 0;
    for (var i = 0; i < 8; i++) {
      result = (result << 8) | digest.bytes[i];
    }
    return result;
  }
  
  /// Create vector to add to the existing string vector.
  List<int> _vectorToAdd(String token) {
    final h = _hashToken(token);
    return List.generate(length, (i) => (h & (1 << i)) != 0 ? 1 : -1);
  }
  
  /// Calculate a Charikar simhash.
  int _createHash(String inputstring) {
    final vector = List.filled(length, 0);
    
    for (final token in sampleTokens(inputstring, length: length)) {
      final toAdd = _vectorToAdd(token);
      for (var i = 0; i < length; i++) {
        vector[i] += toAdd[i];
      }
    }
    
    var result = 0;
    for (var i = 0; i < length; i++) {
      if (vector[i] >= 0) {
        result |= (1 << i);
      }
    }
    return result;
  }
  
  /// Convert the numerical hash to a hexadecimal string.
  String toHex() {
    return hash.toRadixString(16);
  }
  
  /// Convert hexadecimal hash to numerical value.
  int? _hashToInt(String inputhash) {
    try {
      return int.parse(inputhash, radix: 16);
    } catch (e) {
      return null;
    }
  }
  
  /// Validate the input hash and return it, or null otherwise.
  int? _validate(dynamic inputhash) {
    if (inputhash is int && inputhash.toString().length >= 18 && inputhash.toString().length <= 22) {
      return inputhash;
    }
    if (inputhash is String) {
      if (RegExp(r'^\d+$').hasMatch(inputhash) && inputhash.length >= 18 && inputhash.length <= 22) {
        return int.parse(inputhash);
      }
      // Possibly a hex string
      return _hashToInt(inputhash);
    }
    return null;
  }
  
  /// Return distance between two hashes using XOR operator.
  int hammingDistance(Simhash otherHash) {
    final xor = hash ^ otherHash.hash;
    return _bitCount(xor);
  }
  
  /// Count the number of 1 bits in an integer.
  int _bitCount(int n) {
    var count = 0;
    while (n > 0) {
      count += n & 1;
      n >>= 1;
    }
    return count;
  }
  
  /// Calculate how similar this hash is from another simhash.
  /// Returns a float from 0.0 to 1.0.
  double similarity(Simhash otherHash) {
    return (length - hammingDistance(otherHash)) / length;
  }
  
  /// Static placeholder for cache clearing (no-op as Simhash doesn't cache).
  static void clearCache() {
    // No internal cache to clear in this implementation
  }
}

/// Calculate a simhash hex value for meaningful bits of the content.
String contentFingerprint(String content) {
  return Simhash(content).toHex();
}

// Link field indices for LRU cache
const _prev = 0;
const _next = 1;
const _key = 2;
const _result = 3;

/// Pure-Dart Least Recently Used (LRU) cache using a circular doubly linked list.
class LRUCache {
  /// Maximum cache size
  final int maxsize;
  
  /// Cache storage
  final Map<String, List<dynamic>> _cache = {};
  
  /// Root of circular doubly linked list
  late List<dynamic> _root;
  
  /// Whether cache is full
  bool _full = false;
  
  /// Create a new LRU cache with given maximum size.
  LRUCache({this.maxsize = 128}) {
    _root = <dynamic>[null, null, null, null];
    _root[_prev] = _root;
    _root[_next] = _root;
  }
  
  /// Move the link to the front of the circular queue.
  dynamic _moveLink(List<dynamic> link) {
    final linkPrev = link[_prev] as List<dynamic>;
    final linkNext = link[_next] as List<dynamic>;
    final result = link[_result];
    
    linkPrev[_next] = linkNext;
    linkNext[_prev] = linkPrev;
    
    final last = _root[_prev] as List<dynamic>;
    last[_next] = link;
    _root[_prev] = link;
    link[_prev] = last;
    link[_next] = _root;
    
    return result;
  }
  
  /// Get value from cache, returns -1 if not found.
  dynamic get(String key) {
    final link = _cache[key];
    if (link != null) {
      return _moveLink(link);
    }
    return -1;
  }
  
  /// Store a key-value pair in the cache.
  void put(String key, dynamic value) {
    final existingLink = _cache[key];
    if (existingLink != null) {
      _moveLink(existingLink);
      existingLink[_result] = value;
    } else {
      if (_full) {
        // Use the old root to store the new key and result
        final oldroot = _root;
        oldroot[_key] = key;
        oldroot[_result] = value;
        
        // Empty the oldest link and make it the new root
        _root = oldroot[_next] as List<dynamic>;
        final oldkey = _root[_key] as String?;
        _root[_key] = null;
        _root[_result] = null;
        
        // Update cache dictionary
        if (oldkey != null) {
          _cache.remove(oldkey);
        }
        _cache[key] = oldroot;
      } else {
        // Put result in a new link at the front of the queue
        final last = _root[_prev] as List<dynamic>;
        final link = <dynamic>[last, _root, key, value];
        last[_next] = link;
        _root[_prev] = link;
        _cache[key] = link;
        _full = _cache.length >= maxsize;
      }
    }
  }
  
  /// Clear all cache content.
  void clear() {
    _cache.clear();
    _root[_prev] = _root;
    _root[_next] = _root;
    _root[_key] = null;
    _root[_result] = null;
    _full = false;
  }
}

/// Global LRU cache for deduplication tests
final LRUCache lruTest = LRUCache(maxsize: lruSize);

/// Put a string in the LRU cache.
void putInCache(String teststring) {
  final cacheval = lruTest.get(teststring);
  final value = cacheval != -1 ? cacheval + 1 : 1;
  lruTest.put(teststring, value);
}

/// Check for duplicate text with LRU cache.
bool duplicateTest(dom.Element element, Extractor options) {
  final teststring = trim(element.text);
  
  if (teststring.length > options.minDuplcheckSize) {
    // Retrieve value from cache
    final cacheval = lruTest.get(teststring);
    if (cacheval > options.maxRepetitions) {
      lruTest.put(teststring, cacheval + 1);
      return true;
    }
  }
  
  putInCache(teststring);
  return false;
}

/// Check for text filtering based on element content.
bool textfilter(dom.Element element) {
  final text = trim(element.text);
  // Very short text or empty
  if (text.length < 5) {
    return true;
  }
  return false;
}

/// Check if element is an image element with valid attributes.
bool isImageElement(dom.Element elem) {
  final src = elem.attributes['src'] ?? elem.attributes['data-src'] ?? '';
  return src.isNotEmpty && (src.startsWith('http') || src.startsWith('/') || src.startsWith('data:'));
}
