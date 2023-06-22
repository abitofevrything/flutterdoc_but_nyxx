import 'dart:async';
import 'dart:convert';

import 'package:fuzzy/fuzzy.dart';
import 'package:http/http.dart' as http;

import 'package:flutterdoc_but_nyxx/packages/flutter_docs.dart';
import 'package:flutterdoc_but_nyxx/packages/package_docs.dart';

final Map<String, Future<PackageDocs>> _docsCache = _initDocs();
final Map<String, List<String>> _packageCache = {};

Map<String, Future<PackageDocs>> _initDocs() {
  Timer.periodic(Duration(days: 1), (timer) async {
    for (final package in _docsCache.values) {
      (await package).update();
    }
  });

  return {
    'flutter': _initFlutter(),
  };
}

Future<FlutterDocs> _initFlutter() async {
  final docs = FlutterDocs();
  await docs.update();
  return docs;
}

Future<List<DocEntry>> searchDocs(String package, String query) async {
  final docs = await (_docsCache[package] ??= PackageDocs.fromPackage(package));

  final results = Fuzzy<DocEntry>(
    docs.elements.toList(),
    options: FuzzyOptions(
      isCaseSensitive: false,
      threshold: 0.05,
      keys: [
        WeightedKey(
          name: 'qualifiedName',
          getter: (entry) => entry.qualifiedName,
          weight: 1,
        ),
        WeightedKey(
          name: 'name',
          getter: (entry) => entry.name,
          weight: 2,
        ),
        WeightedKey(
          name: 'displayName',
          getter: (entry) => entry.displayName,
          weight: 3,
        ),
      ],
      // We perform our own sort later
      shouldSort: false,
    ),
  ).search(query);

  results.sort((a, b) {
    num getWeight(DocEntry entry) {
      if (entry.type == 'method' &&
          (entry.name.startsWith('operator ') || entry.name == 'hashCode')) {
        // We don't want operators or hashCodes polluting our results
        return 10;
      }

      final priorities = [
        'library',
        'class',
        'top-level constant',
        'top-level property',
        'function',
        'constant',
        'property',
        'method',
      ];

      if (priorities.contains(entry.type)) {
        // Offset by 1 so we don't get a weight of 0, which would be a perfect score
        return priorities.indexOf(entry.type) + 1;
      }

      return priorities.length + 1;
    }

    final aWeight = getWeight(a.item);
    final bWeight = getWeight(b.item);

    int result;
    if (a.score == 0 && b.score == 0) {
      result = aWeight.compareTo(bWeight);
    } else {
      result = (a.score * aWeight).compareTo(b.score * bWeight);
    }

    if (result == 0) {
      result = a.item.packageName.compareTo(b.item.packageName);
    }

    if (result == 0) {
      // If both elements still have the same score, sort alphabetically on their display name
      result = a.item.displayName.compareTo(b.item.displayName);
    }

    return result;
  });

  return results.map((result) => result.item).toList();
}

Future<List<String>> searchPackages(String query) async {
  Future<List<String>> doSearch() async {
    final url = Uri.https('pub.dev', '/api/search', {'q': query});
    final response = await http.get(url);

    final body = jsonDecode(response.body);

    return (body['packages'] as List).map((e) => e['package'] as String).toList();
  }

  return _packageCache[query] ??= await doSearch();
}
