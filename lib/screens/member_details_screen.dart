import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemberDetailsScreen extends StatefulWidget {
  final String memberId;
  const MemberDetailsScreen({super.key, required this.memberId});

  @override
  State<MemberDetailsScreen> createState() => _MemberDetailsScreenState();
}

class _MemberDetailsScreenState extends State<MemberDetailsScreen> {
  Map<String, dynamic> _memberData = {};
  Map<String, dynamic> _mealStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMemberData();
    _loadMealStats();
  }

  Future<void> _loadMemberData() async {
    final response = await Supabase.instance.client
        .from('users')
        .select()
        .eq('id', widget.memberId)
        .single();
    
    setState(() {
      _memberData = response;
    });
  }

  Future<void> _loadMealStats() async {
    final response = await Supabase.instance.client
        .from('meals')
        .select('meal_type, is_taken')
        .eq('user_id', widget.memberId)
        .gte('meal_date', '2026-01-01')
        .lte('meal_date', '2026-01-31');
    
    int breakfast = 0, lunch = 0, dinner = 0;
    
    for (var meal in response) {
      if (meal['is_taken']) {
        switch (meal['meal_type']) {
          case 'breakfast':
            breakfast++;
            break;
          case 'lunch':
            lunch++;
            break;
          case 'dinner':
            dinner++;
            break;
        }
      }
    }
    
    setState(() {
      _mealStats = {
        'breakfast': breakfast,
        'lunch': lunch,
        'dinner': dinner,
        'total': breakfast + lunch + dinner,
      };
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_memberData['name'] ?? 'Member Details'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Profile Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    color: Colors.blue.shade50,
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.blue.shade100,
                          child: _memberData['profile_image'] != null && _memberData['profile_image'].toString().isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    _memberData['profile_image'],
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(Icons.person, size: 60, color: Colors.blue);
                                    },
                                  ),
                                )
                              : const Icon(Icons.person, size: 60, color: Colors.blue),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _memberData['name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _memberData['role']?.toUpperCase() ?? 'MEMBER',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Meal Statistics
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'January 2026 Meal Statistics',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard('Breakfast', _mealStats['breakfast'] ?? 0, Icons.free_breakfast),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard('Lunch', _mealStats['lunch'] ?? 0, Icons.lunch_dining),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard('Dinner', _mealStats['dinner'] ?? 0, Icons.dinner_dining),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Card(
                          color: Colors.blue.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Meals',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${_mealStats['total'] ?? 0}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Personal Information
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Personal Information',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoCard(Icons.email, 'Email', _memberData['email'] ?? 'N/A'),
                        _buildInfoCard(Icons.people, 'Father\'s Name', _memberData['father_name'] ?? 'N/A'),
                        _buildInfoCard(Icons.people, 'Mother\'s Name', _memberData['mother_name'] ?? 'N/A'),
                        _buildInfoCard(Icons.home, 'Address', _memberData['address'] ?? 'N/A'),
                        _buildInfoCard(Icons.school, 'Education', _memberData['current_education'] ?? 'N/A'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.blue),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(title, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(value),
      ),
    );
  }
}