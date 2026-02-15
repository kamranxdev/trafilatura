/// Element selector expressions for content and metadata extraction.
///
/// Since Dart's html package doesn't support XPath natively, this module
/// provides equivalent CSS selectors and custom element selection functions.
library;

import 'package:html/dom.dart' as dom;

/// Element selector function type
typedef ElementSelector = List<dom.Element> Function(dom.Element tree);

// =============================================================================
// CONTENT SELECTORS
// =============================================================================

/// Body content class patterns
const List<String> bodyClassPatterns = [
  'post-text',
  'post_text',
  'post-body',
  'post-entry',
  'postentry',
  'post-content',
  'post_content',
  'postcontent',
  'postContent',
  'post_inner_wrapper',
  'article-text',
  'articletext',
  'articleText',
  'entry-content',
  'article-content',
  'article__content',
  'article-body',
  'article__body',
  'articlebody',
  'ArticleContent',
  'page-content',
  'text-content',
  'body-text',
  'article__container',
  'art-content',
];

/// Body ID patterns
const List<String> bodyIdPatterns = [
  'entry-content',
  'article-content',
  'article__content',
  'article-body',
  'article__body',
  'articlebody',
  'body-text',
  'art-content',
];

/// Secondary body class patterns
const List<String> secondaryBodyClassPatterns = [
  'post-bodycopy',
  'storycontent',
  'story-content',
  'postarea',
  'art-postcontent',
  'theme-content',
  'blog-content',
  'section-content',
  'single-content',
  'single-post',
  'main-column',
  'wpb_text_column',
  'story-body',
  'field-body',
  'fulltext',
];

/// Content class patterns
const List<String> contentClassPatterns = [
  'content-main',
  'content_main',
  'content-body',
  'content__body',
  'main-content',
  'page-content',
];

/// Select body elements from the document.
List<dom.Element> selectBodyElements(dom.Element tree) {
  final results = <dom.Element>[];
  
  // First try: specific article containers
  for (final tag in ['article', 'div', 'main', 'section']) {
    for (final elem in tree.querySelectorAll(tag)) {
      final className = elem.className.toLowerCase();
      final id = (elem.attributes['id'] ?? '').toLowerCase();
      
      // Check class patterns
      for (final pattern in bodyClassPatterns) {
        if (className.contains(pattern.toLowerCase())) {
          results.add(elem);
          break;
        }
      }
      
      // Check ID patterns
      for (final pattern in bodyIdPatterns) {
        if (id.contains(pattern.toLowerCase())) {
          results.add(elem);
          break;
        }
      }
      
      // Check itemprop
      if (elem.attributes['itemprop'] == 'articleBody') {
        results.add(elem);
      }
    }
  }
  
  if (results.isNotEmpty) return [results.first];
  
  // Second try: article tag
  final articles = tree.querySelectorAll('article');
  if (articles.isNotEmpty) return [articles.first];
  
  // Third try: secondary patterns
  for (final tag in ['article', 'div', 'main', 'section']) {
    for (final elem in tree.querySelectorAll(tag)) {
      final className = elem.className.toLowerCase();
      final id = (elem.attributes['id'] ?? '').toLowerCase();
      final role = elem.attributes['role'] ?? '';
      
      for (final pattern in secondaryBodyClassPatterns) {
        if (className.contains(pattern.toLowerCase()) || id.contains(pattern.toLowerCase())) {
          results.add(elem);
          break;
        }
      }
      
      if (role == 'article') {
        results.add(elem);
      }
    }
  }
  
  if (results.isNotEmpty) return [results.first];
  
  // Fourth try: content patterns
  for (final tag in ['article', 'div', 'main', 'section']) {
    for (final elem in tree.querySelectorAll(tag)) {
      final className = elem.className.toLowerCase();
      final id = (elem.attributes['id'] ?? '').toLowerCase();
      
      for (final pattern in contentClassPatterns) {
        if (className.contains(pattern.toLowerCase()) || id.contains(pattern.toLowerCase())) {
          results.add(elem);
          break;
        }
      }
      
      if (id == 'content' || className == 'content') {
        results.add(elem);
      }
    }
  }
  
  if (results.isNotEmpty) return [results.first];
  
  // Fifth try: main elements
  for (final tag in ['article', 'div', 'section', 'main']) {
    for (final elem in tree.querySelectorAll(tag)) {
      final className = elem.className.toLowerCase();
      final id = (elem.attributes['id'] ?? '').toLowerCase();
      final role = elem.attributes['role'] ?? '';
      
      if (className.startsWith('main') || id.startsWith('main') || role.startsWith('main')) {
        results.add(elem);
      }
    }
  }
  
  final mains = tree.querySelectorAll('main');
  results.addAll(mains);
  
  if (results.isNotEmpty) return [results.first];
  
  return [];
}

