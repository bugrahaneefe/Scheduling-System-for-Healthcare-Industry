import 'package:flutter/material.dart';

class PreviewScheduleView extends StatelessWidget {
  final List<Map<String, dynamic>> participants;

  const PreviewScheduleView({Key? key, required this.participants})
    : super(key: key);

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

    // Generate schedule for January 2025
    for (int day = 1; day <= 31; day++) {
      String date = day < 10 ? '0$day.01.2025' : '$day.01.2025';

      // Randomly select 2-3 participants for each day
      participantInfo.shuffle();
      int numberOfParticipants = (day % 2 == 0) ? 2 : 3;
      schedule[date] = participantInfo.take(numberOfParticipants).toList();
    }

    return schedule;
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
                onPressed: () {
                  // Will be implemented later
                },
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
