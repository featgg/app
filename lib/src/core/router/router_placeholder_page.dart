import 'package:flutter/material.dart';

/// Temporary root screen rendered by the stub '/' route until the real root
/// screen is built in the next vertical-slice issue. It carries no feature
/// dependency so that the router configuration can live in core/ without
/// violating the layering rule.
class RouterPlaceholderPage extends StatelessWidget {
  const RouterPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Feat.gg')));
  }
}