/// Comments class patterns
const List<String> commentsClassPatterns = [
  'commentlist',
  'comment-page',
  'comment-list',
  'comments-content',
  'post-comments',
  'comments',
  'comment-',
  'article-comments',
  'comol',
  'disqus_thread',
  'dsq-comments',
];

/// Select comment elements from the document.
List<dom.Element> selectCommentElements(dom.Element tree) {
  final results = <dom.Element>[];
  
  for (final tag in ['div', 'section', 'ul', 'ol']) {
    for (final elem in tree.querySelectorAll(tag)) {
      final className = elem.className.toLowerCase();
      final id = (elem.attributes['id'] ?? '').toLowerCase();
      
      for (final pattern in commentsClassPatterns) {
        if (className.contains(pattern) || id.contains(pattern)) {
          results.add(elem);
          break;
        }
      }
    }
  }
  
  return results;
}

/// Select elements to remove from comments.
List<dom.Element> selectCommentsToRemove(dom.Element tree) {
  final results = <dom.Element>[];
  
  for (final tag in ['div', 'section', 'ul', 'ol', 'span']) {
    for (final elem in tree.querySelectorAll(tag)) {
      final className = elem.className.toLowerCase();
      final id = (elem.attributes['id'] ?? '').toLowerCase();
      
      if (className.startsWith('comment') ||
          id.startsWith('comment') ||
          className.contains('article-comments') ||
          className.contains('post-comments') ||
          id.startsWith('comol') ||
          id.startsWith('disqus_thread') ||
          id.startsWith('dsq-comments')) {
        results.add(elem);
      }
    }
  }
  
  return results;
}

/// Discard patterns for overall cleanup
const List<String> overallDiscardPatterns = [
  'footer',
  'related',
  'viral',
  'shar',
  'share-',
  'share',
  'social',
  'sociable',
  'syndication',
  'jp-',
  'dpsp-content',
  'embedded',
  'embed',
  'newsletter',
  'subnav',
  'cookie',
  'tags',
  'tag-list',
  'sidebar',
  'banner',
  'bar',
  'meta',
  'menu',
  'nav',
  'avigation',
  'navbar',
  'navbox',
  'post-nav',
  'breadcrumb',
  'bread-crumb',
  'author',
  'button',
  'byline',
  'rating',
  'widget',
  'attachment',
  'timestamp',
  'user-info',
  'user-profile',
  '-ad-',
  '-icon',
  'article-infos',
  'nfoline',
  'outbrain',
  'taboola',
  'criteo',
  'options',
  'expand',
  'consent',
  'modal-content',
  ' ad ',
  'permission',
  'next-',
  '-stories',
  'most-popular',
  'mol-factbox',
  'ZendeskForm',
  'message-container',
  'slide',
  'viewport',
  'premium',
  'overlay',
  'paid-content',
  'paidcontent',
  'obfuscated',
  'blurred',
];

/// Patterns for hidden content
const List<String> hiddenPatterns = [
  'comments-title',
  'nocomments',
  'reply-',
  '-reply-',
  'message',
  'reader-comments',
  'akismet',
  'suggest-links',
  'hide-',
  '-hide-',
  'hide-print',
  'hidden',
  ' hidden',
  ' hide',
  'noprint',
  'display:none',
  'display: none',
  'notloaded',
];

