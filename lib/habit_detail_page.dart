import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import '../services/habit_service.dart';

class HabitDetailPage extends StatefulWidget {
  const HabitDetailPage({super.key, required this.habitId});
  final String habitId;

  @override
  State<HabitDetailPage> createState() => _HabitDetailPageState();
}

class _HabitDetailPageState extends State<HabitDetailPage> {
  late final HabitService _service;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _service = HabitService(FirebaseFirestore.instance, fb_auth.FirebaseAuth.instance);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        elevation: 0,
        title: const Text('Habit'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'archive') await _service.archiveHabit(widget.habitId);
              if (v == 'delete') {
                await _service.deleteHabit(widget.habitId);
                if (mounted) Navigator.pop(context);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'archive', child: Text('Archivieren')),
              PopupMenuItem(value: 'delete', child: Text('Löschen')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openEditSheet,
        icon: const Icon(Icons.edit),
        label: const Text('Bearbeiten'),
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _service.watchHabit(widget.habitId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final h = snap.data!;
          final title = (h['name'] as String?) ?? '';
          final desc  = (h['description'] as String?) ?? '';
          final currentStreak = (h['currentStreak'] as num?)?.toInt() ?? 0;
          final longestStreak = (h['longestStreak'] as num?)?.toInt() ?? 0;

          return StreamBuilder<Set<String>>(
            stream: _service.watchCompletions(widget.habitId),
            builder: (context, compSnap) {
              final completedDays = compSnap.data ?? <String>{};

              bool isCompleted(DateTime day) {
                final d = DateTime(day.year, day.month, day.day)
                    .toIso8601String()
                    .substring(0, 10);
                return completedDays.contains(d);
              }

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _HeaderCard(title: title, desc: desc),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'Aktuell',
                              value: '$currentStreak',
                              icon: Icons.local_fire_department,
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: 'Best',
                              value: '$longestStreak',
                              icon: Icons.emoji_events,
                              color: cs.tertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      child: _ModernCalendar(
                        focusedDay: _focusedDay,
                        selectedDay: _selectedDay,
                        isCompleted: isCompleted,
                        onDaySelected: (sel, foc) {
                          setState(() {
                            _selectedDay = sel;
                            _focusedDay = foc;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: () => _service.toggleToday(widget.habitId),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Heute erledigen / rückgängig'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }

  void _openEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _EditHabitSheet(habitId: widget.habitId, service: _service),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.title, required this.desc});
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primaryContainer, cs.secondaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(label: 'Aktiv'),
              _Chip(label: 'Daily'),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            desc.isEmpty ? 'No description yet.' : desc,
            style: text.bodyMedium?.copyWith(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.onSurface.withOpacity(.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(blurRadius: 12, offset: const Offset(0, 6), color: Colors.black.withOpacity(.05))],
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(.7))),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModernCalendar extends StatelessWidget {
  const _ModernCalendar({
    required this.focusedDay,
    required this.selectedDay,
    required this.isCompleted,
    required this.onDaySelected,
  });

  final DateTime focusedDay;
  final DateTime? selectedDay;
  final bool Function(DateTime day) isCompleted;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [BoxShadow(blurRadius: 12, offset: const Offset(0, 6), color: Colors.black.withOpacity(.04))],
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: TableCalendar(
        firstDay: DateTime.utc(2022, 1, 1),
        lastDay: DateTime.utc(2100, 12, 31),
        focusedDay: focusedDay,
        calendarFormat: CalendarFormat.month,
        startingDayOfWeek: StartingDayOfWeek.monday,
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: .5),
          weekendStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: .5),
        ),
        headerStyle: HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          titleTextFormatter: (date, locale) {
            // z. B. "September 2025"
            return '${_monthName(date.month)} ${date.year}';
          },
          titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          leftChevronIcon: const Icon(Icons.chevron_left),
          rightChevronIcon: const Icon(Icons.chevron_right),
        ),
        selectedDayPredicate: (day) => isSameDay(selectedDay, day),
        onDaySelected: onDaySelected,
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          isTodayHighlighted: true,
          todayDecoration: BoxDecoration(
            color: cs.primary.withOpacity(.18),
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: cs.primary,
            shape: BoxShape.circle,
          ),
          defaultTextStyle: const TextStyle(fontWeight: FontWeight.w600),
          weekendTextStyle: const TextStyle(fontWeight: FontWeight.w600),
          markerDecoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
          markersAlignment: Alignment.bottomCenter,
          markersMaxCount: 1,
        ),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focused) => _dayCell(context, day, isCompleted(day), isSameDay(selectedDay, day), false),
          todayBuilder:   (context, day, focused) => _dayCell(context, day, isCompleted(day), isSameDay(selectedDay, day), true),
          selectedBuilder:(context, day, focused) => _dayCell(context, day, isCompleted(day), true, false),
          dowBuilder: (context, day) {
            const labels = ['MO','DI','MI','DO','FR','SA','SO'];
            return Center(child: Text(labels[day.weekday - 1], style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: .6)));
          },
        ),
        eventLoader: (day) => isCompleted(day) ? ['done'] : const [],
      ),
    );
  }

  Widget _dayCell(BuildContext context, DateTime day, bool done, bool selected, bool isToday) {
    final cs = Theme.of(context).colorScheme;
    final base = Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected
          ? cs.primary
          : (isToday ? cs.primary.withOpacity(.15) : Colors.transparent),
      ),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? cs.onPrimary : Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          if (done)
            Positioned(
              bottom: 6,
              child: Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: selected ? cs.onPrimary : Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
    return Center(child: base);
  }

  String _monthName(int m) {
    const months = [
      'Januar','Februar','März','April','Mai','Juni',
      'Juli','August','September','Oktober','November','Dezember'
    ];
    return months[m - 1];
  }
}

class _EditHabitSheet extends StatefulWidget {
  const _EditHabitSheet({required this.habitId, required this.service});
  final String habitId;
  final HabitService service;

  @override
  State<_EditHabitSheet> createState() => _EditHabitSheetState();
}

class _EditHabitSheetState extends State<_EditHabitSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _desc = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.service.watchHabit(widget.habitId).first.then((h) {
      if (h == null) return;
      _name.text = (h['name'] as String?) ?? '';
      _desc.text = (h['description'] as String?) ?? '';
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 4, width: 40, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 12),
              const Text('Habit bearbeiten', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Titel'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Titel erforderlich' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _desc,
                decoration: const InputDecoration(labelText: 'Beschreibung'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Abbrechen'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        if (_form.currentState?.validate() != true) return;
                        await widget.service.updateHabit(
                          widget.habitId,
                          name: _name.text.trim(),
                          description: _desc.text.trim(),
                        );
                        if (mounted) Navigator.pop(context);
                      },
                      child: const Text('Speichern'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
