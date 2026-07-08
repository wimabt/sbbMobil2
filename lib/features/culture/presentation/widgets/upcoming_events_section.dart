import 'package:flutter/material.dart';
import '../../../../core/design/design_tokens.dart';
import '../models/culture_models.dart';

class UpcomingEventsSection extends StatelessWidget {
  const UpcomingEventsSection({
    super.key,
    required this.events,
  });

  final List<UpcomingEvent> events;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        children: [
          _buildHeader(context, isDark),
          _buildEventsList(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Yaklaşan Etkinlikler',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : null,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList(BuildContext context) {
    return SizedBox(
      height: 130,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final event = events[index];
          return _EventCard(event: event);
        },
        separatorBuilder: (context, _) => const SizedBox(width: 8),
        itemCount: events.length,
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final UpcomingEvent event;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: 260,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isDark
            ? LinearGradient(
                colors: [
                  AppColors.neonPurple.withAlpha(180),
                  AppColors.neonPurple.withAlpha(100),
                ],
              )
            : LinearGradient(
                colors: [Colors.teal.shade500, Colors.teal.shade300],
              ),
        border: isDark
            ? Border.all(color: AppColors.neonPurple.withAlpha(60))
            : null,
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: AppColors.neonPurple.withAlpha(30),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIcon(isDark),
          const SizedBox(width: 10),
          Expanded(child: _buildContent(context)),
        ],
      ),
    );
  }

  Widget _buildIcon(bool isDark) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(isDark ? 40 : 51),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.calendar_today, color: Colors.white),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          event.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              event.date,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(width: 6),
            const Text('•', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(width: 6),
            Text(
              event.time,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.place, size: 14, color: Colors.white70),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                event.location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

