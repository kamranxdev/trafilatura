/// Functions needed to scrape metadata from JSON-LD format.
/// For reference, here is the list of all JSON-LD types: https://schema.org/docs/full.html
library;

import 'dart:convert';

import 'settings.dart';
import 'utils.dart';

/// JSON article schema types
const Set<String> jsonArticleSchema = {
  'article',
  'backgroundnewsarticle',
  'blogposting',
  'medicalscholarlyarticle',
  'newsarticle',
  'opinionnewsarticle',
  'reportagenewsarticle',
  'scholarlyarticle',
  'socialmediaposting',
  'liveblogposting',
};

/// JSON OG type schema
const Set<String> jsonOgtypeSchema = {
  'aboutpage',
  'checkoutpage',
  'collectionpage',
  'contactpage',
  'faqpage',
  'itempage',
  'medicalwebpage',
  'profilepage',
  'qapage',
  'realestatelisting',
  'searchresultspage',
  'webpage',
  'website',
  'article',
  'advertisercontentarticle',
  'newsarticle',
  'analysisnewsarticle',
  'askpublicnewsarticle',
  'backgroundnewsarticle',
  'opinionnewsarticle',
  'reportagenewsarticle',
  'reviewnewsarticle',
  'report',
  'satiricalarticle',
  'scholarlyarticle',
  'medicalscholarlyarticle',
  'socialmediaposting',
  'blogposting',
  'liveblogposting',
  'discussionforumposting',
  'techarticle',
  'blog',
  'jobposting',
};

/// JSON publisher schema types
const Set<String> jsonPublisherSchema = {
  'newsmediaorganization',
  'organization',
  'webpage',
  'website',
};

/// Author attrs for name extraction
const List<String> _authorAttrs = ['givenName', 'additionalName', 'familyName'];

// Regex patterns
final _jsonAuthor1 = RegExp(
  r'"author":[^}\[]+?"name?\\?": ?\\?"([^"\\]+)|"author"[^}\[]+?"names?".+?"([^"]+)',
  dotAll: true,
);
final _jsonAuthor2 = RegExp(
  r'"[Pp]erson"[^}]+?"names?".+?"([^"]+)',
  dotAll: true,
);
final _jsonAuthorRemove = RegExp(
  r',?(?:"\w+":?[:|,\[])?{?"@type":"(?:[Ii]mageObject|[Oo]rganization|[Ww]eb[Pp]age)",[^}\[]+}[\]|}]?',
);
final _jsonPublisher = RegExp(
  r'"publisher":[^}]+?"name?\\?": ?\\?"([^"\\]+)',
  dotAll: true,
);
final _jsonType = RegExp(r'"@type"\s*:\s*"([^"]*)"', dotAll: true);
final _jsonCategory = RegExp(r'"articleSection": ?"([^"\\]+)', dotAll: true);
final _jsonRemoveHtml = RegExp(r'<[^>]+>');
final _jsonSchemaOrg = RegExp(r'^https?://schema\.org', caseSensitive: false);
final _jsonUnicodeReplace = RegExp(r'\\u([0-9a-fA-F]{4})');
final _jsonName = RegExp(r'"@type":"[Aa]rticle", ?"name": ?"([^"\\]+)', dotAll: true);
final _jsonHeadline = RegExp(r'"headline": ?"([^"\\]+)', dotAll: true);

