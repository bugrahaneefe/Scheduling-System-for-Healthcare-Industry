import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PreviewScheduleView extends StatelessWidget {
  final List<Map<String, dynamic>> participants;
  final String roomId;

  const PreviewScheduleView({
    Key? key,
    required this.participants,
    required this.roomId,
  }) : super(key: key);

  Map<String, List<Map<String, String>>> _generateSchedule() {
    final Map<String, List<Map<String, String>>> schedule = {};
    final List<Map<String, String>> participantInfo =
        participants.map((p) {
          return {
            'name': p['name'] as String,
            'assignedUser':
                p['isHost'] == true
                    ? 'Host'
                    : (p['assignedUserName'] as String? ?? 'Unassigned'),
          };
        }).toList();

    // Get today's date
    final now = DateTime.now();
    // Calculate the end date (1 month from today)
    final endDate = DateTime(now.year, now.month + 1, now.day);

    // Generate schedule from today until end date
    for (
      var date = now;
      date.isBefore(endDate);
      date = date.add(const Duration(days: 1))
    ) {
      String formattedDate =
          '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

      // Randomly select 2-3 participants for each day
      participantInfo.shuffle();
      int numberOfParticipants = (date.day % 2 == 0) ? 2 : 3;
      schedule[formattedDate] =
          participantInfo.take(numberOfParticipants).toList();
    }

    return schedule;
  }

  Future<void> _applySchedule(
    BuildContext context,
    Map<String, List<Map<String, String>>> schedule,
  ) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Only update appliedSchedule, remove previewSchedule
      await FirebaseFirestore.instance.collection('rooms').doc(roomId).update({
        'appliedSchedule': schedule,
      });

      if (context.mounted) {
        // Remove loading indicator
        Navigator.pop(context);
        // Return to room view and refresh data
        Navigator.pop(context, true); // Pass true to indicate refresh needed
      }
    } catch (e) {
      // Remove loading indicator
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply schedule: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final schedule = _generateSchedule();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1B),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Schedule Preview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48), // For balance
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: schedule.length,
                itemBuilder: (context, index) {
                  String date = schedule.keys.elementAt(index);
                  List<Map<String, String>> names = schedule[date]!;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: Colors.white.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            date,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(color: Colors.white30),
                          ...names.map(
                            (info) => Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: Text(
                                '• ${info['name']} (${info['assignedUser']})',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () => _applySchedule(context, schedule),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text(
                  'Apply Schedule',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
