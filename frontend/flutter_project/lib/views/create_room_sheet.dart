import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateRoomSheet extends StatefulWidget {
  final String hostId;
  final String hostName;

  const CreateRoomSheet({
    Key? key,
    required this.hostId,
    required this.hostName,
  }) : super(key: key);

  @override
  State<CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<CreateRoomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _participantNameController = TextEditingController();
  final _firstDayController = TextEditingController();
  final _lastDayController = TextEditingController();
  List<int> _dailyShifts = [];
  bool _isLoading = false;
  List<Map<String, dynamic>> _selectedParticipants = [];
  late DateTime _firstDay;
  late DateTime _lastDay;

  @override
  void initState() {
    super.initState();
    // Add host as first participant
    _selectedParticipants.add({
      'userId': widget.hostId,
      'name': widget.hostName,
      'isHost': true,
    });

    final now = DateTime.now();
    _firstDay = DateTime(now.year, now.month, now.day);
    _lastDay = _firstDay.add(const Duration(days: 1));

    // Initialize controllers with default dates (current month)
    _firstDayController.text = _formatDate(_firstDay);
    _lastDayController.text = _formatDate(_lastDay);

    // Initialize daily shifts with zeros instead of ones
    _dailyShifts = List.filled(_getDaysBetween(_firstDay, _lastDay), 0);
  }

  String _formatDate(DateTime date) {
    // Format date as YYYY-MM-DD
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  int _getDaysBetween(DateTime start, DateTime end) {
    return end.difference(start).inDays + 1;
  }

  Future<void> _selectDate(BuildContext context, bool isFirstDay) async {
    // Get current values
    DateTime? currentFirstDay =
        _firstDayController.text.isNotEmpty
            ? DateTime.parse(_firstDayController.text)
            : null;
    DateTime? currentLastDay =
        _lastDayController.text.isNotEmpty
            ? DateTime.parse(_lastDayController.text)
            : null;

    // Set minimum selectable date
    DateTime minDate =
        isFirstDay
            ? DateTime.now() // firstDay için bugün
            : currentFirstDay ??
                DateTime.now(); // lastDay için firstDay veya bugün

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          isFirstDay
              ? minDate
              : (currentLastDay ?? minDate.add(const Duration(days: 1))),
      firstDate: minDate,
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      // Create date at noon UTC to avoid timezone issues
      final normalizedDate = DateTime.utc(
        picked.year,
        picked.month,
        picked.day,
        12,
      );

      setState(() {
        if (isFirstDay) {
          _firstDayController.text = _formatDate(normalizedDate);
          // firstDay değiştiğinde lastDay'i kontrol et
          if (currentLastDay != null &&
              !currentLastDay.isAfter(normalizedDate)) {
            // lastDay'i firstDay'den bir gün sonraya ayarla
            final newLastDay = normalizedDate.add(const Duration(days: 1));
            _lastDayController.text = _formatDate(newLastDay);
          }
        } else {
          _lastDayController.text = _formatDate(normalizedDate);
        }

        // Update daily shifts array length
        final start = DateTime.parse(_firstDayController.text);
        final end = DateTime.parse(_lastDayController.text);
        final days = _getDaysBetween(start, end);
        _dailyShifts = List.filled(days, 1);
      });
    }
  }

  Future<void> _editDailyShifts() async {
    // Controller for "Apply to all days"
    final allDaysController = TextEditingController(text: '0');
    // Controllers for each day's shift
    final List<TextEditingController> dayControllers = List.generate(
      _dailyShifts.length,
      (i) => TextEditingController(text: _dailyShifts[i].toString()),
    );

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Edit Daily Required Shifts'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Apply to all days section
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Set all days to:',
                              style: TextStyle(color: Colors.black87),
                            ),
                          ),
                          SizedBox(
                            width: 60,
                            child: TextFormField(
                              controller: allDaysController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              final value =
                                  int.tryParse(allDaysController.text) ?? 0;
                              for (int i = 0; i < dayControllers.length; i++) {
                                dayControllers[i].text = value.toString();
                              }
                              setStateDialog(
                                () {},
                              ); // Rebuild dialog to update fields
                            },
                            child: const Text(
                              'Apply',
                              style: TextStyle(color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 32),
                    // Daily shifts list
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: dayControllers.length,
                        itemBuilder: (context, index) {
                          final date = DateTime.parse(
                            _firstDayController.text,
                          ).add(Duration(days: index));
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                Expanded(child: Text(_formatDate(date))),
                                SizedBox(
                                  width: 60,
                                  child: TextFormField(
                                    controller: dayControllers[index],
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );

    // Dialog kapandıktan sonra controller'lardaki değerleri _dailyShifts'e aktar
    setState(() {
      for (int i = 0; i < _dailyShifts.length; i++) {
        _dailyShifts[i] = int.tryParse(dayControllers[i].text) ?? 0;
      }
    });
  }

  void _addParticipant(String name) {
    if (name.isEmpty) return;

    setState(() {
      _selectedParticipants.add({
        'userId': '', // Empty for now, will be assigned later
        'name': name,
        'isHost': false,
      });
      _participantNameController.clear();
    });
  }

  bool _validateConsecutiveDaysShifts(List<int> shifts, int doctorCount) {
    for (int i = 0; i < shifts.length - 1; i++) {
      if (shifts[i] + shifts[i + 1] > doctorCount) {
        return false;
      }
    }
    return true;
  }

  Future<void> _createRoom() async {
    if (!_formKey.currentState!.validate()) return;

    // Parse dates and set to noon UTC
    final firstDay = DateTime.parse(
      _firstDayController.text,
    ).add(const Duration(hours: 12));
    final lastDay = DateTime.parse(
      _lastDayController.text,
    ).add(const Duration(hours: 12));
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);

    // Validate dates
    if (firstDay.isBefore(todayNormalized)) {
      await _showErrorDialog('First day cannot be before today');
      return;
    }

    if (!lastDay.isAfter(firstDay)) {
      await _showErrorDialog('Last day must be after first day');
      return;
    }

    // Add validation for consecutive days' shifts
    final doctorCount = _selectedParticipants.length;
    if (!_validateConsecutiveDaysShifts(_dailyShifts, doctorCount)) {
      await _showErrorDialog(
        'The sum of shifts for any two consecutive days cannot exceed the total number of doctors',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Store dates in YYYY-MM-DD format
      final formattedFirstDay = _formatDate(firstDay);
      final formattedLastDay = _formatDate(lastDay);

      // _dailyShifts burada kullanıcı tarafından düzenlenmiş haliyle kaydedilecek
      // (yeniden sıfırlama veya varsayılana çekme yok!)
      final roomRef = await FirebaseFirestore.instance.collection('rooms').add({
        'name': _nameController.text,
        'description': _descriptionController.text,
        'createdAt': FieldValue.serverTimestamp(),
        'participants': _selectedParticipants,
        'firstDay': formattedFirstDay,
        'lastDay': formattedLastDay,
        'dailyShifts': _dailyShifts,
      });

      // Update host's rooms array
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.hostId)
          .update({
            'rooms': FieldValue.arrayUnion([roomRef.id]),
          });

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        await _showErrorDialog('Failed to create room: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showErrorDialog(String message) async {
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            title: const Text('Error', style: TextStyle(color: Colors.white)),
            content: Text(message, style: const TextStyle(color: Colors.white)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: Colors.blue)),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF5F5F5), // Light gray background
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Create New Room',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Room Name',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  validator:
                      (value) =>
                          value?.isEmpty == true
                              ? 'Room name is required'
                              : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  maxLines: 3,
                  validator:
                      (value) =>
                          value?.isEmpty == true
                              ? 'Description is required'
                              : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstDayController,
                        decoration: const InputDecoration(
                          labelText: 'First Day',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                        ),
                        readOnly: true,
                        onTap: () => _selectDate(context, true),
                        validator:
                            (value) =>
                                value?.isEmpty == true
                                    ? 'First day is required'
                                    : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _lastDayController,
                        decoration: const InputDecoration(
                          labelText: 'Last Day',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                        ),
                        readOnly: true,
                        onTap: () => _selectDate(context, false),
                        validator:
                            (value) =>
                                value?.isEmpty == true
                                    ? 'Last day is required'
                                    : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _editDailyShifts,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Daily Required Shifts'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _participantNameController,
                        decoration: const InputDecoration(
                          labelText: 'Add Participant',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          _addParticipant(_participantNameController.text);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed:
                          () =>
                              _addParticipant(_participantNameController.text),
                      child: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Participants:',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _selectedParticipants.length,
                          itemBuilder: (context, index) {
                            final participant = _selectedParticipants[index];
                            return ListTile(
                              dense: true,
                              title: Text(
                                participant['name'] as String,
                                style: const TextStyle(color: Colors.black87),
                              ),
                              trailing:
                                  participant['isHost'] == true
                                      ? const Chip(label: Text('Host'))
                                      : IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle,
                                          color: Colors.red,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _selectedParticipants.removeAt(
                                              index,
                                            );
                                          });
                                        },
                                      ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _createRoom,
                  child:
                      _isLoading
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Create Room'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
