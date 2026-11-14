import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';

/// The shared page shell for every authenticated screen.
///
/// It owns three navigation rules that were previously scattered across the
/// app:
///
/// * top-level screens show the portal menu;
/// * every pushed or module screen shows a visible, localized back arrow;
/// * the Android back gesture never leaves a dirty form without confirmation.
///
/// Screens that are not the home dashboard should leave [isRoot] false. A
/// screen reached by a deep link still shows Back: when there is no route to
/// pop it returns to the dashboard instead of closing the app.
class AppScaffold extends StatefulWidget {
  const AppScaffold({
    required this.title,
    required this.body,
    this.actions = const [],
    this.drawer,
    this.floatingActionButton,
    this.isRoot = false,
    this.hasUnsavedChanges = false,
    this.showBack,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset,
    super.key,
  });

  final Widget title;
  final Widget body;
  final List<Widget> actions;
  final Widget? drawer;
  final Widget? floatingActionButton;
  final bool isRoot;
  final bool hasUnsavedChanges;
  final bool? showBack;
  final Widget? bottomNavigationBar;
  final bool? resizeToAvoidBottomInset;

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  DateTime? _lastBackPress;

  bool get _showBack => widget.showBack ?? !widget.isRoot;
  bool get _canPop => context.canPop();

  Future<bool> _confirmDiscard() async {
    final strings = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.discardChangesTitle),
        content: Text(strings.discardChangesMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.keepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.discard),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _leavePage() async {
    if (_canPop) {
      context.pop();
      return;
    }
    context.go('/');
  }

  Future<void> _onBackPressed() async {
    if (widget.hasUnsavedChanges && !await _confirmDiscard()) return;
    if (!mounted) return;
    await _leavePage();
  }

  Future<void> _onRootBack() async {
    final scaffold = _scaffoldKey.currentState;
    if (scaffold?.isDrawerOpen == true) {
      scaffold!.closeDrawer();
      return;
    }
    if (scaffold?.isEndDrawerOpen == true) {
      scaffold!.closeEndDrawer();
      return;
    }
    final now = DateTime.now();
    if (_lastBackPress != null &&
        now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
      await SystemNavigator.pop();
      return;
    }
    _lastBackPress = now;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).pressBackAgainToExit),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final leading = !_showBack
        ? (widget.drawer == null
              ? null
              : IconButton(
                  tooltip: strings.menu,
                  icon: const Icon(Icons.menu),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ))
        : IconButton(
            tooltip: strings.back,
            icon: const Icon(Icons.arrow_back),
            onPressed: _onBackPressed,
          );

    final appBarActions = <Widget>[
      if (_showBack && widget.drawer != null)
        IconButton(
          tooltip: strings.menu,
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ...widget.actions,
    ];

    final blockPop = widget.hasUnsavedChanges || widget.isRoot || !_canPop;

    return PopScope(
      canPop: !blockPop,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (widget.hasUnsavedChanges) {
          await _onBackPressed();
        } else if (widget.isRoot) {
          await _onRootBack();
        } else {
          await _leavePage();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: widget.drawer,
        appBar: AppBar(
          leading: leading,
          title: widget.title,
          actions: appBarActions,
        ),
        body: widget.body,
        floatingActionButton: widget.floatingActionButton,
        bottomNavigationBar: widget.bottomNavigationBar,
        resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      ),
    );
  }
}