// Author normalization patterns
final _authorPrefix = RegExp(
  r'^([a-zäöüß]+(ed|t))? ?(written by|words by|words|by|von|from) ',
  caseSensitive: false,
);
final _authorRemoveNumbers = RegExp(r'\d.+?$');
final _authorTwitter = RegExp(r'@[\w]+');
final _authorReplaceJoin = RegExp(r'[._+]');
final _authorRemoveNickname = RegExp(r'''["'({\['\'][^"]+?[''"\')\]}]''');
final _authorRemoveSpecial = RegExp(r'[^\w]+$|[:()?*$#!%/<>{}~¿]');
final _authorRemovePreposition = RegExp(
  r'\b\s+(am|on|for|at|in|to|from|of|via|with|—|-|–)\s+(.*)',
  caseSensitive: false,
);
final _authorEmail = RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b');
final _authorSplit = RegExp(r'/|;|,|\||&|(?:^|\W)[u|a]nd(?:$|\W)', caseSensitive: false);
final _authorEmojiRemove = RegExp(
  '['
  '\u2700-\u27BE'  // Dingbats
  '\u{1F600}-\u{1F64F}'  // Emoticons
  '\u2600-\u26FF'  // Miscellaneous Symbols
  '\u{1F300}-\u{1F5FF}'  // Miscellaneous Symbols And Pictographs
  '\u{1F900}-\u{1F9FF}'  // Supplemental Symbols and Pictographs
  '\u{1FA70}-\u{1FAFF}'  // Symbols and Pictographs Extended-A
  '\u{1F680}-\u{1F6FF}'  // Transport and Map Symbols
  ']+',
  unicode: true,
);
final _htmlStripTags = RegExp(r'<[^>]+>');

/// Determine if the candidate should be used as sitename.
bool isPlausibleSitename(
  Document metadata,
  dynamic candidate, [
  String? contentType,
]) {
  if (candidate != null && candidate is String && candidate.isNotEmpty) {
    if (metadata.sitename == null ||
        (metadata.sitename!.length < candidate.length && contentType != 'webpage')) {
      return true;
    }
    if (metadata.sitename != null &&
        metadata.sitename!.startsWith('http') &&
        !candidate.startsWith('http')) {
      return true;
    }
  }
  return false;
}

/// Find and extract selected metadata from JSON parts.
Document processParent(List<dynamic> parent, Document metadata) {
  for (final content in parent.whereType<Map<String, dynamic>>()) {
    // Try to extract publisher
    if (content['publisher'] is Map && content['publisher']['name'] != null) {
      metadata.sitename = content['publisher']['name'] as String?;
    }
    
    if (!content.containsKey('@type') || content['@type'] == null) {
      continue;
    }
    
    // Some websites use ['Person'] as type
    var contentType = content['@type'];
    if (contentType is List) {
      contentType = contentType.isNotEmpty ? contentType[0] : null;
    }
    if (contentType == null) continue;
    contentType = contentType.toString().toLowerCase();
    
    // The "pagetype" should only be returned if the page is some kind of article
    if (jsonOgtypeSchema.contains(contentType) && metadata.pagetype == null) {
      metadata.pagetype = normalizeJson(contentType);
    }
    
    if (jsonPublisherSchema.contains(contentType)) {
      final candidate = content['name'] ?? content['legalName'] ?? content['alternateName'];
      if (isPlausibleSitename(metadata, candidate, contentType)) {
        metadata.sitename = candidate as String?;
      }
    } else if (contentType == 'person') {
      final name = content['name'];
      if (name != null && name is String && !name.startsWith('http')) {
        metadata.author = normalizeAuthors(metadata.author, name);
      }
    } else if (jsonArticleSchema.contains(contentType)) {
      // Author and person
      if (content.containsKey('author')) {
        var listAuthors = content['author'];
        
        if (listAuthors is String) {
          try {
            listAuthors = jsonDecode(listAuthors);
          } catch (e) {
            metadata.author = normalizeAuthors(metadata.author, listAuthors);
          }
        }
        
        if (listAuthors is! List) {
          listAuthors = [listAuthors];
        }
        
        for (final author in listAuthors) {
          if (author is Map<String, dynamic>) {
            if (!author.containsKey('@type') || author['@type'] == 'Person') {
              String? authorName;
              
              if (author.containsKey('name')) {
                final name = author['name'];
                if (name is List) {
                  authorName = name.join('; ').replaceAll(RegExp(r'^; |; $'), '');
                } else if (name is Map && name.containsKey('name')) {
                  authorName = name['name'] as String?;
                } else if (name is String) {
                  authorName = name;
                }
              } else if (author.containsKey('givenName') && author.containsKey('familyName')) {
                authorName = _authorAttrs
                    .where((attr) => author.containsKey(attr))
                    .map((attr) => author[attr])
                    .join(' ');
              }
              
              if (authorName != null) {
                metadata.author = normalizeAuthors(metadata.author, authorName);
              }
            }
          }
        }
      }
      
      // Category
      if ((metadata.categories?.isEmpty ?? true) && content.containsKey('articleSection')) {
        final section = content['articleSection'];
        if (section is String) {
          metadata.categories = [section];
        } else if (section is List) {
          metadata.categories = section.whereType<String>().where((s) => s.isNotEmpty).toList();
        }
      }
      
      // Try to extract title
      if (metadata.title == null) {
        if (content.containsKey('name') && contentType == 'article') {
          metadata.title = content['name'] as String?;
        } else if (content.containsKey('headline')) {
          metadata.title = content['headline'] as String?;
        }
      }
    }
  }
  
  return metadata;
}

