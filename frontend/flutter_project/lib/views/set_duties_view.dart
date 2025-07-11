import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project491/utils/app_localizations.dart';

class SetDutiesView extends StatefulWidget {
  final String roomId;
  final String userId;
  final String doctorName;
  final int doctorIndex;
  final DateTime firstDay;
  final DateTime lastDay;

  const SetDutiesView({
    Key? key,
    required this.roomId,
    required this.userId,
    required this.doctorName,
    required this.doctorIndex,
    required this.firstDay,
    required this.lastDay,
  }) : super(key: key);

  @override
  State<SetDutiesView> createState() => _SetDutiesViewState();
}

class _SetDutiesViewState extends State<SetDutiesView> {
  final FocusNode _shiftsFocus = FocusNode();
  TextEditingController? _shiftsController;
  late ValueNotifier<Map<DateTime, int>> _selectedDaysNotifier;
  late CalendarFormat _calendarFormat;
  late DateTime _focusedDay;

  @override
  void initState() {
    super.initState();
    _shiftsController = TextEditingController();
    _calendarFormat = CalendarFormat.month;
    _focusedDay = widget.firstDay;
    _selectedDaysNotifier = ValueNotifier<Map<DateTime, int>>({});
    _loadPreferences();
  }

  @override
  void dispose() {
    _shiftsFocus.dispose();
    _selectedDaysNotifier.dispose();
    _shiftsController?.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .collection('preferences')
              .doc(widget.doctorName)
              .get();

      if (doc.exists) {
        final data = doc.data()!;
        _shiftsController!.text = data['shiftsCount'].toString();

        if (data['availability'] != null) {
          final List<int> availability = List<int>.from(data['availability']);
          final Map<DateTime, int> selectedDays = {};

          DateTime current = widget.firstDay;
          for (int i = 0; i < availability.length; i++) {
            if (availability[i] != 0) {
              final normalizedDate = DateTime(
                current.year,
                current.month,
                current.day,
              );
              selectedDays[normalizedDate] = availability[i];
            }
            current = current.add(const Duration(days: 1));
          }

          if (mounted) {
            setState(() {
              _selectedDaysNotifier.value = Map<DateTime, int>.from(
                selectedDays,
              );
            });
          }
        }
      } else {
        // No preferences: fetch defaultShifts from room
        final roomDoc =
            await FirebaseFirestore.instance
                .collection('rooms')
                .doc(widget.roomId)
                .get();
        int defaultShifts = 0;
        if (roomDoc.exists) {
          final roomData = roomDoc.data();
          if (roomData != null && roomData.containsKey('defaultShifts')) {
            defaultShifts = roomData['defaultShifts'] ?? 0;
          }
        }
        _shiftsController!.text = defaultShifts.toString();
      }
    } catch (e) {
      print('Error loading preferences: $e');
      _shiftsController!.text = '0';
    }
  }

  Future<void> _savePreferences(Map<String, dynamic> dutyData) async {
    try {
      final Map<String, int> normalizedDays = {};
      _selectedDaysNotifier.value.forEach((key, value) {
        final normalizedDate = DateTime(key.year, key.month, key.day);
        normalizedDays[normalizedDate.toIso8601String()] = value;
      });

      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('preferences')
          .doc(widget.doctorName) // Doktor indexi yerine ismini kullanıyoruz
          .set({
            'shiftsCount': dutyData['shiftsCount'],
            'availability': dutyData['availability'],
            'selectedDays': normalizedDays,
            'doctorName': widget.doctorName,
          });
    } catch (e) {
      print('Error saving preferences: $e');
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    // Create a normalized date for consistency
    final normalizedDate = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );

    // Only allow selection within the valid date range
    if (normalizedDate.isBefore(widget.firstDay) ||
        normalizedDate.isAfter(widget.lastDay)) {
      return;
    }

    // Create new map with current values
    final newSelectedDays = Map<DateTime, int>.from(
      _selectedDaysNotifier.value,
    );

    setState(() {
      _focusedDay = focusedDay;

      // Toggle between states: null -> 1 -> -1 -> null
      if (!newSelectedDays.containsKey(normalizedDate)) {
        // Not selected -> Available (+1)
        newSelectedDays[normalizedDate] = 1;
      } else if (newSelectedDays[normalizedDate] == 1) {
        // Available -> Unavailable (-1)
        newSelectedDays[normalizedDate] = -1;
      } else if (newSelectedDays[normalizedDate] == -1) {
        // Unavailable -> On Leave (-99999)
        newSelectedDays[normalizedDate] = -99999;
      } else {
        // On Leave -> Not selected (remove)
        newSelectedDays.remove(normalizedDate);
      }

      // Update the notifier to trigger UI rebuild
      _selectedDaysNotifier.value = Map<DateTime, int>.from(newSelectedDays);
    });
  }

  Map<String, dynamic> _getDutyData() {
    final List<int> availability = [];
    DateTime current = widget.firstDay;

    print('Generating availability for ${widget.doctorName}'); // Debug print

    while (current.compareTo(widget.lastDay) <= 0) {
      final normalizedDate = DateTime(current.year, current.month, current.day);
      final value = _selectedDaysNotifier.value[normalizedDate] ?? 0;
      availability.add(value);
      current = current.add(const Duration(days: 1));
    }

    final shiftsCount = int.parse(_shiftsController!.text);

    print('Doctor: ${widget.doctorName}'); // Debug print
    print('Shifts count: $shiftsCount'); // Debug print
    print('Availability array: $availability'); // Debug print

    return {
      'doctorIndex': widget.doctorIndex,
      'shiftsCount': shiftsCount,
      'availability': availability,
    };
  }

  Future<void> _handleSave() async {
    final dutyData = _getDutyData();
    await _savePreferences(dutyData);
    if (mounted) {
      Navigator.pop(context, dutyData);
    }
  }

  Widget _buildCalendarDay(
    DateTime date,
    bool isEnabled,
    Map<DateTime, int> selectedDays,
  ) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final color =
        isEnabled
            ? (selectedDays.containsKey(normalizedDate)
                ? (selectedDays[normalizedDate] == 1
                    ? const Color(0xFF5C9D5C) // Available (+1)
                    : selectedDays[normalizedDate] == -1
                    ? const Color(0xFFCE5A57) // Unavailable (-1)
                    : Colors.purple)
                : Colors.transparent)
            : Colors.transparent;

    return Container(
      margin: const EdgeInsets.all(4.0),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border:
            isEnabled && color == Colors.transparent
                ? Border.all(color: Colors.grey[600]!, width: 1)
                : null,
      ),
      child: Text(
        '${date.day}',
        style: TextStyle(
          color:
              isEnabled
                  ? (color == Colors.transparent ? Colors.white : Colors.black)
                  : Colors.grey,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final message = AppLocalizations.of(context).get('setDuties');
    return Scaffold(
      backgroundColor: const Color(0x1E1E1E),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          '$message - ${widget.doctorName}',
          style: const TextStyle(color: Colors.white), // Title text white
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ), // Back icon white
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                focusNode: _shiftsFocus, //  ← NEW
                controller: _shiftsController,
                keyboardType:
                    const TextInputType //  ← keep the pure numeric pad
                    .numberWithOptions(signed: false, decimal: false),
                textInputAction:
                    TextInputAction.done, //  ← shows “Done” / ✅ key
                onEditingComplete:
                    () => _shiftsFocus.unfocus(), // closes on iOS
                onSubmitted: (_) => _shiftsFocus.unfocus(), // closes on Android
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).get('numberOfShifts'),
                  labelStyle: TextStyle(color: Colors.white),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white60),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLegendItem(
                    const Color(0xFF5C9D5C),
                    AppLocalizations.of(context).get('available'),
                  ),
                  _buildLegendItem(
                    const Color(0xFFCE5A57),
                    AppLocalizations.of(context).get('unavailable'),
                  ),
                  _buildLegendItem(
                    Colors.purple,
                    AppLocalizations.of(context).get('onLeave'),
                  ),
                  _buildLegendItem(
                    Colors.transparent,
                    AppLocalizations.of(context).get('noPreferences'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<Map<DateTime, int>>(
                valueListenable: _selectedDaysNotifier,
                builder: (context, selectedDays, _) {
                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => FocusScope.of(context).unfocus(),
                    child: TableCalendar(
                      firstDay: widget.firstDay,
                      lastDay: widget.lastDay,
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      selectedDayPredicate:
                          (day) => _selectedDaysNotifier.value.containsKey(day),
                      onDaySelected: _onDaySelected,
                      onPageChanged: (focusedDay) {
                        setState(() {
                          _focusedDay = focusedDay;
                        });
                      },
                      enabledDayPredicate: (day) {
                        final compareDate = DateTime(
                          day.year,
                          day.month,
                          day.day,
                        );
                        final firstDate = DateTime(
                          widget.firstDay.year,
                          widget.firstDay.month,
                          widget.firstDay.day,
                        );
                        final lastDate = DateTime(
                          widget.lastDay.year,
                          widget.lastDay.month,
                          widget.lastDay.day,
                        );
                        return !compareDate.isBefore(firstDate) &&
                            !compareDate.isAfter(lastDate);
                      },
                      calendarStyle: CalendarStyle(
                        selectedDecoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.transparent,
                        ),
                        todayDecoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.transparent,
                        ),
                        selectedTextStyle: const TextStyle(color: Colors.white),
                        todayTextStyle: const TextStyle(color: Colors.blue),
                        defaultTextStyle: const TextStyle(color: Colors.white),
                        weekendTextStyle: const TextStyle(
                          color: Colors.white70,
                        ),
                        disabledTextStyle: const TextStyle(color: Colors.grey),
                      ),
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(color: Colors.white),
                        leftChevronIcon: Icon(
                          Icons.chevron_left,
                          color: Colors.white,
                        ),
                        rightChevronIcon: Icon(
                          Icons.chevron_right,
                          color: Colors.white,
                        ),
                      ),
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, date, _) {
                          final isEnabled =
                              !date.isBefore(widget.firstDay) &&
                              !date.isAfter(widget.lastDay);
                          return _buildCalendarDay(
                            date,
                            isEnabled,
                            _selectedDaysNotifier.value,
                          );
                        },
                        selectedBuilder: (context, date, _) {
                          return _buildCalendarDay(
                            date,
                            true,
                            _selectedDaysNotifier.value,
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D61E7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _handleSave,
                      child: Text(
                        AppLocalizations.of(context).get('savePreferences'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border:
                color == Colors.transparent
                    ? Border.all(color: Colors.grey[600]!, width: 1)
                    : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
