import 'package:flutter/material.dart';
import 'package:reqviora_frontend/shared/layouts/responsive_page_shell.dart';
import 'package:reqviora_frontend/shared/theme/reqviora_tokens.dart';

import '../widgets/create_project_fields.dart';
import '../widgets/create_project_story_preview.dart';

/// Presentation-only input values.
///
/// This is not a Backend DTO or Project domain model.
/// Developer B will map these strings to a verified API contract.
class CreateProjectFormValue {
  const CreateProjectFormValue({
    required this.name,
    required this.description,
    required this.primaryPlatform,
    required this.targetAudience,
    required this.projectType,
    required this.industry,
    required this.technologyPreferences,
    required this.constraints,
    required this.integrations,
  });

  final String name;
  final String description;
  final String primaryPlatform;
  final String targetAudience;
  final String projectType;
  final String industry;
  final String technologyPreferences;
  final String constraints;
  final String integrations;
}

/// An external caller must explicitly confirm successful creation.
///
/// A callback invocation alone is not proof that a project was created.
class CreateProjectSubmissionResult {
  const CreateProjectSubmissionResult.success({this.message})
      : succeeded = true;

  const CreateProjectSubmissionResult.failure({this.message})
      : succeeded = false;

  final bool succeeded;
  final String? message;
}

typedef CreateProjectSubmitCallback = Future<CreateProjectSubmissionResult>
    Function(CreateProjectFormValue values);

/// REQVIORA Living Editorial Studio — form-first adaptive presentation.
///
/// Presentation and local form state only.
/// No navigation, API calls, providers or persistence.
class CreateProjectStudioPage extends StatefulWidget {
  const CreateProjectStudioPage({
    super.key,
    this.onSubmit,
  });

  final CreateProjectSubmitCallback? onSubmit;

  @override
  State<CreateProjectStudioPage> createState() =>
      _CreateProjectStudioPageState();
}