/// Parse and extract metadata from JSON-LD data.
Document extractJson(dynamic schema, Document metadata) {
  List<dynamic> schemaList;
  if (schema is Map<String, dynamic>) {
    schemaList = [schema];
  } else if (schema is List) {
    schemaList = schema;
  } else {
    return metadata;
  }
  
  for (final parent in schemaList.whereType<Map<String, dynamic>>()) {
    final context = parent['@context'];
    
    if (context != null && context is String && _jsonSchemaOrg.hasMatch(context)) {
      List<dynamic> processedParent;
      
      if (parent.containsKey('@graph')) {
        final graph = parent['@graph'];
        processedParent = graph is List ? graph : [graph];
      } else if (parent.containsKey('@type') &&
          parent['@type'] is String &&
          (parent['@type'] as String).toLowerCase().contains('liveblogposting') &&
          parent.containsKey('liveBlogUpdate')) {
        final updates = parent['liveBlogUpdate'];
        processedParent = updates is List ? updates : [updates];
      } else {
        processedParent = schemaList;
      }
      
      metadata = processParent(processedParent, metadata);
    }
  }
  
  return metadata;
}

/// Crudely extract author names from JSON-LD data.
String? extractJsonAuthor(String elemtext, RegExp regularExpression) {
  String? authors;
  var match = regularExpression.firstMatch(elemtext);
  
  while (match != null) {
    final authorName = match.group(1) ?? match.group(2);
    if (authorName != null && authorName.contains(' ')) {
      authors = normalizeAuthors(authors, authorName);
      elemtext = elemtext.replaceFirst(regularExpression, '');
      match = regularExpression.firstMatch(elemtext);
    } else {
      break;
    }
  }
  
  return authors;
}

/// Crudely extract metadata from JSON-LD data when parsing fails.
Document extractJsonParseError(String elem, Document metadata) {
  // Author info
  final elementTextAuthor = elem.replaceAll(_jsonAuthorRemove, '');
  final author = extractJsonAuthor(elementTextAuthor, _jsonAuthor1) ??
      extractJsonAuthor(elementTextAuthor, _jsonAuthor2);
  if (author != null) {
    metadata.author = author;
  }
  
  // Try to extract page type
  if (elem.contains('@type')) {
    final match = _jsonType.firstMatch(elem);
    if (match != null) {
      final candidate = normalizeJson(match.group(1)!.toLowerCase());
      if (jsonOgtypeSchema.contains(candidate)) {
        metadata.pagetype = candidate;
      }
    }
  }
  
  // Try to extract publisher
  if (elem.contains('"publisher"')) {
    final match = _jsonPublisher.firstMatch(elem);
    if (match != null && !match.group(1)!.contains(',')) {
      final candidate = normalizeJson(match.group(1)!);
      if (isPlausibleSitename(metadata, candidate)) {
        metadata.sitename = candidate;
      }
    }
  }
  
  // Category
  if (elem.contains('"articleSection"')) {
    final match = _jsonCategory.firstMatch(elem);
    if (match != null) {
      metadata.categories = [normalizeJson(match.group(1)!)];
    }
  }
  
  // Try to extract title
  final jsonSeq = [
    ('"name"', _jsonName),
    ('"headline"', _jsonHeadline),
  ];
  
  for (final (key, regex) in jsonSeq) {
    if (elem.contains(key) && metadata.title == null) {
      final match = regex.firstMatch(elem);
      if (match != null) {
        metadata.title = normalizeJson(match.group(1)!);
        break;
      }
    }
  }
  
  return metadata;
}