/// Select elements to discard from the document.
List<dom.Element> selectElementsToDiscard(dom.Element tree) {
  final results = <dom.Element>[];
  
  for (final tag in ['div', 'item', 'li', 'p', 'section', 'span']) {
    for (final elem in tree.querySelectorAll(tag)) {
      final className = elem.className.toLowerCase();
      final id = (elem.attributes['id'] ?? '').toLowerCase();
      final style = elem.attributes['style'] ?? '';
      final ariaHidden = elem.attributes['aria-hidden'];
      final role = elem.attributes['role'] ?? '';
      
      // Check main discard patterns
      for (final pattern in overallDiscardPatterns) {
        if (className.contains(pattern.toLowerCase()) || 
            id.contains(pattern.toLowerCase()) ||
            role.toLowerCase().contains(pattern.toLowerCase())) {
          results.add(elem);
          break;
        }
      }
      
      // Check hidden patterns
      for (final pattern in hiddenPatterns) {
        if (className.contains(pattern.toLowerCase()) ||
            id.contains(pattern.toLowerCase()) ||
            style.toLowerCase().contains(pattern.toLowerCase())) {
          results.add(elem);
          break;
        }
      }
      
      if (ariaHidden == 'true') {
        results.add(elem);
      }
    }
  }
  
  return results;
}

/// Select teaser elements to discard.
List<dom.Element> selectTeasersToDiscard(dom.Element tree) {
  final results = <dom.Element>[];
  
  for (final tag in ['div', 'item', 'li', 'p', 'section', 'span']) {
    for (final elem in tree.querySelectorAll(tag)) {
      final className = elem.className.toLowerCase();
      final id = (elem.attributes['id'] ?? '').toLowerCase();
      
      if (className.contains('teaser') || id.contains('teaser')) {
        results.add(elem);
      }
    }
  }
  
  return results;
}

/// Select elements for precision mode discard.
List<dom.Element> selectPrecisionDiscardElements(dom.Element tree) {
  final results = <dom.Element>[];
  
  // Headers
  results.addAll(tree.querySelectorAll('header'));
  
  // Elements with bottom, link, or border
  for (final tag in ['div', 'item', 'li', 'p', 'section', 'span']) {
    for (final elem in tree.querySelectorAll(tag)) {
      final className = elem.className.toLowerCase();
      final id = (elem.attributes['id'] ?? '').toLowerCase();
      final style = elem.attributes['style'] ?? '';
      
      if (className.contains('bottom') ||
          id.contains('bottom') ||
          className.contains('link') ||
          id.contains('link') ||
          style.contains('border')) {
        results.add(elem);
      }
    }
  }
  
  return results;
}

/// Select overall discard elements for precision mode.
List<dom.Element> selectOverallDiscardElements(dom.Element tree) {
  final results = <dom.Element>[];
  
  // Combine multiple discard selectors
  results.addAll(selectElementsToDiscard(tree));
  results.addAll(selectPrecisionDiscardElements(tree));
  results.addAll(selectTeasersToDiscard(tree));
  
  return results..toSet().toList(); // Remove duplicates
}

/// Select image caption elements to discard.
List<dom.Element> selectImageCaptionElements(dom.Element tree) {
  final results = <dom.Element>[];
  
  for (final tag in ['div', 'item', 'li', 'p', 'section', 'span']) {
    for (final elem in tree.querySelectorAll(tag)) {
      final className = elem.className.toLowerCase();
      final id = (elem.attributes['id'] ?? '').toLowerCase();
      
      if (className.contains('caption') || id.contains('caption')) {
        results.add(elem);
      }
    }
  }
  
  return results;
}

