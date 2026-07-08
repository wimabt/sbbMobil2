import 'package:flutter/material.dart';

/// Achievement model for profile screen.
///
/// Backend'den gelen rozet verisini UI için sadeleştirir.
class Achievement {
  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.unlocked,
    required this.icon,
  });

  final int id;
  final String name;
  final String description;
  final bool unlocked;
  final IconData icon;
}

