import 'package:flutter/material.dart';

class BrandShellPage extends StatelessWidget {
  const BrandShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'Brand',
      child: Scaffold(
      appBar: AppBar(title: const Text('Company Dashboard'), centerTitle: true),
      body: const Center(
        child: Text(
          'Company home (placeholder)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      ),
    );
  }
}