/// Select elements to discard from comments section.
List<dom.Element> selectCommentsDiscardElements(dom.Element tree) {
  final results = <dom.Element>[];
  
  // Respond sections
  for (final tag in ['div', 'section']) {
    for (final elem in tree.querySelectorAll(tag)) {
      final id = (elem.attributes['id'] ?? '').toLowerCase();
      if (id.startsWith('respond')) {
        results.add(elem);
      }
    }
  }
  
  // Cite and quote elements
  results.addAll(tree.querySelectorAll('cite'));
  results.addAll(tree.querySelectorAll('quote'));
  
  // Comment-related unwanted elements
  for (final elem in tree.querySelectorAll('*')) {
    final className = elem.className.toLowerCase();
    final id = (elem.attributes['id'] ?? '').toLowerCase();
    final style = elem.attributes['style'] ?? '';
    
    if (className.contains('comments-title') ||
        className.contains('nocomments') ||
        className.startsWith('reply-') ||
        id.startsWith('reply-') ||
        className.contains('-reply-') ||
        className.contains('message') ||
        className.contains('signin') ||
        className.contains('akismet') ||
        id.contains('akismet') ||
        style.contains('display:none')) {
      results.add(elem);
    }
  }
  
  return results;
}

// =============================================================================
// METADATA SELECTORS
// =============================================================================

/// Author class/ID patterns
const List<String> authorPatterns = [
  'author',
  'author-name',
  'AuthorName',
  'authorName',
  'byline',
  'channel-name',
  'zuozhe',
  'bianji',
  'xiaobian',
  'submitted-by',
  'posted-by',
  'username',
  'byl',
  'journalist-name',
  'screenname',
  'Byline',
  'writer',
];

/// Select author elements from the document.
List<dom.Element> selectAuthorElements(dom.Element tree) {
  final results = <dom.Element>[];
  
  // Specific author elements
  for (final tag in ['a', 'address', 'div', 'link', 'p', 'span', 'strong']) {
    for (final elem in tree.querySelectorAll(tag)) {
      final rel = elem.attributes['rel'] ?? '';
      final id = (elem.attributes['id'] ?? '').toLowerCase();
      final className = elem.className.toLowerCase();
      final itemprop = elem.attributes['itemprop'] ?? '';
      final dataTestId = elem.attributes['data-testid'] ?? '';
      
      if (rel == 'author' ||
          rel == 'me' ||
          id == 'author' ||
          className == 'author' ||
          itemprop.contains('author') ||
          dataTestId == 'AuthorCard' ||
          dataTestId == 'AuthorURL') {
        results.add(elem);
        continue;
      }
      
      for (final pattern in authorPatterns) {
        if (className.contains(pattern.toLowerCase()) || id.contains(pattern.toLowerCase())) {
          results.add(elem);
          break;
        }
      }
    }
  }
  
  // Author tag elements
  results.addAll(tree.querySelectorAll('author'));
  
  return results;
}

/// Patterns to discard from author search
const List<String> authorDiscardPatterns = [
  'comments',
  'commentlist',
  'title',
  'date',
  'sidebar',
  'is-hidden',
  'quote',
  'comment-list',
  'comments-list',
  'embedly-instagram',
  'ProductReviews',
  'Figure',
  'article-share',
  'article-support',
  'print',
  'category',
  'meta-date',
  'meta-reviewer',
];

/// Select elements to discard from author search.
List<dom.Element> selectAuthorDiscardElements(dom.Element tree) {
  final results = <dom.Element>[];
  
  for (final tag in ['a', 'div', 'section', 'span']) {
    for (final elem in tree.querySelectorAll(tag)) {
      final className = elem.className.toLowerCase();
      final id = (elem.attributes['id'] ?? '').toLowerCase();
      final dataComponent = elem.attributes['data-component'] ?? '';
      
      for (final pattern in authorDiscardPatterns) {
        if (className.contains(pattern.toLowerCase()) ||
            id.contains(pattern.toLowerCase()) ||
            className.startsWith(pattern.toLowerCase()) ||
            id.startsWith(pattern.toLowerCase()) ||
            dataComponent.contains(pattern)) {
          results.add(elem);
          break;
        }
      }
    }
  }
  
  // Time and figure elements
  results.addAll(tree.querySelectorAll('time'));
  results.addAll(tree.querySelectorAll('figure'));
  
  return results;
}

