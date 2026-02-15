#!/usr/bin/env dart
/// Command-line interface for Trafilatura.
///
/// Run with: dart run trafilatura [options]

import 'package:trafilatura/src/cli.dart' as cli;

Future<void> main(List<String> arguments) async {
  await cli.main(arguments);
}
