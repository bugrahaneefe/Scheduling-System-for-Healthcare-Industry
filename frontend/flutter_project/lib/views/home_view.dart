import 'package:flutter/material.dart';
import 'package:project491/utils/app_localizations.dart';
import 'package:project491/views/create_room_sheet.dart';
import 'package:project491/views/profile_edit_view.dart';
import 'package:project491/views/room_view.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'login_view.dart';
import '../managers/auth_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeView extends StatefulWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ScrollController _roomsScrollController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _roomsScrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthViewModel>(context, listen: false).loadCurrentUser();
    });
  }

  @override
  void dispose() {
    _roomsScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0x1E1E1E),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              AppLocalizations.of(context).get('homeTitle'),
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              PopupMenuButton<String>(
                color: Colors.white,
                icon: const Icon(Icons.menu),
                onSelected: (choice) {
                  final authVM = Provider.of<AuthViewModel>(
                    context,
                    listen: false,
                  );
                  if (choice == 'edit') {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      builder:
                          (_) => ProfileEditView(user: authVM.currentUser!),
                    );
                  } else if (choice == 'logout') {
                    Navigator.of(context).pushReplacement(
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const LoginView(),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    );
                    authVM.clearUserData();
                    authService.value.signOut();
                  }
                },
                itemBuilder:
                    (ctx) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: const Icon(Icons.edit, color: Colors.black),
                          title: Text(
                            AppLocalizations.of(context).get('editProfile'),
                          ),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'logout',
                        child: ListTile(
                          leading: const Icon(
                            Icons.logout,
                            color: Colors.black,
                          ),
                          title: Text(
                            AppLocalizations.of(context).get('logout'),
                          ),
                        ),
                      ),
                    ],
              ),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.black, width: 0.5)),
            ),
            height: 72,
            child: TabBar(
              controller: _tabController,
              labelColor: Color(0xFF1D61E7),
              unselectedLabelColor: Color(0xFF1D61E7),
              indicatorColor: Color(0xFF1D61E7),
              tabs: const [
                Tab(icon: Icon(Icons.home, size: 44)), // increased size
                Tab(icon: Icon(Icons.notifications, size: 44)),
              ],
            ),
          ),
          body: Consumer<AuthViewModel>(
            builder: (context, authVM, child) {
              return Column(
                children: [
                  SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.fromLTRB(2, 0, 2, 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Color(0xFF1D61E7),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black,
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    authVM.currentUser?.name != null
                                        ? Text(
                                          authVM.currentUser!.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                        : const CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Color(0xFF1D61E7),
                                              ),
                                        ),
                                    const SizedBox(height: 4),
                                    authVM.currentUser?.title != null
                                        ? Text(
                                          authVM.currentUser!.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        )
                                        : const CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Color(0xFF1D61E7),
                                              ),
                                        ),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        RefreshIndicator(
                          color: Color(0xFF1D61E7), // spinner color
                          backgroundColor: Colors.white, // circle background
                          onRefresh: () async {
                            await Provider.of<AuthViewModel>(
                              context,
                              listen: false,
                            ).loadCurrentUser();
                            setState(() {});
                          },
                          child: RawScrollbar(
                            controller: _roomsScrollController,
                            thumbVisibility: true,
                            thickness: 2,
                            radius: const Radius.circular(2),
                            thumbColor: Colors.white,
                            child: GlowingOverscrollIndicator(
                              axisDirection: AxisDirection.down,
                              color: Colors.white,
                              child: ListView(
                                controller: _roomsScrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: Column(
                                      children: [
                                        Center(
                                          child: Text(
                                            AppLocalizations.of(
                                              context,
                                            ).get('myRooms'),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        const Divider(
                                          color: Colors.white70,
                                          thickness: 1,
                                          indent: 16,
                                          endIndent: 16,
                                        ),
                                      ],
                                    ),
                                  ),

                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: FutureBuilder<List<Widget>>(
                                      future: _buildRoomsList(
                                        authVM.currentUser?.rooms ?? [],
                                      ),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return const SizedBox(
                                            height: 200,
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Color(0xFF1D61E7)),
                                              ),
                                            ),
                                          );
                                        }
                                        if (authVM.currentUser?.rooms.isEmpty ??
                                            true) {
                                          return SizedBox(
                                            height: 200,
                                            child: Center(
                                              child: Text(
                                                AppLocalizations.of(
                                                  context,
                                                ).get('noRoomAssigned'),
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: snapshot.data ?? [],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        RefreshIndicator(
                          color: Color(0xFF1D61E7),
                          backgroundColor: Colors.white,
                          onRefresh: () async {
                            setState(() {});
                          },
                          child: StreamBuilder<QuerySnapshot>(
                            stream:
                                FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(authService.value.currentUser!.uid)
                                    .collection('notifications')
                                    .orderBy('timestamp', descending: true)
                                    .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF1D61E7),
                                    ),
                                  ),
                                );
                              }

                              if (!snapshot.hasData ||
                                  snapshot.data!.docs.isEmpty) {
                                return Center(
                                  child: Text(
                                    AppLocalizations.of(
                                      context,
                                    ).get('noNotifications'),
                                    style: TextStyle(color: Colors.white),
                                  ),
                                );
                              }

                              return ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: snapshot.data!.docs.length,
                                itemBuilder: (context, index) {
                                  final notification =
                                      snapshot.data!.docs[index];
                                  final data =
                                      notification.data()
                                          as Map<String, dynamic>;
                                  final timestamp =
                                      (data['timestamp'] as Timestamp).toDate();
                                  final formattedTime =
                                      '${timestamp.day.toString().padLeft(2, '0')}.${timestamp.month.toString().padLeft(2, '0')}.${timestamp.year} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';

                                  return ListTile(
                                    title: Text(
                                      data['message'] as String,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    subtitle: Text(
                                      formattedTime,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    leading: Icon(
                                      data['type'] == 'room_dates_updated_host'
                                          ? Icons.edit_calendar
                                          : Icons.calendar_today,
                                      color: Color(0xFF1D61E7),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 35,
          child: Container(
            alignment: Alignment.center,
            child: FloatingActionButton(
              backgroundColor: Color(0xFF1D61E7),
              mini: false,
              elevation: 4,
              onPressed: () async {
                final authVM = Provider.of<AuthViewModel>(
                  context,
                  listen: false,
                );
                if (authVM.currentUser != null) {
                  _showCreateRoomSheet(context);
                }
              },
              child: const Icon(Icons.add, size: 32, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Future<List<Widget>> _buildRoomsList(List<String> roomIds) async {
    List<Widget> roomWidgets = [];
    List<String> invalidRoomIds = [];

    for (String roomId in roomIds) {
      try {
        final roomDoc =
            await FirebaseFirestore.instance
                .collection('rooms')
                .doc(roomId)
                .get();

        if (roomDoc.exists) {
          final roomData = roomDoc.data()!;
          roomWidgets.add(
            Dismissible(
              key: Key(roomId),
              background: Container(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16.0),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              direction: DismissDirection.endToStart,
              confirmDismiss: (direction) async {
                return await showDialog<bool>(
                  context: context,
                  builder:
                      (_) => AlertDialog(
                        backgroundColor: Colors.white, // white dialog
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        title: Text(
                          AppLocalizations.of(context).get('confirmDelete'),
                          style: TextStyle(color: Colors.black),
                        ),
                        content: Text(
                          AppLocalizations.of(
                            context,
                          ).get('sureToConfirmDeleteRoom'),
                          style: TextStyle(color: Colors.black87),
                        ),
                        actions: [
                          // ­— CANCEL: text-only, brand-blue label ­—
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text(
                              AppLocalizations.of(context).get('cancel'),
                              style: TextStyle(color: Colors.black),
                            ),
                          ),

                          // ­— DELETE: filled brand-blue button with white text ­—
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.red, // 🔴 red background
                              foregroundColor: Colors.white, // white text
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context).get('delete'),
                            ),
                          ),
                        ],
                      ),
                );
              },
              onDismissed: (direction) async {
                // Host kontrolünü participants array'inden yap
                final participants = List<Map<String, dynamic>>.from(
                  roomData['participants'] ?? [],
                );
                final isHost = participants.any(
                  (p) =>
                      p['isHost'] == true &&
                      p['userId'] == authService.value.currentUser!.uid,
                );

                if (isHost) {
                  // Host ise odayı tamamen sil
                  await FirebaseFirestore.instance
                      .collection('rooms')
                      .doc(roomId)
                      .delete();
                } else {
                  // Host değilse sadece kendini unassign et
                  final participants = List<Map<String, dynamic>>.from(
                    roomData['participants'] ?? [],
                  );

                  // Kullanıcının atandığı participant'ı bul
                  final myParticipant = participants.firstWhere(
                    (p) => p['userId'] == authService.value.currentUser!.uid,
                    orElse: () => <String, dynamic>{},
                  );

                  // Participant'ı unassign et
                  myParticipant['userId'] = '';
                  myParticipant['assignedUserName'] = null;

                  // Firestore'da participant güncelle
                  await FirebaseFirestore.instance
                      .collection('rooms')
                      .doc(roomId)
                      .update({'participants': participants});

                  // Notify the host that this user left the room
                  final host = participants.firstWhere(
                    (p) => p['isHost'] == true,
                    orElse: () => <String, dynamic>{},
                  );

                  if (host.isNotEmpty &&
                      host['userId'] != null &&
                      host['userId'].toString().isNotEmpty) {
                    final userDoc =
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(authService.value.currentUser!.uid)
                            .get();
                    final userName =
                        userDoc.data()?['name'] ??
                        AppLocalizations.of(context).get('aParticipant');

                    final message = AppLocalizations.of(context).translate(
                      'leftRoomMessage',
                      params: {
                        'userName': userName,
                        'roomName': roomData['name'] ?? '',
                      },
                    );

                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(host['userId'])
                        .collection('notifications')
                        .add({
                          'message': message,
                          'roomId': roomId,
                          'roomName': roomData['name'] ?? '',
                          'timestamp': DateTime.now(),
                          'type': 'left_room',
                        });
                  }

                  // Preferences'ları sil
                  await FirebaseFirestore.instance
                      .collection('rooms')
                      .doc(roomId)
                      .collection('preferences')
                      .doc(myParticipant['name'])
                      .delete();

                  // Kullanıcının rooms listesinden odayı kaldır
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(authService.value.currentUser!.uid)
                      .update({
                        'rooms': FieldValue.arrayRemove([roomId]),
                      });
                }

                // Refresh the user data
                await Provider.of<AuthViewModel>(
                  context,
                  listen: false,
                ).loadCurrentUser();
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder:
                            (_, __, ___) => RoomView(
                              roomId: roomId,
                              roomName:
                                  roomData['name'] ??
                                  AppLocalizations.of(
                                    context,
                                  ).get('unnamedRoom'),
                              roomDescription:
                                  roomData['description'] ??
                                  AppLocalizations.of(
                                    context,
                                  ).get('noDescription'),
                              participants: List<Map<String, dynamic>>.from(
                                roomData['participants'] ?? [],
                              ),
                              currentUserId: authService.value.currentUser!.uid,
                            ),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          roomData['name'] ??
                              AppLocalizations.of(context).get('unnamedRoom'),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: const [
                            Expanded(child: Divider(color: Colors.black)),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.black,
                            ), // <-- trailing icon
                          ],
                        ),
                        Text(
                          roomData['description'] ??
                              AppLocalizations.of(context).get('noDescription'),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          invalidRoomIds.add(roomId);
        }
      } catch (e) {
        invalidRoomIds.add(roomId);
      }
    }

    // Clean up invalid room IDs from user's rooms array
    if (invalidRoomIds.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(authService.value.currentUser!.uid)
            .update({'rooms': FieldValue.arrayRemove(invalidRoomIds)});

        // Refresh the user data in AuthViewModel
        await Provider.of<AuthViewModel>(
          context,
          listen: false,
        ).loadCurrentUser();
      } catch (e) {
        debugPrint('Error cleaning up invalid room IDs: $e');
      }
    }

    return roomWidgets;
  }

  void _showCreateRoomSheet(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1D61E7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => CreateRoomSheet(
            hostId: authService.value.currentUser!.uid,
            hostName:
                Provider.of<AuthViewModel>(
                  context,
                  listen: false,
                ).currentUser!.name,
          ),
    );

    if (result == true && mounted) {
      // Kullanıcı bilgilerini ve oda listesini yenile
      await Provider.of<AuthViewModel>(
        context,
        listen: false,
      ).loadCurrentUser();
      setState(() {}); // UI'ı yenile
    }
  }
}