/// Category class patterns
const List<String> categoryClassPatterns = [
  'post-info',
  'postinfo',
  'post-meta',
  'postmeta',
  'meta',
  'entry-meta',
  'entry-info',
  'entry-utility',
  'postpath',
  'entry-categories',
  'entry-footer',
  'post-category',
  'postcategory',
  'entry-category',
  'cat-links',
  'entry-header',
];

/// Select category elements from the document.
List<dom.Element> selectCategoryElements(dom.Element tree) {
  final results = <dom.Element>[];
  
  // Div/p/footer/li/span with category class containing links
  for (final tag in ['div', 'p', 'footer', 'li', 'span', 'header']) {
    for (final elem in tree.querySelectorAll(tag)) {
      final className = elem.className.toLowerCase();
      final id = (elem.attributes['id'] ?? '').toLowerCase();
      
      for (final pattern in categoryClassPatterns) {
        if (className.contains(pattern.toLowerCase()) ||
            className.startsWith(pattern.toLowerCase()) ||
            id.startsWith(pattern.toLowerCase())) {
          // Get links inside
          results.addAll(elem.querySelectorAll('a[href]'));
          break;
        }
      }
    }
  }
  
  // Row/tags divs
  for (final elem in tree.querySelectorAll('div')) {
    final className = elem.className;
    if (className == 'row' || className == 'tags') {
      results.addAll(elem.querySelectorAll('a[href]'));
    }
  }
  
  return results;
}

/// Tag class patterns
const List<String> tagClassPatterns = [
  'tags',
  'entry-tags',
  'jp-relatedposts',
  'entry-utility',
  'tag',
  'postmeta',
  'meta',
  'entry-meta',
  'topics',
  'tags-links',
];

/// Select tag elements from the document.
List<dom.Element> selectTagElements(dom.Element tree) {
  final results = <dom.Element>[];
  
  for (final tag in ['div', 'p']) {
    for (final elem in tree.querySelectorAll(tag)) {
      final className = elem.className.toLowerCase();
      
      for (final pattern in tagClassPatterns) {
        if (className.contains(pattern.toLowerCase()) ||
            className.startsWith(pattern.toLowerCase()) ||
            className == pattern.toLowerCase()) {
          results.addAll(elem.querySelectorAll('a[href]'));
          break;
        }
      }
    }
  }
  
  return results;
}

/// Title class patterns
const List<String> titleClassPatterns = [
  'post-title',
  'entry-title',
  'headline',
  'post__title',
  'article-title',
  'title',
];

/// Select title elements from the document.
List<dom.Element> selectTitleElements(dom.Element tree) {
  final results = <dom.Element>[];
  
  // H1/H2 with title class
  for (final tag in ['h1', 'h2', 'h3']) {
    for (final elem in tree.querySelectorAll(tag)) {
      final className = elem.className.toLowerCase();
      final id = (elem.attributes['id'] ?? '').toLowerCase();
      final itemprop = elem.attributes['itemprop'] ?? '';
      
      for (final pattern in titleClassPatterns) {
        if (className.contains(pattern.toLowerCase()) ||
            id.contains(pattern.toLowerCase()) ||
            itemprop.contains(pattern.toLowerCase())) {
          results.add(elem);
          break;
        }
      }
    }
  }
  
  // Direct class match
  results.addAll(tree.querySelectorAll('.entry-title'));
  results.addAll(tree.querySelectorAll('.post-title'));
  
  return results;
}

/// Basic clean selector - elements to remove for basic cleaning.
List<dom.Element> selectBasicCleanElements(dom.Element tree) {
  final results = <dom.Element>[];
  
  // aside elements
  results.addAll(tree.querySelectorAll('aside'));
  
  // footer divs
  for (final elem in tree.querySelectorAll('div')) {
    final className = elem.className.toLowerCase();
    final id = (elem.attributes['id'] ?? '').toLowerCase();
    if (className.contains('footer') || id.contains('footer')) {
      results.add(elem);
    }
  }
  
  // footer elements
  results.addAll(tree.querySelectorAll('footer'));
  
  // script and style elements
  results.addAll(tree.querySelectorAll('script'));
  results.addAll(tree.querySelectorAll('style'));
  
  return results;
}
