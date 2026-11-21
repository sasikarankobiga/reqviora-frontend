import 'package:flutter/material.dart';

import '../../../projects/domain/models/project_draft.dart';
import '../../../projects/domain/models/project_requests.dart';
import '../../domain/models/wizard_flow.dart';
import '../widgets/wizard_progress_header.dart';
import '../../../../app/router/route_paths.dart';

class BuilderStep1Page extends StatefulWidget {
  const BuilderStep1Page({
    super.key,
    required this.projectDraft,
    required this.flow,
  });

  final ProjectDraft projectDraft;
  final WizardFlow flow;

  @override
  State<BuilderStep1Page> createState() => _BuilderStep1PageState();
}

class _BuilderStep1PageState extends State<BuilderStep1Page> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.projectDraft.name,
    );

    _descriptionController = TextEditingController(
      text: widget.projectDraft.description,
    );
  }

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

  void _saveStep() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    widget.projectDraft.update(
      name: _nameController.text,
      description: _descriptionController.text,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Step 1 details saved in draft'),
      ),
    );
  }

  void _nextStep() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    widget.projectDraft.update(
      name: _nameController.text,
      description: _descriptionController.text,
    );

    widget.flow.completeStep(1);

    Navigator.pushNamed(
      context,
      RoutePaths.builderWorkflow,
      arguments: WizardStepRouteData(
        flow: widget.flow,
        step: 2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Builder - Step 1'),
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
                  WizardProgressHeader(
                    flow: widget.flow,
                    currentStep: 1,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Step 1 - Identity & Audience',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Project details are prefilled from '
                    'Create Project.',
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    key: const Key('builder-project-name'),
                    controller: _nameController,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'Project Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateName,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    key: const Key('builder-project-description'),
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
                    key: const Key('builder-save-step1'),
                    onPressed: _saveStep,
                    child: const Text('Save Step 1 Draft'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('builder-next-step1'),
                    onPressed: _nextStep,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next: Features & Screens'),
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
