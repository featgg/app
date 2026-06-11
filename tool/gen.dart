// ignore_for_file: avoid_print
// Dependency-free so it launches without package resolution (no .dart_tool/).
//
// Incremental code-gen refresh — the no-clean sibling of setup.dart. Use after
// switching branches or editing a provider/DTO: build_runner re-hashes inputs
// and regenerates only the *.g.dart that changed (seconds). It does not run
// `flutter pub get`; if dependencies changed, run that (or setup.dart) first.
import 'dart:io';

const _usage =
    'Usage: dart run tool/gen.dart\n'
    'Incremental code-gen (no clean, no pub get). Runs: '
    'dart run build_runner build --delete-conflicting-outputs';

typedef _Step = ({String label, String exe, List<String> args});

const _steps = <_Step>[
  (
    label: 'dart run build_runner build --delete-conflicting-outputs',
    exe: 'dart',
    args: ['run', 'build_runner', 'build', '--delete-conflicting-outputs'],
  ),
];

Future<void> main(List<String> arguments) async {
  _handleArgs(arguments);

  for (final step in _steps) {
    await _runStep(step);
  }

  print('\nAll steps completed successfully.');
}

void _handleArgs(List<String> arguments) {
  if (arguments.contains('-h') || arguments.contains('--help')) {
    print(_usage);
    exit(0);
  }
  if (arguments.isNotEmpty) {
    stderr.writeln(_usage);
    exit(2);
  }
}

Future<void> _runStep(_Step step) async {
  print('\n==> ${step.label}');
  final code = await _runProcess(step.exe, step.args);
  if (code != 0) {
    stderr.writeln('\n${step.label} failed (exit $code).');
    exit(code);
  }
}

Future<int> _runProcess(String exe, List<String> args) async {
  try {
    final process = await Process.start(
      exe,
      args,
      mode: ProcessStartMode.inheritStdio,
      runInShell: true,
    );
    return await process.exitCode;
  } on ProcessException catch (e) {
    stderr.writeln('$exe failed: ${e.message}');
    return e.errorCode != 0 ? e.errorCode : 1;
  }
}
