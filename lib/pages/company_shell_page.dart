import 'package:flutter/material.dart';

class CompanyShellPage extends StatelessWidget {
  const CompanyShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Company Dashboard'), centerTitle: true),
      body: const Center(
        child: Text(
          'Company home (placeholder)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
