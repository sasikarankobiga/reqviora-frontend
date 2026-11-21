
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/app_theme.dart';
import '../providers/project_provider.dart';

class CreateProjectPage extends ConsumerStatefulWidget {
  const CreateProjectPage({super.key});

  @override
  ConsumerState<CreateProjectPage> createState() =>
      _CreateProjectPageState();
}

class _CreateProjectPageState
    extends ConsumerState<CreateProjectPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _audienceController = TextEditingController();

  String? _projectType;
  bool _isSubmitting = false;

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

  Future<void> _createProject() async {
    // Step 1: Validate all form fields.
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Step 2: Prevent duplicate requests.
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Step 3: Create project through Riverpod provider.
      // The provider checks authentication and JWT expiry.
      final project = await ref
          .read(projectActionsProvider)
          .createProject(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            projectType: _projectType!,
            targetAudience: _audienceController.text.trim(),
          );

      if (!mounted) return;

      // Step 4: Show success only after API confirms creation.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Project created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Step 5: Open the newly created project.
      context.go(
        '/projects/${Uri.encodeComponent(project.id)}',
      );
    } on DioException catch (error) {
      if (!mounted) return;

      String message = 'Unable to create project.';

      switch (error.response?.statusCode) {
        case 400:
          message = 'Please check your project details.';
          break;
        case 401:
          message = 'Session expired. Please sign in again.';
          break;
        case 403:
          message = 'You do not have permission to create projects.';
          break;
        case 409:
          message = 'A project conflict occurred. Please try again.';
          break;
        case 429:
          message = 'Too many requests. Please try later.';
          break;
        default:
          if (error.response == null) {
            message =
                'Cannot connect to backend. Check if the API is running.';
          } else {
            message = 'Project creation failed. Please try again.';
          }
      }

      _showError(message);
    } on StateError catch (error) {
      if (!mounted) return;

      // Handles missing or expired authentication sessions.
      _showError(error.message);
    } catch (error) {
      if (!mounted) return;

      _showError(
        'An unexpected error occurred. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
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
          onPressed: _isSubmitting
              ? null
              : () => context.go('/dashboard'),
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

                        // Project Name
                        TextFormField(
                          key: const Key('project_name'),
                          controller: _nameController,
                          enabled: !_isSubmitting,
                          maxLength: 120,
                          decoration: const InputDecoration(
                            labelText: 'Project Name',
                            prefixIcon:
                                Icon(Icons.folder_outlined),
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

                        // Project Description
                        TextFormField(
                          key: const Key('project_description'),
                          controller: _descriptionController,
                          enabled: !_isSubmitting,
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

                        // Project Type
                        DropdownButtonFormField<String>(
                          key: const Key('project_type'),
                          initialValue: _projectType,
                          decoration: const InputDecoration(
                            labelText: 'Project Type',
                            prefixIcon:
                                Icon(Icons.apps_outlined),
                          ),
                          items: _projectTypes
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                ),
                              )
                              .toList(),
                          onChanged: _isSubmitting
                              ? null
                              : (value) {
                                  setState(() {
                                    _projectType = value;
                                  });
                                },
                          validator: (value) => value == null
                              ? 'Select a project type'
                              : null,
                        ),

                        const SizedBox(height: 20),

                        // Target Audience
                        TextFormField(
                          key: const Key('target_audience'),
                          controller: _audienceController,
                          enabled: !_isSubmitting,
                          maxLength: 200,
                          decoration: const InputDecoration(
                            labelText: 'Target Audience',
                            prefixIcon:
                                Icon(Icons.groups_outlined),
                            hintText:
                                'e.g., Students and teachers',
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

                        // Create Project API Button
                        FilledButton.icon(
                          key: const Key('create_project_button'),
                          onPressed:
                              _isSubmitting ? null : _createProject,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward),
                          label: Text(
                            _isSubmitting
                                ? 'Creating Project...'
                                : 'Continue',
                          ),
                        ),

                        const SizedBox(height: 12),

                        TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => context.go('/dashboard'),
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
