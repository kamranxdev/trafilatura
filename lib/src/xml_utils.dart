/// XML generation, processing and validation functions.
///
/// Provides functions for building XML output, TEI conversion,
/// and text extraction from XML structures.
library;

import 'dart:convert';
import 'package:xml/xml.dart';

import 'settings.dart';
import 'utils.dart';

/// Package version
const String pkgVersion = '2.0.0';

/// TEI schema path
const String teiSchema = 'lib/src/data/tei_corpus.dtd';

/// Valid TEI tags
const Set<String> teiValidTags = {
  'ab', 'body', 'cell', 'code', 'del', 'div', 'graphic', 'head', 'hi',
  'item', 'lb', 'list', 'p', 'quote', 'ref', 'row', 'table'
};

/// Valid TEI attributes
const Set<String> teiValidAttrs = {'rend', 'rendition', 'role', 'target', 'type'};

/// Tags that should have tail removed
const Set<String> teiRemoveTail = {'ab', 'p'};

/// Valid siblings for div in TEI
const Set<String> teiDivSiblings = {'p', 'list', 'table', 'quote', 'ab'};

/// Elements that should have newlines appended
const Set<String> newlineElems = {'graphic', 'head', 'lb', 'list', 'p', 'quote', 'row', 'table'};

/// Special formatting elements
const Set<String> specialFormatting = {'code', 'del', 'head', 'hi', 'ref', 'item', 'cell'};

/// Elements that need attributes preserved
const Set<String> withAttributes = {'cell', 'row', 'del', 'graphic', 'head', 'hi', 'item', 'list', 'ref'};

/// Elements allowed for nesting
const Set<String> nestingWhitelist = {'cell', 'figure', 'item', 'note', 'quote'};

/// Meta attributes to include in output
const List<String> metaAttributes = [
  'sitename', 'title', 'author', 'date', 'url', 'hostname',
  'description', 'categories', 'tags', 'license', 'id',
  'fingerprint', 'language'
];

/// Hi formatting for markdown conversion
const Map<String, String> hiFormatting = {
  '#b': '**',
  '#i': '*',
  '#u': '__',
  '#t': '`',
};

/// Maximum table width
const int maxTableWidth = 1000;

/// Delete an element from its parent.
void deleteElement(XmlElement element, {bool keepTail = true}) {
  final parent = element.parent;
  if (parent == null || parent is! XmlElement) return;
  
  // Handle tail text preservation - in XML, text follows elements
  // We need to preserve the text that follows this element
  if (keepTail) {
    final siblings = parent.children.toList();
    final index = siblings.indexOf(element);
    
    // Check for text node after this element
    if (index + 1 < siblings.length && siblings[index + 1] is XmlText) {
      final tailText = (siblings[index + 1] as XmlText).value;
      
      // Find previous sibling element or prepend to parent
      XmlElement? previousElement;
      for (var i = index - 1; i >= 0; i--) {
        if (siblings[i] is XmlElement) {
          previousElement = siblings[i] as XmlElement;
          break;
        }
      }
      
      if (previousElement != null) {
        // Append to previous element's trailing text
        final prevIndex = parent.children.indexOf(previousElement);
        if (prevIndex + 1 < parent.children.length && parent.children[prevIndex + 1] is XmlText) {
          final existingText = (parent.children[prevIndex + 1] as XmlText).value;
          parent.children[prevIndex + 1] = XmlText('$existingText$tailText');
        } else {
          parent.children.insert(prevIndex + 1, XmlText(tailText));
        }
      } else {
        // Prepend to parent's text
        final existingText = parent.innerText;
        if (parent.children.isNotEmpty && parent.children.first is XmlText) {
          parent.children.first = XmlText('$tailText$existingText');
        } else {
          parent.children.insert(0, XmlText(tailText));
        }
      }
    }
  }
  
  parent.children.remove(element);
}

