import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marriage_connect/src/features/shell/shell_routes.dart';

/// DEPRECATED shim. The Home list of links is replaced by the app shell
/// (`features/shell`: bottom tabs Discover / Interests / Matches / Profile).
/// Until the router mounts `shellRoutes()` this just forwards to the first
/// tab; delete this file together with the `/home` route when it does.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(shellHomePath);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}
