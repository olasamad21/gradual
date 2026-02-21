import 'package:flutter/material.dart';

class GradualScaffold extends StatelessWidget {
  const GradualScaffold({
    super.key,
    this.title,
    required this.body,
    this.actions,
  });

  final String? title;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title == null ? null : AppBar(title: Text(title!), actions: actions),
      body: SafeArea(child: body),
    );
  }
}

