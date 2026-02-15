/// Meta-functions to be applied module-wide.
///
/// This module provides utility functions for cache management
/// and resource cleanup.
library;

import 'deduplication.dart';

/// Reset all known caches used to speed up processing.
///
/// This may release some memory by clearing internal caches.
void resetCaches() {
  // Clear LRU cache for deduplication
  lruTestCache.clear();
  
  // Clear Simhash vector cache
  Simhash.clearCache();
  
  // Clear domain similarity cache
  _domainSimilarityCache.clear();
}

/// Internal cache for domain similarity checks.
final Map<String, bool> _domainSimilarityCache = {};

/// Clear domain similarity cache explicitly.
void clearDomainSimilarityCache() {
  _domainSimilarityCache.clear();
}

/// Global LRU test cache instance.
final LRUCache lruTestCache = LRUCache(maxsize: 65536);