/// Merge element with its parent and convert formatting to markdown.
void mergeWithParent(XmlElement element, {bool includeFormatting = false}) {
  final parent = element.parent;
  if (parent == null || parent is! XmlElement) return;
  
  final fullText = replaceElementText(element, includeFormatting);
  
  final siblings = parent.children.toList();
  final index = siblings.indexOf(element);
  
  // Find previous element or use parent text
  XmlElement? previous;
  for (var i = index - 1; i >= 0; i--) {
    if (siblings[i] is XmlElement) {
      previous = siblings[i] as XmlElement;
      break;
    }
  }
  
  if (previous != null) {
    // Append to previous element's tail
    final prevIndex = parent.children.indexOf(previous);
    if (prevIndex + 1 < parent.children.length && parent.children[prevIndex + 1] is XmlText) {
      final existingText = (parent.children[prevIndex + 1] as XmlText).value;
      parent.children[prevIndex + 1] = XmlText('$existingText $fullText');
    } else {
      parent.children.insert(prevIndex + 1, XmlText(' $fullText'));
    }
  } else {
    // Prepend to parent text
    if (parent.children.isNotEmpty && parent.children.first is XmlText) {
      final existingText = (parent.children.first as XmlText).value;
      parent.children.first = XmlText('$existingText $fullText');
    } else {
      parent.children.insert(0, XmlText(fullText));
    }
  }
  
  parent.children.remove(element);
}

/// Remove text elements without text.
XmlElement removeEmptyElements(XmlElement tree) {
  final elementsToRemove = <XmlElement>[];
  
  for (final element in tree.descendants.whereType<XmlElement>()) {
    if (element.children.whereType<XmlElement>().isEmpty &&
        !textCharsTest(element.innerText)) {
      final parent = element.parent;
      if (parent != null && 
          parent is XmlElement && 
          element.name.local != 'graphic' &&
          parent.name.local != 'code') {
        elementsToRemove.add(element);
      }
    }
  }
  
  for (final elem in elementsToRemove) {
    elem.parent?.children.remove(elem);
  }
  
  return tree;
}

/// Prevent nested tags among a fixed list of tags.
XmlElement stripDoubleTags(XmlElement tree) {
  for (final tag in ['head', 'code', 'p']) {
    for (final elem in tree.findAllElements(tag).toList().reversed) {
      for (final subelem in elem.findAllElements(tag).toList()) {
        final parent = subelem.parent;
        if (parent != null && 
            parent is XmlElement && 
            !nestingWhitelist.contains(parent.name.local)) {
          mergeWithParent(subelem);
        }
      }
    }
  }
  return tree;
}

/// Build JSON output based on extracted information.
String buildJsonOutput(Document docmeta, {bool withMetadata = true}) {
  Map<String, dynamic> outputdict;
  
  if (withMetadata) {
    outputdict = {
      'source': docmeta.url,
      'source-hostname': docmeta.sitename,
      'title': docmeta.title,
      'author': docmeta.author,
      'date': docmeta.date,
      'description': docmeta.description,
      'categories': docmeta.categories?.join(';'),
      'tags': docmeta.tags?.join(';'),
      'fingerprint': docmeta.fingerprint,
      'id': docmeta.id,
      'license': docmeta.license,
      'language': docmeta.language,
      'image': docmeta.image,
      'pagetype': docmeta.pagetype,
      'text': xmltotxt(docmeta.body, includeFormatting: false),
      'comments': docmeta.commentsbody != null 
          ? xmltotxt(docmeta.commentsbody!, includeFormatting: false)
          : null,
    };
  } else {
    outputdict = {
      'text': xmltotxt(docmeta.body, includeFormatting: false),
      'comments': docmeta.commentsbody != null
          ? xmltotxt(docmeta.commentsbody!, includeFormatting: false)
          : null,
    };
  }
  
  return jsonEncode(outputdict);
}