class _CreateProjectStudioPageState extends State<CreateProjectStudioPage> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _description = TextEditingController();
  final _targetAudience = TextEditingController();
  final _projectType = TextEditingController();
  final _industry = TextEditingController();
  final _technologyPreferences = TextEditingController();
  final _constraints = TextEditingController();
  final _integrations = TextEditingController();

  String _primaryPlatform = 'web';

  bool _submitting = false;
  bool _confirmed = false;
  String? _errorMessage;
  String? _successMessage;

  bool get _fieldsEnabled => !_submitting && !_confirmed;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _targetAudience.dispose();
    _projectType.dispose();
    _industry.dispose();
    _technologyPreferences.dispose();
    _constraints.dispose();
    _integrations.dispose();
    super.dispose();
  }

  CreateProjectFormValue _readValues() {
    return CreateProjectFormValue(
      name: _name.text.trim(),
      description: _description.text.trim(),
      primaryPlatform: _primaryPlatform,
      targetAudience: _targetAudience.text.trim(),
      projectType: _projectType.text.trim(),
      industry: _industry.text.trim(),
      technologyPreferences: _technologyPreferences.text.trim(),
      constraints: _constraints.text.trim(),
      integrations: _integrations.text.trim(),
    );
  }

  Future<void> _submit() async {
    if (_submitting || _confirmed || widget.onSubmit == null) {
      return;
    }

    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _submitting = true);

    try {
      final result = await widget.onSubmit!(_readValues());

      if (!mounted) {
        return;
      }

      setState(() {
        if (result.succeeded) {
          _confirmed = true;
          _successMessage =
              result.message ?? 'Your project has been created successfully.';
        } else {
          _errorMessage = result.message ??
              'Your project could not be created. Please try again.';
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            'We could not confirm project creation. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= ReqvioraTokens.desktopBreakpoint;
    final mobile = width < ReqvioraTokens.mobileBreakpoint;

    // The document preview listens to text editing locally; no network calls.
    // The existing form callback and submission state remain untouched.
    final liveStory = AnimatedBuilder(
      animation: Listenable.merge([_name, _description]),
      builder: (context, _) => CreateProjectStoryPreview(
        projectName: _name.text.trim(),
        projectDescription: _description.text.trim(),
        primaryPlatform: _primaryPlatform,
      ),
    );

    return Scaffold(
      key: const Key('create-project-studio-page'),
      backgroundColor: scheme.surface,
      body: ResponsivePageShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            SizedBox(height: mobile ? 16 : 22),
            _introduction(context, mobile),
            SizedBox(height: mobile ? 20 : 26),
            _workspaceHeading(context, mobile),
            const SizedBox(height: 18),
            if (desktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: _formContent(context)),
                  const SizedBox(width: 26),
                  Expanded(flex: 4, child: liveStory),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _formContent(context),
                  const SizedBox(height: 28),
                  liveStory,
                ],
              ),
            const SizedBox(height: 44),
            Divider(color: scheme.outlineVariant),
            const SizedBox(height: 18),
            Text(
              'REQVIORA  /  CREATIVE PROJECT WORKSPACE',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.3,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 560;

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scheme.primary,
                scheme.tertiary,
              ],
            ),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            Icons.auto_awesome_rounded,
            size: 19,
            color: scheme.onPrimary,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            'REQVIORA',
            style: TextStyle(
              fontSize: compact ? 17 : 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: scheme.onSurface,
            ),
          ),
        ),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              compact ? 'STUDIO' : 'PROJECT STUDIO',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _introduction(BuildContext context, bool mobile) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.all(mobile ? 18 : 25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.44),
            scheme.surfaceContainerLow,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.dashboard_customize_outlined,
                size: 17,
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'YOUR CREATIVE WORKSPACE',
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Create a new project',
            style: textTheme.headlineMedium?.copyWith(
              fontSize: mobile ? 25 : 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.9,
              height: 1.15,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 9),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 610),
            child: Text(
              'Define your idea, choose a platform, and explore '
              'a live visual preview as you work.',
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workspaceHeading(BuildContext context, bool mobile) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(
          Icons.tune_rounded,
          color: scheme.primary,
          size: 19,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            'Project setup',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
          ),
        ),
        if (!mobile)
          Text(
            'LIVE CREATIVE WORKSPACE',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.6,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  Widget _formContent(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _section(
            context,
            number: '01',
            title: 'Project essentials',
            subtitle: 'Three essentials to start your workspace.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CreateProjectTextField(
                  fieldKey: const Key('create-name'),
                  controller: _name,
                  label: 'Project Name',
                  maxLength: 200,
                  requiredField: true,
                  minLength: 2,
                  hint: 'Give your idea a meaningful name',
                  enabled: _fieldsEnabled,
                ),
                const SizedBox(height: 18),
                CreateProjectTextField(
                  fieldKey: const Key('create-description'),
                  controller: _description,
                  label: 'Describe Your Idea',
                  maxLength: 4000,
                  multiline: true,
                  hint: 'What would you like to create?',
                  enabled: _fieldsEnabled,
                ),
                const SizedBox(height: 20),
                CreateProjectPlatformSelector(
                  value: _primaryPlatform,
                  enabled: _fieldsEnabled,
                  onChanged: (value) {
                    setState(() => _primaryPlatform = value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _optionalSection(
            context,
            sectionKey: 'create-basic-section',
            title: 'More project details',
            subtitle: 'Audience, project type and industry.',
            children: [
              CreateProjectTextField(
                fieldKey: const Key('create-targetAudience'),
                controller: _targetAudience,
                label: 'Target Audience',
                maxLength: 500,
                multiline: true,
                enabled: _fieldsEnabled,
              ),
              const SizedBox(height: 16),
              CreateProjectTextField(
                fieldKey: const Key('create-projectType'),
                controller: _projectType,
                label: 'Project Type',
                maxLength: 120,
                hint: 'Describe the kind of product',
                enabled: _fieldsEnabled,
              ),
              const SizedBox(height: 16),
              CreateProjectTextField(
                fieldKey: const Key('create-industry'),
                controller: _industry,
                label: 'Industry',
                maxLength: 120,
                hint: 'Any industry or domain',
                enabled: _fieldsEnabled,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _optionalSection(
            context,
            sectionKey: 'create-advanced-section',
            title: 'Advanced preferences',
            subtitle: 'Only if you already know these details.',
            children: [
              CreateProjectTextField(
                fieldKey: const Key('create-technologyPreferences'),
                controller: _technologyPreferences,
                label: 'Technology Preferences',
                maxLength: 2000,
                multiline: true,
                enabled: _fieldsEnabled,
              ),
              const SizedBox(height: 16),
              CreateProjectTextField(
                fieldKey: const Key('create-constraints'),
                controller: _constraints,
                label: 'Constraints',
                maxLength: 4000,
                multiline: true,
                enabled: _fieldsEnabled,
              ),
              const SizedBox(height: 16),
              CreateProjectTextField(
                fieldKey: const Key('create-integrations'),
                controller: _integrations,
                label: 'Integrations',
                maxLength: 4000,
                multiline: true,
                enabled: _fieldsEnabled,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_errorMessage != null) ...[
            _feedback(
              context,
              keyName: 'create-submit-error',
              message: _errorMessage!,
              isError: true,
            ),
            const SizedBox(height: 16),
          ],
          if (_confirmed && _successMessage != null) ...[
            _feedback(
              context,
              keyName: 'create-submit-success',
              message: _successMessage!,
              isError: false,
            ),
            const SizedBox(height: 16),
          ],
          FilledButton.icon(
            key: const Key('create-submit'),
            onPressed:
                _fieldsEnabled && widget.onSubmit != null ? _submit : null,
            icon: _submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward),
            label: Text(
              _submitting
                  ? 'Creating Project...'
                  : _confirmed
                      ? 'Project Created'
                      : 'Create Project',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              minimumSize: const Size(190, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          if (widget.onSubmit == null) ...[
            const SizedBox(height: 10),
            Text(
              'Project creation will be available once a creation '
              'handler is connected.',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String number,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number / PROJECT SETUP',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 23),
          child,
        ],
      ),
    );
  }

  Widget _optionalSection(
    BuildContext context, {
    required String sectionKey,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          key: Key(sectionKey),
          initiallyExpanded: false,
          maintainState: true,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 9,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
          title: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          subtitle: Text(
            '$subtitle Optional.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          children: children,
        ),
      ),
    );
  }

  Widget _feedback(
    BuildContext context, {
    required String keyName,
    required String message,
    required bool isError,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      liveRegion: true,
      child: Container(
        key: Key(keyName),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isError ? scheme.errorContainer : scheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color:
                  isError ? scheme.onErrorContainer : scheme.onPrimaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isError
                      ? scheme.onErrorContainer
                      : scheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
