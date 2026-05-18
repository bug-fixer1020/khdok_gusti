import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MealAttendanceScreen extends StatefulWidget {
  const MealAttendanceScreen({super.key});

  @override
  State<MealAttendanceScreen> createState() => _MealAttendanceScreenState();
}

class _MealAttendanceScreenState extends State<MealAttendanceScreen> {
  List<Map<String, dynamic>> _members = [];
  Map<String, Map<String, bool>> _mealStatus = {};
  bool _isLoading = true;
  String? _currentUserId;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    _currentUserId = user?.id;
    
    try {
      final membersResponse = await Supabase.instance.client
          .from('members')
          .select('*')
          .eq('is_active', true);
      
      _members = List<Map<String, dynamic>>.from(membersResponse);
      await _loadMealStatus();
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMealStatus() async {
    final dateStr = _selectedDate.toIso8601String().split('T')[0];
    
    for (var member in _members) {
      final memberId = member['id'];
      _mealStatus[memberId] = {
        'breakfast': false,
        'lunch': false,
        'dinner': false,
      };
      
      final response = await Supabase.instance.client
          .from('meals')
          .select('meal_type, is_taken, taken_at')
          .eq('member_id', memberId)
          .eq('meal_date', dateStr);
      
      for (var meal in response) {
        _mealStatus[memberId]![meal['meal_type']] = meal['is_taken'];
      }
    }
    setState(() {});
  }

  Future<void> _toggleMeal(String memberId, String mealType) async {
    final currentStatus = _mealStatus[memberId]![mealType] ?? false;
    final dateStr = _selectedDate.toIso8601String().split('T')[0];
    
    if (currentStatus) {
      final response = await Supabase.instance.client
          .from('meals')
          .select('taken_at')
          .eq('member_id', memberId)
          .eq('meal_date', dateStr)
          .eq('meal_type', mealType)
          .single();
      
      if (response != null && response['taken_at'] != null) {
        final takenAt = DateTime.parse(response['taken_at']);
        final now = DateTime.now();
        final difference = now.difference(takenAt);
        
        if (difference.inMinutes < 5) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You cannot unmark a meal within 5 minutes of marking it!')),
          );
          return;
        }
      }
    }
    
    try {
      final existing = await Supabase.instance.client
          .from('meals')
          .select()
          .eq('member_id', memberId)
          .eq('meal_date', dateStr)
          .eq('meal_type', mealType);
      
      if (existing.isEmpty) {
        await Supabase.instance.client.from('meals').insert({
          'member_id': memberId,
          'meal_date': dateStr,
          'meal_type': mealType,
          'is_taken': !currentStatus,
          'taken_at': !currentStatus ? DateTime.now().toIso8601String() : null,
        });
      } else {
        await Supabase.instance.client
            .from('meals')
            .update({
              'is_taken': !currentStatus,
              'taken_at': !currentStatus ? DateTime.now().toIso8601String() : null,
            })
            .eq('member_id', memberId)
            .eq('meal_date', dateStr)
            .eq('meal_type', mealType);
      }
      
      setState(() {
        _mealStatus[memberId]![mealType] = !currentStatus;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Meal ${!currentStatus ? 'marked' : 'unmarked'} successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  int _getTotalMeals(String memberId) {
    int total = 0;
    if (_mealStatus[memberId]?['breakfast'] == true) total++;
    if (_mealStatus[memberId]?['lunch'] == true) total++;
    if (_mealStatus[memberId]?['dinner'] == true) total++;
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Attendance'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() {
                  _selectedDate = date;
                  _loadMealStatus();
                });
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.grey[200],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Text('Total Meals', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _members.length,
                    itemBuilder: (context, index) {
                      final member = _members[index];
                      final memberId = member['id'];
                      final isCurrentUser = member['user_id'] == _currentUserId;
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        elevation: 2,
                        child: Column(
                          children: [
                            ListTile(
                              title: Text(
                                member['name'],
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text('Total Meals Today: ${_getTotalMeals(memberId)}'),
                              trailing: CircleAvatar(
                                backgroundColor: Colors.green,
                                child: Text(
                                  '${_getTotalMeals(memberId)}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  _buildMealButton(memberId, 'breakfast', 'Breakfast', isCurrentUser),
                                  const SizedBox(width: 8),
                                  _buildMealButton(memberId, 'lunch', 'Lunch', isCurrentUser),
                                  const SizedBox(width: 8),
                                  _buildMealButton(memberId, 'dinner', 'Dinner', isCurrentUser),
                                ],
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
    );
  }

  Widget _buildMealButton(String memberId, String mealType, String label, bool canEdit) {
    final isTaken = _mealStatus[memberId]?[mealType] ?? false;
    
    return Expanded(
      child: ElevatedButton(
        onPressed: canEdit ? () => _toggleMeal(memberId, mealType) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isTaken ? Colors.green : Colors.grey[300],
          foregroundColor: isTaken ? Colors.white : Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Icon(isTaken ? Icons.check_circle : Icons.radio_button_unchecked, size: 20),
          ],
        ),
      ),
    );
  }
}