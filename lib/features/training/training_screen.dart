import 'package:flutter/material.dart';
import '../../shared/widgets/coming_soon_placeholder.dart';

class TrainingScreen extends StatelessWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Training'),
      ),
      body: const ComingSoonPlaceholder(),
    );
  }
}
