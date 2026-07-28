import 'package:flutter/material.dart';


import '../widgets/shared_widgets.dart';

class DocumentViewerScreen extends StatelessWidget {
  const DocumentViewerScreen({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: SectionCard(
          child: Text(body, style: const TextStyle(fontSize: 14.5, height: 1.6)),
        ),
      ),
    );
  }
}
