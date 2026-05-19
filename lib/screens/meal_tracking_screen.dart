import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class MealTrackingScreen extends StatefulWidget {
  const MealTrackingScreen({super.key});

  @override
  State<MealTrackingScreen> createState() => _MealTrackingScreenState();
}

class _MealTrackingScreenState extends State<MealTrackingScreen> {
  List<Map<String, dynamic>> _mealData = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  String _currentUserId = '';
  String _currentUserRole = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final response = await Supabase.instance.client
        .from('users')
        .select('id, role')
        .limit(1);
    
    if (response.isNotEmpty) {
      setState(() {
        _currentUserId = response[0]['id'];
        _currentUserRole = response[0]['role'] ?? 'member';
      });
      _loadMealData();
    }
  }

  Future<void> _loadMealData() async {
    setState(() => _isLoading = true);
    
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
    final response = await Supabase.instance.client
        .from('users')
        .select('''
          id,
          name,
          meals!left (meal_type, is_taken, marked_at)
        ''')
        .eq('role', 'member')
        .eq('meals.meal_date', dateStr);
    
    final List<Map<String, dynamic>> data = [];
    for (var user in response) {
      final meals = user['meals'] as List? ?? [];
      
      Map<String, dynamic> mealStatus = {
        'breakfast': false,
        'lunch': false,
        'dinner': false,
        'breakfast_time': null,
        'lunch_time': null,
        'dinner_time': null,
      };
      
      for (var meal in meals) {
        mealStatus[meal['meal_type']] = meal['is_taken'];
        mealStatus['${meal['meal_type']}_time'] = meal['marked_at'];
      }
      
      data.add({
        'id': user['id'],
        'name': user['name'],
        ...mealStatus,
      });
    }
    
    setState(() {
      _mealData = data;
      _isLoading = false;
    });
  }

  Future<void> _toggleMeal(String userId, String mealType, bool currentValue) async {
    if (_currentUserRole != 'admin' && userId != _currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only mark your own meals!')),
      );
      return;
    }
    
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
    try {
      // Check if already marked and trying to unmark
      if (currentValue) {
        final existingMeal = await Supabase.instance.client
            .from('meals')
            .select('marked_at')
            .eq('user_id', userId)
            .eq('meal_date', dateStr)
            .eq('meal_type', mealType)
            .maybeSingle();
        
        if (existingMeal != null && existingMeal['marked_at'] != null) {
          final markedTime = DateTime.parse(existingMeal['marked_at']);
          final difference = DateTime.now().difference(markedTime);
          
          if (difference.inMinutes >= 5) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cannot unmark meal after 5 minutes!')),
            );
            return;
          }
        }
      }
      
      // Update or insert meal record
      await Supabase.instance.client
          .from('meals')
          .upsert({
            'user_id': userId,
            'meal_date': dateStr,
            'meal_type': mealType,
            'is_taken': !currentValue,
            'marked_at': !currentValue ? DateTime.now().toIso8601String() : null,
          });
      
      _loadMealData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Meal ${!currentValue ? 'marked' : 'unmarked'} successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _changeDate(int days) async {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _loadMealData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Tracking'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (_currentUserRole == 'admin')
            IconButton(
              icon: const Icon(Icons.date_range),
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2026),
                );
                if (date != null) {
                  setState(() => _selectedDate = date);
                  _loadMealData();
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Date Selector
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue.shade50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => _changeDate(-1),
                      ),
                      Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => _changeDate(1),
                        onLongPress: () => _changeDate(7),
                      ),
                    ],
                  ),
                ),
                
                // Meal Table Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: const Row(
                    children: [
                      Expanded(flex: 2, child: Text('Member', textAlign: TextAlign.center)),
                      Expanded(child: Text('🍳 Breakfast', textAlign: TextAlign.center)),
                      Expanded(child: Text('🍽️ Lunch', textAlign: TextAlign.center)),
                      Expanded(child: Text('🍲 Dinner', textAlign: TextAlign.center)),
                    ],
                  ),
                ),
                
                // Meal List
                Expanded(
                  child: ListView.builder(
                    itemCount: _mealData.length,
                    itemBuilder: (context, index) {
                      final member = _mealData[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                member['name'],
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            Expanded(
                              child: _buildMealButton(
                                member['id'],
                                'breakfast',
                                member['breakfast'],
                              ),
                            ),
                            Expanded(
                              child: _buildMealButton(
                                member['id'],
                                'lunch',
                                member['lunch'],
                              ),
                            ),
                            Expanded(
                              child: _buildMealButton(
                                member['id'],
                                'dinner',
                                member['dinner'],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                
                // Legend
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border(top: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 5),
                      Text('Taken'),
                      SizedBox(width: 20),
                      Icon(Icons.cancel, color: Colors.red, size: 20),
                      SizedBox(width: 5),
                      Text('Not Taken'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
  
  Widget _buildMealButton(String userId, String mealType, bool isTaken) {
    final canEdit = (_currentUserRole == 'admin' || userId == _currentUserId);
    
    return GestureDetector(
      onTap: canEdit ? () => _toggleMeal(userId, mealType, isTaken) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isTaken ? Colors.green.shade100 : Colors.red.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isTaken ? Icons.check_circle : Icons.cancel,
          color: isTaken ? Colors.green : Colors.red,
          size: 24,
        ),
      ),
    );
  }
}