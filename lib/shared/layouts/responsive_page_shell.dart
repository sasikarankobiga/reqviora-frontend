import 'package:flutter/material.dart';

import '../theme/reqviora_tokens.dart';

/// A reusable, responsive content container.
///
/// This widget does not own navigation, app bootstrap,
/// Riverpod providers, or backend state.
class ResponsivePageShell extends StatelessWidget {
  const ResponsivePageShell({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final horizontalPadding =
            ReqvioraTokens.horizontalPaddingFor(width);
        final verticalPadding =
            ReqvioraTokens.verticalPaddingFor(width);

        return SafeArea(
          child: SingleChildScrollView(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                key: const Key('reqviora-shell-content'),
                constraints: const BoxConstraints(
                  maxWidth: ReqvioraTokens.maxContentWidth,
                ),
                child: Padding(
                  key: const Key('reqviora-shell-padding'),
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}