/// Build HTML output based on extracted information.
String buildHtmlOutput(Document docmeta, {bool withMetadata = true}) {
  final buffer = StringBuffer();
  buffer.writeln('<!DOCTYPE html>');
  buffer.writeln('<html>');
  buffer.writeln('<head>');
  buffer.writeln('<meta charset="utf-8">');
  if (docmeta.title != null) {
    buffer.writeln('<title>${_escapeHtml(docmeta.title!)}</title>');
  }
  if (withMetadata) {
    if (docmeta.author != null) {
      buffer.writeln('<meta name="author" content="${_escapeHtml(docmeta.author!)}">');
    }
    if (docmeta.description != null) {
      buffer.writeln('<meta name="description" content="${_escapeHtml(docmeta.description!)}">');
    }
    if (docmeta.date != null) {
      buffer.writeln('<meta name="date" content="${_escapeHtml(docmeta.date!)}">');
    }
    if (docmeta.url != null) {
      buffer.writeln('<link rel="canonical" href="${_escapeHtml(docmeta.url!)}">');
    }
  }
  buffer.writeln('</head>');
  buffer.writeln('<body>');
  buffer.writeln(docmeta.body.toXmlString(pretty: true));
  if (docmeta.commentsbody != null) {
    buffer.writeln('<section class="comments">');
    buffer.writeln(docmeta.commentsbody!.toXmlString(pretty: true));
    buffer.writeln('</section>');
  }
  buffer.writeln('</body>');
  buffer.writeln('</html>');
  return buffer.toString();
}

