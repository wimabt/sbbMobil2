import 'package:flutter/material.dart';

/// Menu item model for profile screen
class MenuItem {
  const MenuItem({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;
}

