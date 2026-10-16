import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/core/theme/app_theme.dart';

/// Content frame for modal bottom sheets: drag handle, title row with a
/// 48 dp close button, scrollable [child], optional pinned [actions].
/// Keyboard-aware (pads by the IME inset) and safe for 200% text.
///
/// Use [BottomSheetScaffold.show] to present it.
class BottomSheetScaffold extends StatelessWidget {
  const BottomSheetScaffold({
    required this.title,
    required this.child,
    this.actions,
    super.key,
  });

  final String title;
  final Widget child;

  /// Pinned below the scrolling body (typically McButtons).
  final List<Widget>? actions;

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required Widget child,
    List<Widget>? actions,
  }) =>
      showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: false,
        backgroundColor: context.mc.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(context.mc.radii.lg),
          ),
        ),
        builder: (_) => BottomSheetScaffold(
          title: title,
          actions: actions,
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    final l = AppLocalizations.of(context);
    return Material(
      color: mc.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(mc.radii.lg)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Semantics(
          scopesRoute: true,
          explicitChildNodes: true,
          namesRoute: true,
          label: title,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExcludeSemantics(
                child: Center(
                  child: Container(
                    margin: EdgeInsets.only(top: mc.space.xs),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: mc.colors.outline,
                      borderRadius: BorderRadius.circular(mc.radii.pill),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: mc.space.md,
                  top: mc.space.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(title, style: mc.text.title),
                      ),
                    ),
                    IconButton(
                      tooltip: l.kitCloseSheet,
                      constraints: BoxConstraints.tightFor(
                        width: mc.space.minTarget,
                        height: mc.space.minTarget,
                      ),
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: mc.space.md,
                    vertical: mc.space.xs,
                  ),
                  child: child,
                ),
              ),
              if (actions != null && actions!.isNotEmpty)
                Padding(
                  padding: EdgeInsets.all(mc.space.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < actions!.length; i++) ...[
                        if (i > 0) SizedBox(height: mc.space.xs),
                        actions![i],
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
