import 'package:flutter/material.dart';

import '../../../../app/router/route_paths.dart';
import '../../domain/models/project_requests.dart';

class CreateProjectPage extends StatefulWidget {
  const CreateProjectPage({super.key});

  @override
  State<CreateProjectPage> createState() => _CreateProjectPageState();
}

class _CreateProjectPageState extends State<CreateProjectPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    try {
      ProjectFieldValidation.validateName(value ?? '');
      return null;
    } on ProjectValidationException catch (error) {
      return error.message;
    }
  }

  String? _validateDescription(String? value) {
    try {
      ProjectFieldValidation.validateDescription(value ?? '');
      return null;
    } on ProjectValidationException catch (error) {
      return error.message;
    }
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final request = CreateProjectRequest(
      name: _nameController.text,
      description: _descriptionController.text,
    );

    Navigator.pushNamed(
      context,
      RoutePaths.projectOverview,
      arguments: request,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Project'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Create a New Project',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    key: const Key('project-name'),
                    controller: _nameController,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'Project Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateName,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    key: const Key('project-description'),
                    controller: _descriptionController,
                    maxLength: 4000,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Project Description',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateDescription,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('continue-project'),
                    onPressed: _continue,
                    child: const Text('Continue to Overview'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
