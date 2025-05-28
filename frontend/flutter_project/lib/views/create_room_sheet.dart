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
  final TextEditingController _defaultShiftsController = TextEditingController(
    text: '0',
  );
  List<int> _dailyShifts = [];
  bool _isLoading = false;
  List<Map<String, dynamic>> _selectedParticipants = [];
  late DateTime _firstDay;
  late DateTime _lastDay;
  int _defaultShifts = 0;

  @override
  void initState() {
    super.initState();
    // Add host as first participant
    _selectedParticipants.add({
      'userId': widget.hostId,
      'name': widget.hostName,
      'isHost': true,
      'defaultShifts': _defaultShifts,
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
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1D61E7),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.black),
            ),
            dialogBackgroundColor: Colors.white,
            textSelectionTheme: const TextSelectionThemeData(
              cursorColor: Colors.black,
              selectionColor: Colors.black12,
              selectionHandleColor: Colors.black,
            ),
            inputDecorationTheme: const InputDecorationTheme(
              labelStyle: TextStyle(
                color: Colors.black,
              ), // Ensure label text is black
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.black),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.black, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.black),
              ),
              hintStyle: TextStyle(
                color: Colors.black,
              ), // Ensure "Enter date" text is black
            ),
          ),
          child: Builder(
            builder: (context) {
              return child!;
            },
          ),
        );
      },
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
              backgroundColor: Colors.white,
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
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.black,
                        ), // Changed to black border
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Set all days to:',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                          SizedBox(
                            width: 60,
                            child: TextFormField(
                              controller: allDaysController,
                              cursorColor: Colors.black,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.black),
                              decoration: const InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.black,
                                    width: 2,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black),
                                ),
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
                              setStateDialog(() {});
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFF1D61E7),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            child: const Text(
                              'Apply',
                              style: TextStyle(color: Colors.white),
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
                                    cursorColor: Colors.black,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.black,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.black,
                                          width: 2,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.black,
                                        ),
                                      ),
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
                  child: const Text(
                    'Done',
                    style: TextStyle(color: Colors.black),
                  ), // Changed Done button color
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
        'defaultShifts': _defaultShifts,
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
        'The sum of shifts for any two consecutive days cannot exceed the total number of doctors.',
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

      // Parse default shifts count
      _defaultShifts = int.tryParse(_defaultShiftsController.text) ?? 0;
      // Update all participants' defaultShifts before saving
      for (var p in _selectedParticipants) {
        p['defaultShifts'] = _defaultShifts;
      }

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
        'defaultShifts': _defaultShifts, // Save to room for later use
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
          (_) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            title: const Text(
              'Invalid Shifts',
              style: TextStyle(color: Colors.black),
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
                child: const Text('OK', style: TextStyle(color: Colors.white)),
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
            color: Colors.white, // Changed background to white
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
                // Modify Room Name field:
                Focus(
                  child: Builder(
                    builder: (context) {
                      return TextFormField(
                        controller: _nameController,
                        cursorColor: Colors.black,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          labelText: 'Room Name',
                          labelStyle: const TextStyle(color: Colors.black),
                          border: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.black),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Colors.black,
                              width: 2,
                            ),
                          ),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                        textInputAction: TextInputAction.next,
                        validator:
                            (value) =>
                                value?.isEmpty == true
                                    ? 'Room name is required'
                                    : null,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Modify Description field:
                Focus(
                  child: Builder(
                    builder: (context) {
                      return TextFormField(
                        controller: _descriptionController,
                        cursorColor: Colors.black,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          labelText: 'Description',
                          labelStyle: const TextStyle(color: Colors.black),
                          border: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.black),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Colors.black,
                              width: 2,
                            ),
                          ),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                        textInputAction: TextInputAction.next,
                        maxLines: 3,
                        validator:
                            (value) =>
                                value?.isEmpty == true
                                    ? 'Description is required'
                                    : null,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Focus(
                        child: Builder(
                          builder: (context) {
                            return TextFormField(
                              controller: _firstDayController,
                              cursorColor: Colors.black,
                              style: const TextStyle(color: Colors.black),
                              decoration: InputDecoration(
                                labelText: 'First Day',
                                labelStyle: const TextStyle(
                                  color: Colors.black,
                                ),
                                border: OutlineInputBorder(
                                  borderSide: const BorderSide(
                                    color: Colors.black,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(
                                    color: Colors.black,
                                    width: 2,
                                  ),
                                ),
                                fillColor: Colors.white,
                                filled: true,
                              ),
                              readOnly: true,
                              onTap: () => _selectDate(context, true),
                              validator:
                                  (value) =>
                                      value?.isEmpty == true
                                          ? 'First day is required'
                                          : null,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Focus(
                        child: Builder(
                          builder: (context) {
                            return TextFormField(
                              controller: _lastDayController,
                              cursorColor: Colors.black,
                              style: const TextStyle(color: Colors.black),
                              decoration: InputDecoration(
                                labelText: 'Last Day',
                                labelStyle: const TextStyle(
                                  color: Colors.black,
                                ),
                                border: OutlineInputBorder(
                                  borderSide: const BorderSide(
                                    color: Colors.black,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(
                                    color: Colors.black,
                                    width: 2,
                                  ),
                                ),
                                fillColor: Colors.white,
                                filled: true,
                              ),
                              readOnly: true,
                              onTap: () => _selectDate(context, false),
                              validator:
                                  (value) =>
                                      value?.isEmpty == true
                                          ? 'Last day is required'
                                          : null,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Modify Default Number of Shifts field:
                Focus(
                  child: Builder(
                    builder: (context) {
                      return TextFormField(
                        controller: _defaultShiftsController,
                        cursorColor: Colors.black,
                        style: const TextStyle(color: Colors.black),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Default Number of Shifts',
                          labelStyle: const TextStyle(color: Colors.black),
                          hintText:
                              'Enter default number of shifts for each participant',
                          hintStyle: const TextStyle(color: Colors.black),
                          border: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.black),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Colors.black,
                              width: 2,
                            ),
                          ),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter default number of shifts';
                          }
                          final shifts = int.tryParse(value);
                          if (shifts == null || shifts < 0) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          setState(() {
                            _defaultShifts = int.tryParse(value) ?? 0;
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _editDailyShifts,
                  icon: const Icon(
                    Icons.edit,
                    color: Colors.black,
                  ), // changed to black
                  label: const Text(
                    'Edit Daily Required Shifts',
                    style: TextStyle(color: Colors.black), // changed to black
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(
                      color: Colors.black,
                    ), // changed to black border
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Focus(
                        child: Builder(
                          builder: (context) {
                            return TextFormField(
                              controller: _participantNameController,
                              cursorColor: Colors.black,
                              style: const TextStyle(color: Colors.black),
                              decoration: InputDecoration(
                                labelText: 'Add Participant',
                                labelStyle: const TextStyle(
                                  color: Colors.black,
                                ),
                                border: OutlineInputBorder(
                                  borderSide: const BorderSide(
                                    color: Colors.black,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(
                                    color: Colors.black,
                                    width: 2,
                                  ),
                                ),
                                fillColor: Colors.white,
                                filled: true,
                              ),
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted:
                                  (_) => _addParticipant(
                                    _participantNameController.text,
                                  ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 40, // Fixed size for circular button
                      height: 40,
                      child: ElevatedButton(
                        onPressed:
                            () => _addParticipant(
                              _participantNameController.text,
                            ),
                        child: const Icon(Icons.add, color: Colors.white),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D61E7),
                          padding: EdgeInsets.zero,
                          shape:
                              const CircleBorder(), // Makes the button circular
                        ),
                      ),
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
                                      ? Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF1D61E7,
                                          ), // Changed background color
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Text(
                                          'Host',
                                          style: TextStyle(
                                            color: Colors.white,
                                          ), // Changed text color to white
                                        ),
                                      )
                                      : IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle,
                                          color:
                                              Colors
                                                  .red, // Changed from Color(0xFF1D61E7) to Colors.red
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
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black, // changed to black
                            ),
                          )
                          : const Text(
                            'Create Room',
                            style: TextStyle(
                              color: Colors.black,
                            ), // changed to black
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(
                      color: Colors.black,
                    ), // changed to black border
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
