import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:project491/views/home_view.dart';
import 'package:project491/views/preview_schedule_view.dart';
import 'package:project491/views/set_duties_view.dart';
import 'package:project491/views/view_preferences_view.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/date_editor_dialog.dart';

class RoomView extends StatefulWidget {
  final String roomId;
  final String roomName;
  final String roomDescription;
  final List<Map<String, dynamic>> participants;
  final String currentUserId;

  const RoomView({
    Key? key,
    required this.roomId,
    required this.roomName,
    required this.roomDescription,
    required this.participants,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<RoomView> createState() => _RoomViewState();
}

class _RoomViewState extends State<RoomView> {
  List<Map<String, dynamic>> _participants = [];
  final TextEditingController _newParticipantController =
      TextEditingController();
  bool _isHost = false;
  Map<String, List<Map<String, String>>>? _appliedSchedule;
  bool _showOnlyMySchedule = false;
  final ScrollController _scheduleScrollController = ScrollController();
  Map<int, Map<String, dynamic>> _doctorPreferences = {};

  @override
  void initState() {
    super.initState();
    _participants = widget.participants;
    _isHost = _participants.any(
      (p) => p['isHost'] == true && p['userId'] == widget.currentUserId,
    );
    _loadSchedules().then((_) {
      if (_appliedSchedule != null) {
        final sortedDates = _appliedSchedule!.keys.toList()..sort();
        _scrollToToday(sortedDates);
      }
    });
    _loadAllDoctorPreferences();
  }

  @override
  void dispose() {
    _scheduleScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSchedules() async {
    final roomDoc =
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomId)
            .get();

    if (roomDoc.exists) {
      setState(() {
        _appliedSchedule = _convertScheduleData(
          roomDoc.data()?['appliedSchedule'],
        );
      });
    }
  }

  Map<String, List<Map<String, String>>>? _convertScheduleData(dynamic data) {
    if (data == null) return null;

    final Map<String, List<Map<String, String>>> result = {};
    (data as Map<String, dynamic>).forEach((key, value) {
      result[key] =
          (value as List)
              .map((item) => Map<String, String>.from(item))
              .toList();
    });
    return result;
  }

  Future<void> _refreshRoom() async {
    try {
      final roomDoc =
          await FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .get();

      if (roomDoc.exists) {
        setState(() {
          _participants = List<Map<String, dynamic>>.from(
            roomDoc.data()?['participants'] ?? [],
          );
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _loadAllDoctorPreferences() async {
    try {
      final preferencesSnapshot =
          await FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .collection('preferences')
              .get();

      setState(() {
        _doctorPreferences.clear();
        for (var doc in preferencesSnapshot.docs) {
          // Doktor ismini doğrudan document ID olarak kullanıyoruz
          final doctorName = doc.id;
          final data = doc.data();

          // Doktor hala odada var mı kontrol ediyoruz
          if (_participants.any((p) => p['name'] == doctorName)) {
            final List<int> availability =
                (data['availability'] as List<dynamic>?)
                    ?.map((e) => e as int)
                    .toList() ??
                [];

            // İndex yerine doktor ismi ile saklıyoruz
            _doctorPreferences[_participants.indexWhere(
              (p) => p['name'] == doctorName,
            )] = {
              'shiftsCount': data['shiftsCount'] as int,
              'availability': availability,
            };
          }
        }
      });
    } catch (e) {
      print('Error loading doctor preferences: $e');
    }
  }

  Future<void> _handleParticipantTap(Map<String, dynamic> participant) async {
    // Check if user is already assigned to another participant
    bool isAlreadyAssigned = _participants.any(
      (p) => p != participant && p['userId'] == widget.currentUserId,
    );

    // If user is not host, use existing assignment logic
    if (!_isHost) {
      if (participant['userId'] != null && participant['userId'].isNotEmpty) {
        // Show warning for assigned participant
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Participant Assigned'),
                content: Text(
                  'This participant is already assigned to ${participant['name']}.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      } else if (isAlreadyAssigned) {
        // Show warning that user is already assigned
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Already Assigned'),
                content: const Text(
                  'You are already assigned to another participant in this room.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      } else {
        // Show confirmation for unassigned participant
        final bool? confirm = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Assign Participant'),
                content: Text(
                  'Do you want to assign yourself to ${participant['name']}? \n You won\'t be able to unassign yourself later.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Yes'),
                  ),
                ],
              ),
        );

        if (confirm == true) {
          try {
            // Get user's name from Firestore
            final userDoc =
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.currentUserId)
                    .get();

            final userName = userDoc.data()?['name'] ?? 'Unknown User';

            // Update the participant's userId and assignedUserName
            final int participantIndex = _participants.indexOf(participant);
            if (participantIndex != -1) {
              _participants[participantIndex]['userId'] = widget.currentUserId;
              _participants[participantIndex]['assignedUserName'] = userName;

              // Update in Firestore
              await FirebaseFirestore.instance
                  .collection('rooms')
                  .doc(widget.roomId)
                  .update({'participants': _participants});

              // Add room to user's rooms array if not already there
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.currentUserId)
                  .update({
                    'rooms': FieldValue.arrayUnion([widget.roomId]),
                  });

              // Refresh the room
              await _refreshRoom();
            }
          } catch (e) {
            // Show error dialog
            if (mounted) {
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Error'),
                      content: Text('Failed to assign participant: $e'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
              );
            }
          }
        }
      }
      return;
    }

    // Host-specific actions
    if (participant['userId'] != null && participant['userId'].isNotEmpty) {
      // Prevent host from unassigning themselves
      if (participant['isHost'] == true &&
          participant['userId'] == widget.currentUserId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Host cannot be unassigned'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show options to remove assigned user
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Remove Assignment'),
              content: Text(
                'Do you want to remove the assigned user from ${participant['name']}?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Remove'),
                ),
              ],
            ),
      );

      if (confirm == true) {
        await _removeUserFromParticipant(participant);
      }
    } else if (_isHost && !participant['isHost']) {
      // Show options to remove unassigned participant
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Remove Participant'),
              content: Text(
                'Do you want to remove ${participant['name']} from the room?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Remove'),
                ),
              ],
            ),
      );

      if (confirm == true) {
        await _removeParticipant(participant);
      }
    }
  }

  Future<void> _removeUserFromParticipant(
    Map<String, dynamic> participant,
  ) async {
    try {
      final int index = _participants.indexOf(participant);

      if (index != -1) {
        // Remove both userId and assignedUserName
        _participants[index]['userId'] = '';
        _participants[index]['assignedUserName'] = null;

        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomId)
            .update({'participants': _participants});

        await _refreshRoom();
      }
    } catch (e) {
      _showError('Failed to remove user: $e');
    }
  }

  bool _validateConsecutiveDaysShifts(List<int> shifts, int doctorCount) {
    for (int i = 0; i < shifts.length - 1; i++) {
      if (shifts[i] + shifts[i + 1] > doctorCount) {
        return false;
      }
    }
    return true;
  }

  Future<void> _removeParticipant(Map<String, dynamic> participant) async {
    try {
      // Get the room data to check daily shifts
      final roomDoc =
          await FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .get();

      final dailyShifts = List<int>.from(roomDoc.data()?['dailyShifts'] ?? []);
      final updatedDoctorCount = _participants.length - 1; // After removal

      if (!_validateConsecutiveDaysShifts(dailyShifts, updatedDoctorCount)) {
        if (mounted) {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Cannot Remove Doctor'),
                  content: const Text(
                    'Removing this doctor would result in consecutive days having more '
                    'shifts than available doctors. Please adjust the daily shifts first.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
          );
        }
        return;
      }

      // Original removal code
      _participants.remove(participant);

      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .update({'participants': _participants});

      // Silinen doktorun preferences'larını da sil
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('preferences')
          .doc(participant['name'])
          .delete();

      // UI'ı güncelle
      setState(() {
        _doctorPreferences.clear(); // Tüm preferences'ları temizle
      });

      // Verileri yeniden yükle
      await _refreshRoom();
      await _loadAllDoctorPreferences();
      await _loadSchedules();
    } catch (e) {
      _showError('Failed to remove participant: $e');
    }
  }

  Future<void> _addNewParticipant() async {
    final name = _newParticipantController.text.trim();
    if (name.isEmpty) return;

    // Prevent adding duplicate participant names
    final alreadyExists = _participants.any((p) => p['name'] == name);
    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A participant with this name already exists.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      _participants.add({'userId': '', 'name': name, 'isHost': false});

      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .update({'participants': _participants});

      _newParticipantController.clear();
      await _refreshRoom();
    } catch (e) {
      _showError('Failed to add participant: $e');
    }
  }

  Future<void> _deleteRoom() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Room'),
            content: const Text('Are you sure you want to delete this room?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        // Delete the room document
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomId)
            .delete();

        // Remove room from all participants' rooms arrays
        for (var participant in _participants) {
          if (participant['userId']?.isNotEmpty == true) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(participant['userId'])
                .update({
                  'rooms': FieldValue.arrayRemove([widget.roomId]),
                });
          }
        }

        if (mounted) {
          Navigator.pop(context); // Return to home view
        }
      } catch (e) {
        _showError('Failed to delete room: $e');
      }
    }
  }

  Future<void> _shareRoomInvitation() async {
    if (!_isHost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the host can share room invitations'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Generate a shareable link with the room ID
    final inviteLink = 'project491://room/${widget.roomId}';

    // Copy to clipboard
    await Clipboard.setData(ClipboardData(text: inviteLink));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invitation link copied to clipboard!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _formatDateForComparison(String date) {
    // Convert from DD.MM.YYYY to YYYY-MM-DD
    final parts = date.split('.');
    return '${parts[2]}-${parts[1]}-${parts[0]}';
  }

  void _scrollToToday(List<String> sortedDates) {
    if (sortedDates.isEmpty) return;

    final today = DateTime.now();
    final formattedToday =
        '${today.day.toString().padLeft(2, '0')}.${today.month.toString().padLeft(2, '0')}.${today.year}';

    final index = sortedDates.indexWhere((date) {
      final dateStr = _formatDateForComparison(date);
      final todayStr = _formatDateForComparison(formattedToday);
      return dateStr.compareTo(todayStr) >= 0;
    });

    if (index != -1) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scheduleScrollController.hasClients) {
          _scheduleScrollController.animateTo(
            index * 72.0, // Approximate height of each ListTile
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  Widget _buildScheduleList(Map<String, List<Map<String, String>>>? schedule) {
    if (schedule == null) return const SizedBox.shrink();

    // Filter schedule if needed
    Map<String, List<Map<String, String>>> filteredSchedule =
        _showOnlyMySchedule
            ? Map.fromEntries(
              schedule.entries.where((entry) {
                final myParticipantInfo = _participants.firstWhere(
                  (p) => p['userId'] == widget.currentUserId,
                  orElse: () => {},
                );
                return entry.value.any(
                  (assignment) =>
                      assignment['name'] == myParticipantInfo['name'],
                );
              }),
            )
            : schedule;

    final sortedDates =
        filteredSchedule.keys.toList()..sort((a, b) {
          final aDate = DateTime.parse(a.split('.').reversed.join('-'));
          final bDate = DateTime.parse(b.split('.').reversed.join('-'));
          return aDate.compareTo(bDate);
        });

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => setState(() => _showOnlyMySchedule = false),
              child: Text(
                'All',
                style: TextStyle(
                  color: !_showOnlyMySchedule ? Colors.blue : Colors.white,
                  fontWeight:
                      !_showOnlyMySchedule
                          ? FontWeight.bold
                          : FontWeight.normal,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _showOnlyMySchedule = true),
              child: Text(
                'Me',
                style: TextStyle(
                  color: _showOnlyMySchedule ? Colors.blue : Colors.white,
                  fontWeight:
                      _showOnlyMySchedule ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            controller: _scheduleScrollController,
            itemCount: sortedDates.length,
            itemBuilder: (context, index) {
              final date = sortedDates[index];
              final assignments = filteredSchedule[date]!;
              final isToday =
                  date ==
                  '${DateTime.now().day.toString().padLeft(2, '0')}.${DateTime.now().month.toString().padLeft(2, '0')}.${DateTime.now().year}';

              return ListTile(
                title: Text(
                  date,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    backgroundColor:
                        isToday ? Colors.blue.withOpacity(0.3) : null,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- REMOVE dutyCounts horizontal scroll region ---
                    ...assignments.map((a) {
                      return _isHost
                          ? Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${a['name']} (${a['assignedUser']})',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                onPressed: () => _removeAssignment(date, a),
                              ),
                            ],
                          )
                          : Text(
                            '${a['name']} (${a['assignedUser']})',
                            style: const TextStyle(color: Colors.white70),
                          );
                    }).toList(),
                  ],
                ),
                trailing:
                    _isHost
                        ? IconButton(
                          icon: const Icon(Icons.add, color: Colors.green),
                          onPressed: () => _showAddAssignmentDialog(date),
                        )
                        : null,
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _removeAssignment(
    String date,
    Map<String, String> assignment,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Remove Assignment'),
            content: Text('Remove ${assignment['name']} from $date?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        final updatedSchedule = Map<String, List<Map<String, String>>>.from(
          _appliedSchedule!,
        );
        updatedSchedule[date]!.removeWhere(
          (a) =>
              a['name'] == assignment['name'] &&
              a['assignedUser'] == assignment['assignedUser'],
        );

        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomId)
            .update({'appliedSchedule': updatedSchedule});

        await _loadSchedules();
      } catch (e) {
        _showError('Failed to remove assignment: $e');
      }
    }
  }

  Future<void> _showAddAssignmentDialog(String date) async {
    // Check for users already assigned on this date
    final List<String> assignedUsers =
        _appliedSchedule![date]!
            .map((assignment) => assignment['name'] as String)
            .toList();

    final availableParticipants =
        _participants.where((p) => !assignedUsers.contains(p['name'])).toList();

    if (availableParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All participants are already assigned for this day'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final selectedParticipant = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Add Assignment for $date'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: availableParticipants.length,
                itemBuilder: (context, index) {
                  final participant = availableParticipants[index];
                  return ListTile(
                    title: Text(participant['name']),
                    subtitle: Text(
                      participant['assignedUserName'] ?? 'Unassigned',
                    ),
                    onTap: () => Navigator.pop(context, participant),
                  );
                },
              ),
            ),
          ),
    );

    if (selectedParticipant != null) {
      try {
        final updatedSchedule = Map<String, List<Map<String, String>>>.from(
          _appliedSchedule!,
        );
        updatedSchedule[date]!.add({
          'name': selectedParticipant['name'],
          'assignedUser':
              selectedParticipant['assignedUserName'] ?? 'Unassigned',
        });

        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomId)
            .update({'appliedSchedule': updatedSchedule});

        await _loadSchedules();
      } catch (e) {
        _showError('Failed to add assignment: $e');
      }
    }
  }

  Future<void> _openSetDutiesScreen(
    Map<String, dynamic> participant,
    int index,
  ) async {
    try {
      final roomDoc =
          await FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .get();

      if (!roomDoc.exists) {
        _showError('Room data not found');
        return;
      }

      final data = roomDoc.data();
      if (data == null ||
          !data.containsKey('firstDay') ||
          !data.containsKey('lastDay')) {
        _showError('Room scheduling data is incomplete');
        return;
      }

      final firstDayStr = data['firstDay'] as String;
      final lastDayStr = data['lastDay'] as String;

      final firstDay = DateTime.parse(firstDayStr);
      final lastDay = DateTime.parse(lastDayStr);

      final normalizedFirstDay = DateTime(
        firstDay.year,
        firstDay.month,
        firstDay.day,
      );
      final normalizedLastDay = DateTime(
        lastDay.year,
        lastDay.month,
        lastDay.day,
        23,
        59,
        59,
      );

      if (mounted) {
        print('Opening duties screen for ${participant['name']}');

        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => SetDutiesView(
                  roomId: widget.roomId,
                  userId: widget.currentUserId,
                  doctorName: participant['name'],
                  doctorIndex: index,
                  firstDay: normalizedFirstDay,
                  lastDay: normalizedLastDay,
                ),
          ),
        );

        if (result != null && mounted) {
          print('Received preferences for ${participant['name']}');
          setState(() {
            _doctorPreferences[index] = {
              'shiftsCount': result['shiftsCount'],
              'availability': result['availability'],
            };
          });
        }
      }
    } catch (e) {
      _showError('Failed to open duties screen: $e');
    }
  }

  Future<void> _editDailyShifts() async {
    // First, fetch current dailyShifts from Firestore
    final roomDoc =
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomId)
            .get();

    if (!roomDoc.exists) {
      _showError('Room data not found');
      return;
    }

    final data = roomDoc.data()!;
    final List<int> currentDailyShifts = List<int>.from(data['dailyShifts']);
    final String firstDay = data['firstDay'];

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            title: const Text(
              'Edit Daily Required Shifts',
              style: TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 400, // Fixed height for scrollable content
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: currentDailyShifts.length,
                itemBuilder: (context, index) {
                  final date = DateTime.parse(
                    firstDay,
                  ).add(Duration(days: index));
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: TextFormField(
                            initialValue: currentDailyShifts[index].toString(),
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white38),
                              ),
                            ),
                            onChanged: (value) {
                              currentDailyShifts[index] =
                                  int.tryParse(value) ?? 1;
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              TextButton(
                onPressed: () async {
                  // Validate consecutive days constraint
                  if (!_validateConsecutiveDaysShifts(
                    currentDailyShifts,
                    _participants.length,
                  )) {
                    _showError(
                      'The sum of shifts for any two consecutive days cannot exceed the total number of doctors',
                    );
                    return;
                  }

                  // Update Firestore
                  await FirebaseFirestore.instance
                      .collection('rooms')
                      .doc(widget.roomId)
                      .update({'dailyShifts': currentDailyShifts});

                  if (mounted) {
                    Navigator.pop(context);
                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Daily shifts updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                child: const Text('Save', style: TextStyle(color: Colors.blue)),
              ),
            ],
          ),
    );
  }

  Future<void> _editRoomDates() async {
    try {
      final roomDoc =
          await FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .get();

      if (!roomDoc.exists) {
        _showError('Room data not found');
        return;
      }

      // Show warning dialog before proceeding
      final bool? shouldProceed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E2E),
              title: const Text(
                'Warning',
                style: TextStyle(color: Colors.white),
              ),
              content: const Text(
                'Changing room dates will reset:\n\n'
                '• All doctors\' duty preferences\n'
                '• Number of shifts for each doctor\n'
                '• Daily required shifts (will be set to 1)\n'
                '• Any existing schedule\n\n'
                'Do you want to continue?',
                style: TextStyle(color: Colors.white),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Continue',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            ),
      );

      if (shouldProceed != true) return;

      final data = roomDoc.data()!;
      final firstDay = DateTime.parse(data['firstDay'] as String);
      final lastDay = DateTime.parse(data['lastDay'] as String);

      // --- Show First Day and Last Day as two rows ---
      FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance
                .collection('rooms')
                .doc(widget.roomId)
                .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(height: 32);
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const SizedBox(height: 32);
          }
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final firstDay = data['firstDay'] ?? '';
          final lastDay = data['lastDay'] ?? '';
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'First Day: ',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      firstDay,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Last Day: ',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      lastDay,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
      // --- END BLOCK ---

      // Rest of existing date editor code...
      final result = await showDialog<Map<String, DateTime>>(
        context: context,
        builder:
            (context) => DateEditorDialog(firstDay: firstDay, lastDay: lastDay),
      );

      if (result != null) {
        // Format dates to YYYY-MM-DD
        final newFirstDay =
            '${result['firstDay']!.year}-${result['firstDay']!.month.toString().padLeft(2, '0')}-${result['firstDay']!.day.toString().padLeft(2, '0')}';
        final newLastDay =
            '${result['lastDay']!.year}-${result['lastDay']!.month.toString().padLeft(2, '0')}-${result['lastDay']!.day.toString().padLeft(2, '0')}';

        // Calculate number of days between new dates
        final daysDifference =
            result['lastDay']!.difference(result['firstDay']!).inDays + 1;

        // Create new arrays with proper length
        final List<int> newDailyShifts = List.filled(
          daysDifference,
          1,
        ); // Default value of 1 shift per day

        // Show progress dialog
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder:
                (context) => const Center(child: CircularProgressIndicator()),
          );
        }

        // Update room dates and arrays
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomId)
            .update({
              'firstDay': newFirstDay,
              'lastDay': newLastDay,
              'dailyShifts': newDailyShifts,
            });

        // Reset all preferences since date range changed
        final batch = FirebaseFirestore.instance.batch();
        final preferencesSnapshot =
            await FirebaseFirestore.instance
                .collection('rooms')
                .doc(widget.roomId)
                .collection('preferences')
                .get();

        for (var doc in preferencesSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        // Clear local preferences
        setState(() {
          _doctorPreferences.clear();
        });

        // Also clear any existing schedule
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomId)
            .update({'appliedSchedule': null});

        // Notify all assigned users (except host) about the date change
        final hostParticipant = _participants.firstWhere(
          (p) => p['isHost'] == true,
          orElse: () => <String, dynamic>{},
        );
        final hostUserId = hostParticipant['userId'];

        final roomName = widget.roomName;
        final notificationMessage =
            'Your host in "$roomName" updated start and end date. Please confirm your preferences.';

        final now = DateTime.now();

        // Find all assigned users except host
        final assignedUsers = _participants.where(
          (p) =>
              p['userId'] != null &&
              p['userId'].toString().isNotEmpty &&
              p['isHost'] != true,
        );

        // Send notifications to regular users
        for (final user in assignedUsers) {
          final userId = user['userId'];
          if (userId != null && userId.toString().isNotEmpty) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('notifications')
                .add({
                  'message': notificationMessage,
                  'roomId': widget.roomId,
                  'roomName': roomName,
                  'timestamp': now,
                  'type': 'room_dates_updated',
                });
          }
        }

        // Send notification to host
        if (hostUserId != null && hostUserId.toString().isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(hostUserId)
              .collection('notifications')
              .add({
                'message': 'You updated start and end date in "$roomName".',
                'roomId': widget.roomId,
                'roomName': roomName,
                'timestamp': now,
                'type': 'room_dates_updated_host',
              });
        }

        // Dismiss progress dialog
        if (mounted) {
          Navigator.pop(context);

          // Show detailed success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Room dates updated. All preferences and schedules have been reset. '
                'Please inform doctors to set their preferences again.',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 5),
            ),
          );
        }

        // Reload all room data
        await _refreshRoom();
        await _loadAllDoctorPreferences();
        await _loadSchedules();
      }
    } catch (e) {
      // Dismiss progress dialog if showing
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showError('Failed to update room dates: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: const Color(0xFF0D0D1B),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await _loadSchedules();
              await _refreshRoom();
              await _loadAllDoctorPreferences();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .spaceBetween, // Changed to spaceBetween
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HomeView(),
                              ),
                              (route) => false,
                            );
                          },
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              widget.roomName,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.bold,
                                fontSize: 32,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        if (_isHost)
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.share,
                                  color: Colors.white,
                                ),
                                onPressed: _shareRoomInvitation,
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: _deleteRoom,
                              ),
                            ],
                          ),
                        if (!_isHost) const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // --- Show First Day and Last Day as two rows ---
                    FutureBuilder<DocumentSnapshot>(
                      future:
                          FirebaseFirestore.instance
                              .collection('rooms')
                              .doc(widget.roomId)
                              .get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SizedBox(height: 32);
                        }
                        if (!snapshot.hasData || !snapshot.data!.exists) {
                          return const SizedBox(height: 32);
                        }
                        final data =
                            snapshot.data!.data() as Map<String, dynamic>;
                        final firstDay = data['firstDay'] ?? '';
                        final lastDay = data['lastDay'] ?? '';
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'First Day: ',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    firstDay,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Last Day: ',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    lastDay,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    // --- END BLOCK ---
                    if (_appliedSchedule != null)
                      _buildScheduleList(_appliedSchedule),
                    const SizedBox(height: 16),
                    if (_isHost) ...[
                      ElevatedButton(
                        onPressed: _editDailyShifts,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: const Text(
                          'Edit Daily Required Shifts',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_isHost)
                      ElevatedButton(
                        onPressed: () async {
                          // Prevent preview if there are unassigned participants
                          final hasUnassigned = _participants.any(
                            (p) =>
                                (p['userId'] == null ||
                                    p['userId'].toString().isEmpty) &&
                                p['isHost'] != true,
                          );
                          if (hasUnassigned) {
                            showDialog(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    backgroundColor: const Color(0xFF1E1E2E),
                                    title: const Text(
                                      'Cannot Preview Schedule',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    content: const Text(
                                      'There are unassigned participants in the room. Please assign all participants before previewing the schedule.',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text(
                                          'OK',
                                          style: TextStyle(color: Colors.blue),
                                        ),
                                      ),
                                    ],
                                  ),
                            );
                            return;
                          }
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (BuildContext context) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                          );

                          try {
                            // Filter participants to get only doctors (non-host users)
                            final doctors =
                                _participants
                                    .asMap()
                                    .entries
                                    .map(
                                      (entry) => entry.value['name'] as String,
                                    )
                                    .toList();

                            if (doctors.isEmpty) {
                              Navigator.pop(context);
                              _showError(
                                'No doctors found in the room. Please add participants first.',
                              );
                              return;
                            }

                            final roomDoc =
                                await FirebaseFirestore.instance
                                    .collection('rooms')
                                    .doc(widget.roomId)
                                    .get();

                            final data = roomDoc.data();
                            final firstDay = data?['firstDay'] as String;
                            final lastDay = data?['lastDay'] as String;
                            final dailyShifts = List<int>.from(
                              data?['dailyShifts'] ?? [],
                            );

                            // Prepare the input data with doctors from participants
                            final numShifts = List<int>.generate(
                              doctors.length,
                              (i) =>
                                  _doctorPreferences[i]?['shiftsCount'] ?? 10,
                            );

                            final availabilityMatrix = List<
                              List<int>
                            >.generate(doctors.length, (i) {
                              final prefs = _doctorPreferences[i];
                              // Properly cast the availability array
                              final List<int> availability =
                                  (prefs?['availability'] as List<dynamic>?)
                                      ?.map((e) => e as int)
                                      .toList() ??
                                  List<int>.filled(dailyShifts.length, 0);
                              print(
                                'Doctor ${doctors[i]} (index $i) availability: $availability',
                              );
                              return availability;
                            });

                            final inputData = {
                              'firstDay': firstDay,
                              'lastDay': lastDay,
                              'doctors': doctors,
                              'numShifts': numShifts,
                              'dailyShifts': dailyShifts,
                              'availabilityMatrix': availabilityMatrix,
                            };

                            print('Algorithm Input Data:');
                            print('Doctors order: $doctors'); // Debug print
                            print(
                              'Number of Shifts per Doctor: $numShifts',
                            ); // Debug print
                            print('Daily Required Shifts: $dailyShifts');
                            print(
                              'Availability Matrix: $availabilityMatrix',
                            ); // Debug print

                            // Make API request
                            final response = await http.post(
                              Uri.parse(
                                'http://127.0.0.1:8000/api/generate-schedule/',
                              ),
                              headers: {'Content-Type': 'application/json'},
                              body: jsonEncode(inputData),
                            );

                            if (response.statusCode == 200) {
                              final resultData = jsonDecode(response.body);
                              print('API Response: $resultData'); // Debug print

                              // Extract the schedule from the response
                              final scheduleData =
                                  resultData['schedule']
                                      as Map<String, dynamic>;

                              // Convert API response to schedule format
                              final Map<String, List<String>> schedule = {};
                              scheduleData.forEach((date, doctors) {
                                if (doctors is List) {
                                  print(
                                    'Processing date: $date, doctors: $doctors',
                                  ); // Debug print
                                  schedule[date] = List<String>.from(doctors);
                                }
                              });

                              print('Final schedule: $schedule'); // Debug print

                              Navigator.pop(context); // Remove loading dialog
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => PreviewScheduleView(
                                        participants: _participants,
                                        roomId: widget.roomId,
                                        scheduleData: schedule,
                                      ),
                                ),
                              );

                              // If returned with refresh flag, reload the data
                              if (result == true) {
                                await _loadSchedules();
                                await _refreshRoom();
                              }
                            } else {
                              Navigator.pop(context); // Remove loading dialog
                              _showError(
                                'Failed to fetch schedule: ${response.body}',
                              );
                            }
                          } catch (e) {
                            Navigator.pop(context); // Remove loading dialog
                            _showError('Error occurred: $e');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: const Text(
                          'Preview New Schedule',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            widget.roomDescription,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_isHost) ...[
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _editRoomDates,
                              icon: const Icon(
                                Icons.calendar_today,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Edit Room Dates',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Center(
                      child: Text(
                        'Participants',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          fontSize: 20,
                          color: Colors.white,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_isHost)
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _newParticipantController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(
                                      hintText: 'Add new participant',
                                      hintStyle: TextStyle(
                                        color: Colors.white60,
                                      ),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.white60,
                                        ),
                                      ),
                                    ),
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => _addNewParticipant(),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                  ),
                                  onPressed: _addNewParticipant,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    SizedBox(
                      height: MediaQuery.of(context).size.height - 300,
                      child: ListView.builder(
                        itemCount: _participants.length,
                        itemBuilder: (context, index) {
                          final participant = _participants[index];
                          return InkWell(
                            onTap: () => _handleParticipantTap(participant),
                            child: _buildParticipantRow(
                              participant['name'],
                              _getParticipantStatusColor(participant),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantRow(String name, Color statusColor) {
    final participant = _participants.firstWhere(
      (p) => p['name'] == name,
      orElse: () => <String, dynamic>{},
    );

    bool isHost = participant['isHost'] == true;
    String? assignedUserName = participant['assignedUserName'];
    final index = _participants.indexWhere((p) => p['name'] == name);
    final hasPreferences = _doctorPreferences.containsKey(index);
    final isCurrentUser = participant['userId'] == widget.currentUserId;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: isHost ? Border.all(color: Colors.blue, width: 3.0) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.person, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isHost || assignedUserName != null)
                  Text(
                    '${isHost ? "Host" : ""}${isHost && assignedUserName != null ? " • " : ""}${assignedUserName != null ? "Assigned to: $assignedUserName" : ""}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
              ],
            ),
          ),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          if (participant['userId']?.isNotEmpty ==
              true) // Sadece atanmış kullanıcılar için
            TextButton(
              onPressed:
                  isCurrentUser // Kendisi ise (host olsa bile)
                      ? () => _openSetDutiesScreen(participant, index)
                      : hasPreferences // Kendisi değilse ve preferences varsa
                      ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => ViewPreferencesView(
                                  doctorName: participant['name'],
                                  preferences: _doctorPreferences[index]!,
                                ),
                          ),
                        );
                      }
                      : null, // Kendisi değilse ve preferences yoksa butonu devre dışı bırak
              child: Text(
                isCurrentUser
                    ? hasPreferences
                        ? 'Edit Duties'
                        : 'Set Duties'
                    : hasPreferences
                    ? 'View Duties'
                    : 'No Duties Set',
                style: TextStyle(
                  color:
                      isCurrentUser || hasPreferences
                          ? Colors.blue
                          : Colors.grey,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getParticipantStatusColor(Map<String, dynamic> participant) {
    if (participant['userId'] == null || participant['userId'].isEmpty) {
      return Colors.grey; // No assigned userId
    }
    if (participant['userId'] == widget.currentUserId) {
      return Colors.green; // Current user
    }
    return Colors.red; // Other assigned user
  }
}
