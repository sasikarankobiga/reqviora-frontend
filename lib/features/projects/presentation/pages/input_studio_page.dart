import 'package:flutter/material.dart';

class InputStudioPage extends StatelessWidget {
  const InputStudioPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Studio'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 64,
            ),
            SizedBox(height: 20),
            Text(
              'Input Studio',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 15),
            Text(
              'Document, Voice, Text and Manual Input',
            ),
          ],
        ),
      ),
    );
  }
}
