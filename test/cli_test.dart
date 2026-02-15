/// Tests for CLI functionality.
import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('CLI Invocation', () {
    test('shows help message', () async {
      final result = await Process.run('dart', ['run', 'bin/trafilatura.dart', '--help']);
      expect(result.stdout.toString(), contains('Trafilatura'));
      expect(result.stdout.toString(), contains('--URL'));
    });

    test('shows version when requested', () async {
      final result = await Process.run('dart', ['run', 'bin/trafilatura.dart', '--version']);
      expect(result.exitCode, equals(0));
    });
  });

  group('CLI Options', () {
    test('accepts output format option', () async {
      final result = await Process.run('dart', ['run', 'bin/trafilatura.dart', '--help']);
      expect(result.stdout.toString(), contains('--output-format'));
    });

    test('accepts parallel option', () async {
      final result = await Process.run('dart', ['run', 'bin/trafilatura.dart', '--help']);
      expect(result.stdout.toString(), contains('--parallel'));
    });

    test('accepts formatting options', () async {
      final result = await Process.run('dart', ['run', 'bin/trafilatura.dart', '--help']);
      expect(result.stdout.toString(), contains('--formatting'));
      expect(result.stdout.toString(), contains('--links'));
      expect(result.stdout.toString(), contains('--images'));
    });
  });

  group('CLI Input Methods', () {
    test('accepts URL input option', () async {
      final result = await Process.run('dart', ['run', 'bin/trafilatura.dart', '--help']);
      expect(result.stdout.toString(), contains('--URL'));
    });

    test('accepts file input option', () async {
      final result = await Process.run('dart', ['run', 'bin/trafilatura.dart', '--help']);
      expect(result.stdout.toString(), contains('--input-file'));
    });

    test('accepts directory input option', () async {
      final result = await Process.run('dart', ['run', 'bin/trafilatura.dart', '--help']);
      expect(result.stdout.toString(), contains('--input-dir'));
    });
  });

  group('CLI Discovery Features', () {
    test('supports feed discovery', () async {
      final result = await Process.run('dart', ['run', 'bin/trafilatura.dart', '--help']);
      expect(result.stdout.toString(), contains('--feed'));
    });

    test('supports sitemap discovery', () async {
      final result = await Process.run('dart', ['run', 'bin/trafilatura.dart', '--help']);
      expect(result.stdout.toString(), contains('--sitemap'));
    });

    test('supports crawling', () async {
      final result = await Process.run('dart', ['run', 'bin/trafilatura.dart', '--help']);
      expect(result.stdout.toString(), contains('--crawl'));
    });
  });
}

