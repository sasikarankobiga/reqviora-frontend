
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/app_theme.dart';

class CreateProjectPage extends StatefulWidget {
  const CreateProjectPage({super.key});

  @override
  State<CreateProjectPage> createState() =>
      _CreateProjectPageState();
}

class _CreateProjectPageState extends State<CreateProjectPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _audienceController = TextEditingController();

  String? _projectType;

  static const _projectTypes = [
    'Web Application',
    'Mobile Application',
    'Desktop Application',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _audienceController.dispose();
    super.dispose();
  }

  void _validateProject() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Project details validated. '
          'Backend saving will be connected next.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Create Project'),
        leading: IconButton(
          tooltip: 'Back to Dashboard',
          onPressed: () => context.go('/dashboard'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.create_new_folder_outlined,
                          size: 48,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Start a New Project',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Describe your software idea '
                          'to begin the REQVIORA journey.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),

                        TextFormField(
                          key: const Key('project_name'),
                          controller: _nameController,
                          maxLength: 120,
                          decoration: const InputDecoration(
                            labelText: 'Project Name',
                            prefixIcon: Icon(Icons.folder_outlined),
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.trim().length < 3) {
                              return 'Enter at least 3 characters';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        TextFormField(
                          key: const Key('project_description'),
                          controller: _descriptionController,
                          maxLines: 4,
                          maxLength: 1000,
                          decoration: const InputDecoration(
                            labelText: 'Project Description',
                            alignLabelWithHint: true,
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.trim().length < 10) {
                              return 'Enter at least 10 characters';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        DropdownButtonFormField<String>(
                          key: const Key('project_type'),
                          initialValue: _projectType,
                          decoration: const InputDecoration(
                            labelText: 'Project Type',
                            prefixIcon: Icon(Icons.apps_outlined),
                          ),
                          items: _projectTypes
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _projectType = value;
                            });
                          },
                          validator: (value) =>
                              value == null
                                  ? 'Select a project type'
                                  : null,
                        ),

                        const SizedBox(height: 20),

                        TextFormField(
                          key: const Key('target_audience'),
                          controller: _audienceController,
                          maxLength: 200,
                          decoration: const InputDecoration(
                            labelText: 'Target Audience',
                            prefixIcon: Icon(Icons.groups_outlined),
                            hintText: 'e.g., Students and teachers',
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Target audience is required';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        FilledButton.icon(
                          key: const Key('create_project_button'),
                          onPressed: _validateProject,
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Continue'),
                        ),

                        const SizedBox(height: 12),

                        TextButton(
                          onPressed: () => context.go('/dashboard'),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
