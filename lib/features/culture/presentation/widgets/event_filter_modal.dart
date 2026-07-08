import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../l10n/l10n.dart';
import '../providers/events_provider.dart';

/// Enum for quick date selection options
enum QuickDateOption {
  today,
  tomorrow,
  thisWeekend,
  custom,
}

/// Event Filter Modal - Bottom Sheet for filtering events
/// Includes: Time filters, Price filters, and action buttons
class EventFilterModal extends ConsumerStatefulWidget {
  const EventFilterModal({super.key});

  @override
  ConsumerState<EventFilterModal> createState() => _EventFilterModalState();

  /// Shows the filter modal as a bottom sheet
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Root navigator: aksi halde modal, shell'in iç navigator'ında açılıp
      // ScaffoldShell'in ortadaki harita FAB'ı + alt navigasyon çubuğunun
      // ALTINDA kalıyor ve "Uygula" butonuyla çakışıyordu. Root navigator
      // modalı tüm shell'in üstüne taşır → çakışma biter.
      useRootNavigator: true,
      builder: (context) => const EventFilterModal(),
    );
  }
}

class _EventFilterModalState extends ConsumerState<EventFilterModal> {
  // Local state for the modal (applied on "Uygula" button)
  QuickDateOption? _selectedQuickDate;
  DateTimeRange? _customDateRange;
  late bool _isFreeOnly;
  late EventSortMode _sortMode;

  @override
  void initState() {
    super.initState();
    // Initialize from current provider state
    final state = ref.read(eventsListProvider);
    _isFreeOnly = state.showFreeOnly;
    _customDateRange = state.dateRange;
    _sortMode = state.sortMode;

    // Determine which quick date option matches current state
    _selectedQuickDate = _getQuickDateFromRange(state.dateRange);
  }

  QuickDateOption? _getQuickDateFromRange(DateTimeRange? range) {
    if (range == null) return null;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    
    // Check if it's "Today"
    if (range.start == today && range.end == today) {
      return QuickDateOption.today;
    }
    
    // Check if it's "Tomorrow"
    if (range.start == tomorrow && range.end == tomorrow) {
      return QuickDateOption.tomorrow;
    }
    
    // Check if it's "This Weekend"
    final weekendStart = _getNextWeekendStart(today);
    final weekendEnd = weekendStart.add(const Duration(days: 1));
    if (range.start == weekendStart && range.end == weekendEnd) {
      return QuickDateOption.thisWeekend;
    }
    
    return QuickDateOption.custom;
  }

  DateTime _getNextWeekendStart(DateTime from) {
    // Saturday = 6
    final daysUntilSaturday = (6 - from.weekday) % 7;
    return from.add(Duration(days: daysUntilSaturday == 0 ? 0 : daysUntilSaturday));
  }

  void _onQuickDateSelected(QuickDateOption option) {
    setState(() {
      if (_selectedQuickDate == option) {
        // Toggle off
        _selectedQuickDate = null;
        _customDateRange = null;
      } else {
        _selectedQuickDate = option;
        _customDateRange = _getDateRangeForOption(option);
        
        if (option == QuickDateOption.custom) {
          // Show date range picker
          _showDateRangePicker();
        }
      }
    });
  }