/// Normalize unicode strings and trim the output.
String normalizeJson(String string) {
  if (string.contains('\\')) {
    string = string
        .replaceAll('\\n', '')
        .replaceAll('\\r', '')
        .replaceAll('\\t', '');
    string = string.replaceAllMapped(
      _jsonUnicodeReplace,
      (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
    );
    // Remove surrogate pairs
    string = String.fromCharCodes(
      string.codeUnits.where((c) => c < 0xD800 || c > 0xDFFF),
    );
    string = _htmlUnescape(string);
  }
  return trim(_jsonRemoveHtml.hasMatch(string) 
      ? string.replaceAll(_jsonRemoveHtml, '') 
      : string);
}

/// HTML unescape utility
String _htmlUnescape(String text) {
  return text
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ')
      .replaceAllMapped(
        RegExp(r'&#(\d+);'),
        (m) => String.fromCharCode(int.parse(m.group(1)!)),
      )
      .replaceAllMapped(
        RegExp(r'&#x([0-9a-fA-F]+);'),
        (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
      );
}

/// Normalize author info to focus on author names only.
String? normalizeAuthors(String? currentAuthors, String authorString) {
  final newAuthors = <String>[];
  
  // Skip URLs and emails
  if (authorString.toLowerCase().startsWith('http') ||
      _authorEmail.hasMatch(authorString)) {
    return currentAuthors;
  }
  
  if (currentAuthors != null) {
    newAuthors.addAll(currentAuthors.split('; '));
  }
  
  // Fix unicode escapes
  if (authorString.contains('\\u')) {
    authorString = authorString.replaceAllMapped(
      RegExp(r'\\u([0-9a-fA-F]{4})'),
      (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
    );
  }
  
  // Fix HTML entities
  if (authorString.contains('&#') || authorString.contains('&amp;')) {
    authorString = _htmlUnescape(authorString);
  }
  
  // Remove HTML tags
  authorString = authorString.replaceAll(_htmlStripTags, '');
  
  // Examine names
  for (var author in authorString.split(_authorSplit)) {
    author = trim(author);
    if (author.isEmpty) continue;
    
    // Remove emoji
    author = author.replaceAll(_authorEmojiRemove, '');
    // Remove @username
    author = author.replaceAll(_authorTwitter, '');
    // Replace special characters with space
    author = trim(author.replaceAll(_authorReplaceJoin, ' '));
    author = author.replaceAll(_authorRemoveNickname, '');
    // Remove special characters
    author = author.replaceAll(_authorRemoveSpecial, '');
    author = author.replaceAll(_authorPrefix, '');
    author = author.replaceAll(_authorRemoveNumbers, '');
    author = author.replaceAll(_authorRemovePreposition, '');
    
    // Skip empty or improbably long strings
    if (author.isEmpty ||
        (author.length >= 50 && !author.contains(' ') && !author.contains('-'))) {
      continue;
    }
    
    // Title case
    if (!author[0].toUpperCase().contains(author[0]) ||
        author.split('').where((c) => c.toUpperCase() == c && c.toLowerCase() != c).length < 1) {
      author = _toTitleCase(author);
    }
    
    // Safety checks
    if (!newAuthors.contains(author) &&
        (newAuthors.isEmpty || newAuthors.every((a) => !author.contains(a)))) {
      newAuthors.add(author);
    }
  }
  
  if (newAuthors.isEmpty) {
    return currentAuthors;
  }
  
  return newAuthors.join('; ').replaceAll(RegExp(r'^; |; $'), '');
}

/// Convert string to title case.
String _toTitleCase(String text) {
  return text.split(' ').map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}
