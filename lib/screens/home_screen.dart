import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'members_list_screen.dart';
import 'meal_attendance_screen.dart';
import 'expense_screen.dart';
import 'profile_screen.dart';
import '../responsive_wrapper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String? _userRole;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final response = await Supabase.instance.client
          .from('users')
          .select('role, name')
          .eq('id', user.id)
          .single();
      
      setState(() {
        _userRole = response['role'];
        _userName = response['name'];
      });
    }
  }

  final List<Widget> _screens = [
    const MembersListScreen(),
    const MealAttendanceScreen(),
    const ExpenseScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return ResponsiveWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Icon(Icons.restaurant, color: Colors.white),
              const SizedBox(width: 10),
              const Text('Khadok Gusti'),
              const Spacer(),
              if (_userName != null)
                Text('Welcome, $_userName', style: const TextStyle(fontSize: 14)),
            ],
          ),
          backgroundColor: Colors.green,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
            ),
          ],
        ),
        body: _screens[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.green,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Members'),
            BottomNavigationBarItem(icon: Icon(Icons.restaurant), label: 'Meals'),
            BottomNavigationBarItem(icon: Icon(Icons.money), label: 'Expenses'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}