  DateTimeRange? _getDateRangeForOption(QuickDateOption option) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    switch (option) {
      case QuickDateOption.today:
        return DateTimeRange(start: today, end: today);
      case QuickDateOption.tomorrow:
        final tomorrow = today.add(const Duration(days: 1));
        return DateTimeRange(start: tomorrow, end: tomorrow);
      case QuickDateOption.thisWeekend:
        final saturday = _getNextWeekendStart(today);
        final sunday = saturday.add(const Duration(days: 1));
        return DateTimeRange(start: saturday, end: sunday);
      case QuickDateOption.custom:
        return _customDateRange;
    }
  }

  Future<void> _showDateRangePicker() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _customDateRange,
      helpText: context.l10n.filterSelectDateRangeHelp,
      cancelText: context.l10n.btnCancel,
      saveText: context.l10n.btnSave,
      fieldStartHintText: context.l10n.filterStartDateHint,
      fieldEndHintText: context.l10n.filterEndDateHint,
      errorInvalidRangeText: context.l10n.filterInvalidRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppColors.neonCyan,
                    onPrimary: Colors.white,
                    surface: AppColors.darkSurface,
                    onSurface: Colors.white,
                  )
                : ColorScheme.light(
                    primary: Colors.teal.shade600,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black87,
                  ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedQuickDate = QuickDateOption.custom;
      });
    }
  }

  void _onReset() {
    setState(() {
      _selectedQuickDate = null;
      _customDateRange = null;
      _isFreeOnly = false;
      _sortMode = EventSortMode.date;
    });
  }

  void _onApply() {
    final notifier = ref.read(eventsListProvider.notifier);

    // Apply date range
    notifier.setDateRange(_customDateRange);

    // Apply free only filter
    if (_isFreeOnly != ref.read(eventsListProvider).showFreeOnly) {
      notifier.toggleFreeOnly();
    }

    // Apply sort mode
    notifier.setSortMode(_sortMode);

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewPadding = MediaQuery.of(context).viewPadding.bottom;
    // Root navigator ile açıldığından alttaki navbar'ı modal zaten kapatıyor;
    // navbar yüksekliğini ayırmaya gerek yok, güvenli alan + küçük boşluk yeter.
    final bottomPadding = viewPadding + 16;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          _buildDragHandle(isDark),
          
          // Header
          _buildHeader(context, isDark),
          
          const SizedBox(height: 16),
          
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section 0: Sıralama (eski dropdown buradan yönetiliyor)
                _buildSortSection(context, isDark),

                const SizedBox(height: 24),

                // Section 1: Time
                _buildTimeSection(context, isDark),

                const SizedBox(height: 24),

                // Section 2: Price
                _buildPriceSection(context, isDark),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Footer: Action Buttons
          _buildFooter(context, isDark, bottomPadding),
        ],
      ),
    );
  }

  Widget _buildDragHandle(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(50) : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark 
                  ? AppColors.neonCyan.withAlpha(30) 
                  : Colors.teal.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.tune_rounded,
              size: 24,
              color: isDark ? AppColors.neonCyan : Colors.teal.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.filterEventTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.filterSubtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark 
                        ? Colors.white.withAlpha(150) 
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortSection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.swap_vert_rounded,
              size: 20,
              color: isDark ? AppColors.neonCyan : Colors.teal.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              context.l10n.filterSortTitle,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: EventSortMode.values
              .map((m) => _buildSortChip(context, isDark, m))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildSortChip(BuildContext context, bool isDark, EventSortMode mode) {
    final isSelected = _sortMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _sortMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: isDark
                      ? [AppColors.neonCyan, AppColors.neonCyan.withAlpha(180)]
                      : [Colors.teal.shade500, Colors.teal.shade400],
                )
              : null,
          color: isSelected
              ? null
              : (isDark ? Colors.white.withAlpha(10) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? null
              : Border.all(
                  color: isDark
                      ? Colors.white.withAlpha(15)
                      : Colors.grey.shade300,
                ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isDark ? AppColors.neonCyan : Colors.teal)
                        .withAlpha(40),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Text(
          eventSortLabel(context.l10n, mode),
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white.withAlpha(180) : Colors.grey.shade700),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 20,
              color: isDark ? AppColors.neonCyan : Colors.teal.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              context.l10n.lblTime,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildQuickDateChip(
              context: context,
              isDark: isDark,
              label: context.l10n.filterToday,
              icon: Icons.today_rounded,
              option: QuickDateOption.today,
            ),
            _buildQuickDateChip(
              context: context,
              isDark: isDark,
              label: context.l10n.filterTomorrow,
              icon: Icons.event_rounded,
              option: QuickDateOption.tomorrow,
            ),
            _buildQuickDateChip(
              context: context,
              isDark: isDark,
              label: context.l10n.filterThisWeekend,
              icon: Icons.weekend_rounded,
              option: QuickDateOption.thisWeekend,
            ),
            _buildQuickDateChip(
              context: context,
              isDark: isDark,
              label: _selectedQuickDate == QuickDateOption.custom && _customDateRange != null
                  ? _formatDateRange(context, _customDateRange!)
                  : context.l10n.filterSelectDateRange,
              icon: Icons.date_range_rounded,
              option: QuickDateOption.custom,
            ),
          ],
        ),
      ],
    );
  }

  String _formatDateRange(BuildContext context, DateTimeRange range) {
    // Ay kısaltmaları aktif dile göre intl ile üretilir (TR: Oca/Şub, EN: Jan/Feb).
    final locale = Localizations.localeOf(context).toString();
    final mmm = DateFormat.MMM(locale);
    final startMonth = mmm.format(range.start);
    final endMonth = mmm.format(range.end);

    if (range.start.month == range.end.month) {
      return '${range.start.day} - ${range.end.day} $endMonth';
    }
    return '${range.start.day} $startMonth - ${range.end.day} $endMonth';
  }

  Widget _buildQuickDateChip({
    required BuildContext context,
    required bool isDark,
    required String label,
    required IconData icon,
    required QuickDateOption option,
  }) {
    final isSelected = _selectedQuickDate == option;
    
    return GestureDetector(
      onTap: () => _onQuickDateSelected(option),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: isDark
                      ? [AppColors.neonCyan, AppColors.neonCyan.withAlpha(180)]
                      : [Colors.teal.shade500, Colors.teal.shade400],
                )
              : null,
          color: isSelected
              ? null
              : (isDark 
                  ? Colors.white.withAlpha(10) 
                  : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? null
              : Border.all(
                  color: isDark 
                      ? Colors.white.withAlpha(15) 
                      : Colors.grey.shade300,
                ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isDark ? AppColors.neonCyan : Colors.teal)
                        .withAlpha(40),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? Colors.white
                  : (isDark 
                      ? Colors.white.withAlpha(180) 
                      : Colors.grey.shade700),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark 
                        ? Colors.white.withAlpha(180) 
                        : Colors.grey.shade700),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceSection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.payments_rounded,
              size: 20,
              color: isDark ? AppColors.neonCyan : Colors.teal.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              context.l10n.lblPrice,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            setState(() {
              _isFreeOnly = !_isFreeOnly;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _isFreeOnly
                  ? (isDark 
                      ? AppColors.neonCyan.withAlpha(30) 
                      : Colors.green.shade50)
                  : (isDark 
                      ? Colors.white.withAlpha(10) 
                      : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isFreeOnly
                    ? (isDark 
                        ? AppColors.neonCyan 
                        : Colors.green.shade400)
                    : (isDark 
                        ? Colors.white.withAlpha(15) 
                        : Colors.grey.shade300),
                width: _isFreeOnly ? 2 : 1,
              ),
              boxShadow: _isFreeOnly
                  ? [
                      BoxShadow(
                        color: (isDark ? AppColors.neonCyan : Colors.green)
                            .withAlpha(30),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  _isFreeOnly 
                      ? Icons.check_circle_rounded 
                      : Icons.circle_outlined,
                  size: 22,
                  color: _isFreeOnly
                      ? (isDark ? AppColors.neonCyan : Colors.green.shade600)
                      : (isDark 
                          ? Colors.white.withAlpha(180) 
                          : Colors.grey.shade600),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.filterFreeEventsOnly,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: _isFreeOnly 
                              ? FontWeight.w600 
                              : FontWeight.w500,
                          color: _isFreeOnly
                              ? (isDark 
                                  ? AppColors.neonCyan 
                                  : Colors.green.shade700)
                              : (isDark 
                                  ? Colors.white.withAlpha(180) 
                                  : Colors.grey.shade700),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.filterFreeEventsOnlyDesc,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark 
                              ? Colors.white.withAlpha(100) 
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _isFreeOnly,
                  onChanged: (value) {
                    setState(() {
                      _isFreeOnly = value;
                    });
                  },
                  activeThumbColor:
                      isDark ? AppColors.neonCyan : Colors.green.shade600,
                  activeTrackColor: (isDark
                          ? AppColors.neonCyan
                          : Colors.green.shade600)
                      .withAlpha(80),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context, bool isDark, double bottomPadding) {
    final hasActiveFilters = _selectedQuickDate != null ||
        _isFreeOnly ||
        _sortMode != EventSortMode.date;
    
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomPadding),
      decoration: BoxDecoration(
        color: isDark 
            ? AppColors.darkBackground 
            : Colors.grey.shade50,
        border: Border(
          top: BorderSide(
            color: isDark 
                ? Colors.white.withAlpha(10) 
                : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          // Reset Button
          TextButton(
            onPressed: hasActiveFilters ? _onReset : null,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              context.l10n.filterReset,
              style: TextStyle(
                color: hasActiveFilters
                    ? (isDark ? Colors.white.withAlpha(180) : Colors.grey.shade700)
                    : (isDark ? Colors.white.withAlpha(50) : Colors.grey.shade400),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Apply Button
          Expanded(
            child: ElevatedButton(
              onPressed: _onApply,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.neonCyan : Colors.teal.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                context.l10n.btnApply,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