/// Helper function to escape HTML entities.
String _escapeHtml(String text) {
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

/// Remove unnecessary attributes.
XmlElement cleanAttributes(XmlElement tree) {
  for (final elem in tree.descendants.whereType<XmlElement>()) {
    if (!withAttributes.contains(elem.name.local)) {
      elem.attributes.clear();
    }
  }
  return tree;
}

/// Build XML output tree based on extracted information.
XmlElement buildXmlOutput(Document docmeta) {
  final output = XmlElement(XmlName('doc'));
  addXmlMeta(output, docmeta);
  
  // Clone and rename body
  final body = docmeta.body.copy();
  final main = XmlElement(XmlName('main'));
  for (final child in body.children.toList()) {
    main.children.add(child.copy());
  }
  output.children.add(cleanAttributes(main));
  
  // Clone and rename comments
  if (docmeta.commentsbody != null) {
    final comments = XmlElement(XmlName('comments'));
    for (final child in docmeta.commentsbody!.children.toList()) {
      comments.children.add(child.copy());
    }
    output.children.add(cleanAttributes(comments));
  }
  
  return output;
}

/// Make sure the XML output is conform and valid if required.
String controlXmlOutput(Document document, Extractor options) {
  stripDoubleTags(document.body);
  removeEmptyElements(document.body);
  
  XmlElement outputTree;
  if (options.format == 'xml') {
    outputTree = buildXmlOutput(document);
  } else {
    outputTree = buildTeiOutput(document);
  }
  
  // Sanitize - would need proper implementation
  // For now, just return the formatted output
  return outputTree.toXmlString(pretty: true).trim();
}

/// Add extracted metadata to the XML output tree.
void addXmlMeta(XmlElement output, Document docmeta) {
  if (docmeta.sitename != null) output.setAttribute('sitename', docmeta.sitename!);
  if (docmeta.title != null) output.setAttribute('title', docmeta.title!);
  if (docmeta.author != null) output.setAttribute('author', docmeta.author!);
  if (docmeta.date != null) output.setAttribute('date', docmeta.date!);
  if (docmeta.url != null) output.setAttribute('url', docmeta.url!);
  if (docmeta.hostname != null) output.setAttribute('hostname', docmeta.hostname!);
  if (docmeta.description != null) output.setAttribute('description', docmeta.description!);
  if (docmeta.categories != null) output.setAttribute('categories', docmeta.categories!.join(';'));
  if (docmeta.tags != null) output.setAttribute('tags', docmeta.tags!.join(';'));
  if (docmeta.license != null) output.setAttribute('license', docmeta.license!);
  if (docmeta.id != null) output.setAttribute('id', docmeta.id!);
  if (docmeta.fingerprint != null) output.setAttribute('fingerprint', docmeta.fingerprint!);
  if (docmeta.language != null) output.setAttribute('language', docmeta.language!);
}

/// Build TEI-XML output tree based on extracted information.
XmlElement buildTeiOutput(Document docmeta) {
  final output = writeTeiTree(docmeta);
  return checkTei(output, docmeta.url);
}

/// Check if the resulting XML file is conform and scrub remaining tags.
XmlElement checkTei(XmlElement xmldoc, String? url) {
  // Convert head tags to ab
  for (final elem in xmldoc.findAllElements('head').toList()) {
    final newElem = XmlElement(XmlName('ab'));
    newElem.setAttribute('type', 'header');
    
    for (final attr in elem.attributes) {
      newElem.setAttribute(attr.name.local, attr.value);
    }
    
    for (final child in elem.children.toList()) {
      newElem.children.add(child.copy());
    }
    
    final parent = elem.parent;
    if (parent != null && parent is XmlElement) {
      final index = parent.children.indexOf(elem);
      parent.children[index] = newElem;
    }
  }
  
  // Look for invalid elements
  for (final elem in xmldoc.descendants.whereType<XmlElement>().toList()) {
    if (!teiValidTags.contains(elem.name.local)) {
      mergeWithParent(elem);
      continue;
    }
    
    // Check attributes
    final invalidAttrs = elem.attributes
        .where((a) => !teiValidAttrs.contains(a.name.local))
        .toList();
    for (final attr in invalidAttrs) {
      elem.removeAttribute(attr.name.local);
    }
  }
  
  return xmldoc;
}

/// Determine element text based on just the text of the element.
String replaceElementText(XmlElement element, bool includeFormatting) {
  var elemText = element.innerText;
  
  // Handle formatting: convert to markdown
  if (includeFormatting && elemText.isNotEmpty) {
    final tag = element.name.local;
    
    if ({'article', 'list', 'table'}.contains(tag)) {
      elemText = elemText.trim();
    } else if (tag == 'head') {
      var number = 2;
      final rend = element.getAttribute('rend');
      if (rend != null && rend.length > 1) {
        try {
          number = int.parse(rend[1]);
        } catch (e) {
          number = 2;
        }
      }
      elemText = '${'#' * number} $elemText';
    } else if (tag == 'del') {
      elemText = '~~$elemText~~';
    } else if (tag == 'hi') {
      final rend = element.getAttribute('rend');
      if (rend != null && hiFormatting.containsKey(rend)) {
        elemText = '${hiFormatting[rend]}$elemText${hiFormatting[rend]}';
      }
    } else if (tag == 'code') {
      if (elemText.contains('\n') || element.findElements('lb').isNotEmpty) {
        elemText = '```\n$elemText\n```\n';
      } else {
        elemText = '`$elemText`';
      }
    }
  }
  
  // Handle links
  if (element.name.local == 'ref') {
    if (elemText.isNotEmpty) {
      final linkText = '[$elemText]';
      final target = element.getAttribute('target');
      if (target != null) {
        elemText = '$linkText($target)';
      } else {
        elemText = linkText;
      }
    }
  }
  
  // Cells - strip whitespace
  if (element.name.local == 'cell') {
    elemText = elemText.trim();
  }
  
  return elemText;
}

/// Process element recursively for text extraction.
void processElement(XmlElement element, List<String> returnList, bool includeFormatting) {
  final tag = element.name.local;
  
  // Table cell start
  if (tag == 'cell') {
    final prev = _getPreviousSibling(element);
    if (prev == null) {
      returnList.add('| ');
    }
  }
  
  // Get element text (not including children)
  final directText = _getDirectText(element);
  if (directText.isNotEmpty) {
    returnList.add(replaceElementText(element, includeFormatting));
  }
  
  // Process children
  for (final child in element.children.whereType<XmlElement>()) {
    processElement(child, returnList, includeFormatting);
  }
  
  // Handle elements without direct text
  if (directText.isEmpty) {
    if (tag == 'graphic') {
      final title = element.getAttribute('title') ?? '';
      final alt = element.getAttribute('alt') ?? '';
      final src = element.getAttribute('src') ?? '';
      final text = '$title $alt'.trim();
      returnList.add('![$text]($src)');
    } else if (newlineElems.contains(tag)) {
      if (tag == 'row') {
        final cellCount = element.findAllElements('cell').length;
        final spanInfo = element.getAttribute('colspan') ?? element.getAttribute('span');
        var maxSpan = 1;
        if (spanInfo != null) {
          try {
            maxSpan = int.parse(spanInfo).clamp(1, maxTableWidth);
          } catch (e) {
            maxSpan = 1;
          }
        }
        
        if (cellCount < maxSpan) {
          returnList.add('${'|' * (maxSpan - cellCount)}\n');
        }
        
        // If this is a head row, draw the separator below
        if (element.findAllElements('cell')
            .any((c) => c.getAttribute('role') == 'head')) {
          returnList.add('\n|${'---|' * maxSpan}\n');
        }
      } else {
        returnList.add('\n');
      }
    } else if (tag == 'cell' || tag == 'item') {
      // Continue processing
    } else {
      return;
    }
  }
  
  // Common elements newline handling
  if (newlineElems.contains(tag)) {
    if (includeFormatting && tag != 'row') {
      returnList.add('\n\u2424\n');
    } else {
      returnList.add('\n');
    }
  } else if (tag == 'cell') {
    returnList.add(' | ');
  } else if (!specialFormatting.contains(tag)) {
    returnList.add(' ');
  }
}

/// Get direct text content of an element (not including children).
String _getDirectText(XmlElement element) {
  final buffer = StringBuffer();
  for (final child in element.children) {
    if (child is XmlText) {
      buffer.write(child.value);
    }
  }
  return buffer.toString().trim();
}

/// Get the previous sibling element.
XmlElement? _getPreviousSibling(XmlElement element) {
  final parent = element.parent;
  if (parent == null) return null;
  
  final siblings = parent.children.whereType<XmlElement>().toList();
  final index = siblings.indexOf(element);
  if (index <= 0) return null;
  
  return siblings[index - 1];
}

/// Convert to plain text format and optionally preserve formatting as markdown.
String xmltotxt(XmlElement? xmloutput, {required bool includeFormatting}) {
  if (xmloutput == null) return '';
  
  final returnList = <String>[];
  processElement(xmloutput, returnList, includeFormatting);
  
  final result = returnList.join();
  return sanitize(result, preserveSpace: true) ?? '';
}

/// Convert the internal XML document representation to a CSV string.
String xmltocsv(Document document, bool includeFormatting, {String delim = '\t', String nullVal = 'null'}) {
  final posttext = xmltotxt(document.body, includeFormatting: includeFormatting);
  final commentstext = document.commentsbody != null
      ? xmltotxt(document.commentsbody!, includeFormatting: includeFormatting)
      : nullVal;
  
  final fields = [
    document.url ?? nullVal,
    document.id ?? nullVal,
    document.fingerprint ?? nullVal,
    document.hostname ?? nullVal,
    document.title ?? nullVal,
    document.image ?? nullVal,
    document.date ?? nullVal,
    posttext.isEmpty ? nullVal : posttext,
    commentstext.isEmpty ? nullVal : commentstext,
    document.license ?? nullVal,
    document.pagetype ?? nullVal,
  ];
  
  // Escape fields and join with delimiter
  final escapedFields = fields.map((f) => _escapeCsvField(f, delim)).join(delim);
  return escapedFields;
}

/// Escape a CSV field value.
String _escapeCsvField(String field, String delim) {
  if (field.contains(delim) || field.contains('"') || field.contains('\n')) {
    return '"${field.replaceAll('"', '""')}"';
  }
  return field;
}

/// Bundle the extracted post and comments into a TEI tree.
XmlElement writeTeiTree(Document docmeta) {
  final teidoc = XmlElement(XmlName('TEI'));
  teidoc.setAttribute('xmlns', 'http://www.tei-c.org/ns/1.0');
  
  writeFullHeader(teidoc, docmeta);
  
  final textelem = XmlElement(XmlName('text'));
  teidoc.children.add(textelem);
  
  final textbody = XmlElement(XmlName('body'));
  textelem.children.add(textbody);
  
  // Post div
  final postbody = XmlElement(XmlName('div'));
  postbody.setAttribute('type', 'entry');
  for (final child in docmeta.body.children.toList()) {
    postbody.children.add(child.copy());
  }
  textbody.children.add(cleanAttributes(postbody));
  
  // Comments div
  if (docmeta.commentsbody != null) {
    final commentsbody = XmlElement(XmlName('div'));
    commentsbody.setAttribute('type', 'comments');
    for (final child in docmeta.commentsbody!.children.toList()) {
      commentsbody.children.add(child.copy());
    }
    textbody.children.add(cleanAttributes(commentsbody));
  }
  
  return teidoc;
}

/// Construct a publisher string to include in TEI header.
String _definePublisherString(Document docmeta) {
  if (docmeta.hostname != null && docmeta.sitename != null) {
    return '${docmeta.sitename!.trim()} (${docmeta.hostname})';
  }
  return docmeta.hostname ?? docmeta.sitename ?? 'N/A';
}

/// Write TEI header based on gathered metadata.
void writeFullHeader(XmlElement teidoc, Document docmeta) {
  final header = XmlElement(XmlName('teiHeader'));
  teidoc.children.add(header);
  
  final filedesc = XmlElement(XmlName('fileDesc'));
  header.children.add(filedesc);
  
  // Title statement
  final bibTitlestmt = XmlElement(XmlName('titleStmt'));
  filedesc.children.add(bibTitlestmt);
  
  final title = XmlElement(XmlName('title'));
  title.setAttribute('type', 'main');
  title.innerText = docmeta.title ?? '';
  bibTitlestmt.children.add(title);
  
  if (docmeta.author != null) {
    final author = XmlElement(XmlName('author'));
    author.innerText = docmeta.author!;
    bibTitlestmt.children.add(author);
  }
  
  // Publication statement
  final publicationstmt = XmlElement(XmlName('publicationStmt'));
  filedesc.children.add(publicationstmt);
  
  final publisherString = _definePublisherString(docmeta);
  
  if (docmeta.license != null) {
    final publisher = XmlElement(XmlName('publisher'));
    publisher.innerText = publisherString;
    publicationstmt.children.add(publisher);
    
    final availability = XmlElement(XmlName('availability'));
    publicationstmt.children.add(availability);
    
    final p = XmlElement(XmlName('p'));
    p.innerText = docmeta.license!;
    availability.children.add(p);
  } else {
    final p = XmlElement(XmlName('p'));
    publicationstmt.children.add(p);
  }
  
  // Notes statement
  final notesstmt = XmlElement(XmlName('notesStmt'));
  filedesc.children.add(notesstmt);
  
  if (docmeta.id != null) {
    final note = XmlElement(XmlName('note'));
    note.setAttribute('type', 'id');
    note.innerText = docmeta.id!;
    notesstmt.children.add(note);
  }
  
  if (docmeta.fingerprint != null) {
    final note = XmlElement(XmlName('note'));
    note.setAttribute('type', 'fingerprint');
    note.innerText = docmeta.fingerprint!;
    notesstmt.children.add(note);
  }
  
  // Source description
  final sourcedesc = XmlElement(XmlName('sourceDesc'));
  filedesc.children.add(sourcedesc);
  
  final sourceBibl = XmlElement(XmlName('bibl'));
  sourcedesc.children.add(sourceBibl);
  
  final sigle = [docmeta.sitename, docmeta.date].where((s) => s != null).join(', ');
  sourceBibl.innerText = [docmeta.title, sigle].where((s) => s != null && s.isNotEmpty).join(', ');
  
  final sigleBibl = XmlElement(XmlName('bibl'));
  sigleBibl.setAttribute('type', 'sigle');
  sigleBibl.innerText = sigle;
  sourcedesc.children.add(sigleBibl);
  
  // Full bibliographic entry
  final biblfull = XmlElement(XmlName('biblFull'));
  sourcedesc.children.add(biblfull);
  
  final bibTitlestmt2 = XmlElement(XmlName('titleStmt'));
  biblfull.children.add(bibTitlestmt2);
  
  final title2 = XmlElement(XmlName('title'));
  title2.setAttribute('type', 'main');
  title2.innerText = docmeta.title ?? '';
  bibTitlestmt2.children.add(title2);
  
  if (docmeta.author != null) {
    final author = XmlElement(XmlName('author'));
    author.innerText = docmeta.author!;
    bibTitlestmt2.children.add(author);
  }
  
  final publicationstmt2 = XmlElement(XmlName('publicationStmt'));
  biblfull.children.add(publicationstmt2);
  
  final publisher2 = XmlElement(XmlName('publisher'));
  publisher2.innerText = publisherString;
  publicationstmt2.children.add(publisher2);
  
  if (docmeta.url != null) {
    final ptr = XmlElement(XmlName('ptr'));
    ptr.setAttribute('type', 'URL');
    ptr.setAttribute('target', docmeta.url!);
    publicationstmt2.children.add(ptr);
  }
  
  final dateElem = XmlElement(XmlName('date'));
  dateElem.innerText = docmeta.date ?? '';
  publicationstmt2.children.add(dateElem);
  
  // Profile description
  final profiledesc = XmlElement(XmlName('profileDesc'));
  header.children.add(profiledesc);
  
  final abstract = XmlElement(XmlName('abstract'));
  profiledesc.children.add(abstract);
  
  final abstractP = XmlElement(XmlName('p'));
  abstractP.innerText = docmeta.description ?? '';
  abstract.children.add(abstractP);
  
  if ((docmeta.categories?.isNotEmpty ?? false) || (docmeta.tags?.isNotEmpty ?? false)) {
    final textclass = XmlElement(XmlName('textClass'));
    profiledesc.children.add(textclass);
    
    final keywords = XmlElement(XmlName('keywords'));
    textclass.children.add(keywords);
    
    if (docmeta.categories?.isNotEmpty ?? false) {
      final term = XmlElement(XmlName('term'));
      term.setAttribute('type', 'categories');
      term.innerText = docmeta.categories!.join(',');
      keywords.children.add(term);
    }
    
    if (docmeta.tags?.isNotEmpty ?? false) {
      final term = XmlElement(XmlName('term'));
      term.setAttribute('type', 'tags');
      term.innerText = docmeta.tags!.join(',');
      keywords.children.add(term);
    }
  }
  
  final creation = XmlElement(XmlName('creation'));
  profiledesc.children.add(creation);
  
  final downloadDate = XmlElement(XmlName('date'));
  downloadDate.setAttribute('type', 'download');
  downloadDate.innerText = docmeta.filedate ?? '';
  creation.children.add(downloadDate);
  
  // Encoding description
  final encodingdesc = XmlElement(XmlName('encodingDesc'));
  header.children.add(encodingdesc);
  
  final appinfo = XmlElement(XmlName('appInfo'));
  encodingdesc.children.add(appinfo);
  
  final application = XmlElement(XmlName('application'));
  application.setAttribute('version', pkgVersion);
  application.setAttribute('ident', 'Trafilatura');
  appinfo.children.add(application);
  
  final label = XmlElement(XmlName('label'));
  label.innerText = 'Trafilatura';
  application.children.add(label);
  
  final appPtr = XmlElement(XmlName('ptr'));
  appPtr.setAttribute('target', 'https://github.com/adbar/trafilatura');
  application.children.add(appPtr);
}
