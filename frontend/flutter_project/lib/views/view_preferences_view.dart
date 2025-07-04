import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project491/utils/app_localizations.dart';

class ViewPreferencesView extends StatefulWidget {
  final String doctorName;
  final Map<String, dynamic> preferences;
  final bool isHost;
  final String roomId;

  const ViewPreferencesView({
    Key? key,
    required this.doctorName,
    required this.preferences,
    required this.isHost,
    required this.roomId,
  }) : super(key: key);

  @override
  State<ViewPreferencesView> createState() => _ViewPreferencesViewState();
}

class _ViewPreferencesViewState extends State<ViewPreferencesView> {
  late TextEditingController _shiftsController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _shiftsController = TextEditingController(
      text: widget.preferences['shiftsCount'].toString(),
    );
  }

  Future<void> _showMessage(String message, bool isError) async {
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            title: Text(
              isError
                  ? AppLocalizations.of(context).get('error')
                  : AppLocalizations.of(context).get('shiftCountUpdate'),
              style: const TextStyle(color: Colors.black),
            ),
            content: Text(
              message,
              style: const TextStyle(color: Colors.black87),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF1D61E7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  AppLocalizations.of(context).get('ok'),
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _updateShiftsCount() async {
    final newCount = int.tryParse(_shiftsController.text);
    if (newCount == null) return;

    setState(() => _isLoading = true);

    try {
      final prefsRef = FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('preferences')
          .doc(widget.doctorName);

      final doc = await prefsRef.get();

      if (doc.exists) {
        await prefsRef.update({'shiftsCount': newCount});
      } else {
        await prefsRef.set({
          'shiftsCount': newCount,
          'availability': List<int>.filled(
            DateTime.parse(widget.preferences['lastDay'])
                    .difference(DateTime.parse(widget.preferences['firstDay']))
                    .inDays +
                1,
            0,
          ),
        });
      }

      // Update local state immediately
      setState(() {
        widget.preferences['shiftsCount'] = newCount;
      });

      if (mounted) {
        await _showMessage(
          AppLocalizations.of(context).get('shiftCountUpdatedSuccessfully'),
          false,
        );
        // Return with updated data
        Navigator.pop(context, {
          'shiftsCount': newCount,
          'doctorName': widget.doctorName,
          'availability': widget.preferences['availability'],
        });
      }
    } catch (e) {
      if (mounted) {
        final message = AppLocalizations.of(
          context,
        ).get('failedToUpdateShiftCount');
        await _showMessage('$message$e', true);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shiftsCount = widget.preferences['shiftsCount'] as int;
    final availability = List<int>.from(
      widget.preferences['availability'] as List,
    );

    // Parse firstDay with null check and fallback
    final firstDay =
        widget.preferences['firstDay'] != null
            ? DateTime.parse(widget.preferences['firstDay'] as String)
            : DateTime.now();
    final lastDay =
        widget.preferences['lastDay'] != null
            ? DateTime.parse(widget.preferences['lastDay'] as String)
            : firstDay.add(Duration(days: availability.length - 1));
    final message = AppLocalizations.of(context).get('preferences');
    return Scaffold(
      backgroundColor: const Color(0x1E1E1E),
      appBar: AppBar(
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
        ),
        title: FittedBox(
          fit: BoxFit.scaleDown, //    down only (never up)
          child: Text(
            "${widget.doctorName}$message",
            maxLines: 2, // ② keep a single line
            style: const TextStyle(color: Colors.white),
            overflow: TextOverflow.ellipsis, // ③ still add “…” if necessary
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Color(0xFF1D61E7).withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.white.withOpacity(0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.work_history,
                          color: Color(0xFF1D61E7),
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(
                                  context,
                                ).get('requestedNumberOfShifts'),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (widget.isHost) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _shiftsController,
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                        cursorColor: const Color(0xFF1D61E7),
                                        decoration: const InputDecoration(
                                          enabledBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Colors.white,
                                            ),
                                          ),
                                          focusedBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Color(0xFF1D61E7),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed:
                                          _isLoading
                                              ? null
                                              : _updateShiftsCount,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF1D61E7,
                                        ),
                                      ),
                                      child:
                                          _isLoading
                                              ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.white),
                                                ),
                                              )
                                              : Text(
                                                AppLocalizations.of(
                                                  context,
                                                ).get('update'),
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                    ),
                                  ],
                                ),
                              ] else
                                Text(
                                  shiftsCount.toString(),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month,
                          color: Color(0xFF1D61E7),
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(
                            context,
                          ).get('availabilityCalendar'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TableCalendar(
                      firstDay: firstDay,
                      lastDay: lastDay,
                      focusedDay: firstDay,
                      calendarFormat: CalendarFormat.month,
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
                      calendarStyle: const CalendarStyle(
                        defaultTextStyle: TextStyle(color: Colors.white),
                        weekendTextStyle: TextStyle(color: Colors.white70),
                        outsideTextStyle: TextStyle(color: Colors.grey),
                      ),
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, date, _) {
                          final dayIndex = date.difference(firstDay).inDays;
                          if (dayIndex < 0 || dayIndex >= availability.length) {
                            return null;
                          }

                          final value = availability[dayIndex];
                          final backgroundColor =
                              value == 1
                                  ? const Color(
                                    0xFF5C9D5C,
                                  ) // Green for available
                                  : value == -1
                                  ? const Color(
                                    0xFFCE5A57,
                                  ) // Red for unavailable
                                  : value == -99999
                                  ? Colors
                                      .purple // Purple for on leave
                                  : Colors.grey; // Grey for no preference

                          return Container(
                            margin: const EdgeInsets.all(4.0),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: backgroundColor.withOpacity(0.8),
                            ),
                            child: Text(
                              '${date.day}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Legend
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0),
                          child: _buildLegendItem(
                            const Color(0xFF5C9D5C),
                            AppLocalizations.of(context).get('available'),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0),
                          child: _buildLegendItem(
                            const Color(0xFFCE5A57),
                            AppLocalizations.of(context).get('unavailable'),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0),
                          child: _buildLegendItem(
                            Colors.purple,
                            AppLocalizations.of(context).get('onLeave'),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0),
                          child: _buildLegendItem(
                            Colors.grey,
                            AppLocalizations.of(context).get('noPreferences'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
