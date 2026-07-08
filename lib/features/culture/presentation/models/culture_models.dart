import 'package:flutter/material.dart';

class CultureCategory {
  const CultureCategory({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

class UpcomingEvent {
  const UpcomingEvent({
    required this.title,
    required this.date,
    required this.time,
    required this.location,
    required this.type,
  });

  final String title;
  final String date;
  final String time;
  final String location;
  final String type;
}

class CulturalPlace {
  const CulturalPlace({
    required this.id,
    required this.imageAsset,
    required this.title,
    required this.description,
    required this.categoryKey,
    required this.categoryLabel,
    required this.rating,
    required this.distance,
    required this.visitors,
    required this.isFree,
    this.openHours,
    this.date,
    this.ticketPrice,
  });

  final String id;
  final String imageAsset;
  final String title;
  final String description;
  final String categoryKey;
  final String categoryLabel;
  final double rating;
  final String distance;
  final String visitors;
  final bool isFree;
  final String? openHours;
  final String? date;
  final String? ticketPrice;
}

