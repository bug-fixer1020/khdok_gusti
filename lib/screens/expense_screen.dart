import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  List<Map<String, dynamic>> _expenses = [];
  bool _isLoading = true;
  double _totalExpense = 0;
  double _mealRate = 0;
  int _totalMeals = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final startOfMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
      final endOfMonth = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
      
      final response = await Supabase.instance.client
          .from('expenses')
          .select('*')
          .gte('expense_date', startOfMonth.toIso8601String())
          .lte('expense_date', endOfMonth.toIso8601String())
          .order('expense_date', ascending: false);
      
      _expenses = List<Map<String, dynamic>>.from(response);
      _totalExpense = _expenses.fold(0, (sum, item) => sum + (item['amount'] as num).toDouble());
      
      final summaryResponse = await Supabase.instance.client
          .from('monthly_summary')
          .select('total_meals, meal_rate')
          .eq('month_year', startOfMonth.toIso8601String())
          .maybeSingle();
      
      if (summaryResponse != null) {
        _totalMeals = summaryResponse['total_meals'] ?? 0;
        _mealRate = (summaryResponse['meal_rate'] as num?)?.toDouble() ?? 0;
      }
    } catch (e) {
      print('Error loading expenses: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addExpense() async {
    final dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final categoryController = TextEditingController();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Expense'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dateController,
                decoration: const InputDecoration(labelText: 'Date'),
                readOnly: true,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    dateController.text = DateFormat('yyyy-MM-dd').format(date);
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Category (e.g., Fish, Oil, Rice)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Amount (Taka)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description (Optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (categoryController.text.isNotEmpty && amountController.text.isNotEmpty) {
                final user = Supabase.instance.client.auth.currentUser;
                try {
                  await Supabase.instance.client.from('expenses').insert({
                    'expense_date': dateController.text,
                    'category': categoryController.text,
                    'amount': double.parse(amountController.text),
                    'description': descriptionController.text,
                    'added_by': user!.id,
                  });
                  
                  await _updateMonthlySummary(dateController.text);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Expense added successfully')),
                  );
                  Navigator.pop(context);
                  _loadData();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateMonthlySummary(String dateStr) async {
    final date = DateTime.parse(dateStr);
    final monthYear = DateTime(date.year, date.month, 1);
    
    final expensesResponse = await Supabase.instance.client
        .from('expenses')
        .select('amount')
        .gte('expense_date', monthYear.toIso8601String())
        .lte('expense_date', DateTime(date.year, date.month + 1, 0).toIso8601String());
    
    final totalExpense = (expensesResponse as List)
        .fold(0.0, (sum, item) => sum + (item['amount'] as num).toDouble());
    
    final mealsResponse = await Supabase.instance.client
        .from('meals')
        .select('is_taken')
        .gte('meal_date', monthYear.toIso8601String())
        .lte('meal_date', DateTime(date.year, date.month + 1, 0).toIso8601String())
        .eq('is_taken', true);
    
    final totalMeals = mealsResponse.length;
    final mealRate = totalMeals > 0 ? totalExpense / totalMeals : 0;
    
    await Supabase.instance.client.from('monthly_summary').upsert({
      'month_year': monthYear.toIso8601String(),
      'total_expense': totalExpense,
      'total_meals': totalMeals,
      'meal_rate': mealRate,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addExpense,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.green.withOpacity(0.1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          const Text('Total Expense', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('৳${_totalExpense.toStringAsFixed(2)}', 
                               style: const TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('Total Meals', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('$_totalMeals', 
                               style: const TextStyle(fontSize: 18, color: Colors.blue, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('Meal Rate', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('৳${_mealRate.toStringAsFixed(2)}', 
                               style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _expenses.length,
                    itemBuilder: (context, index) {
                      final expense = _expenses[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        elevation: 2,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green,
                            child: Text(
                              expense['category'][0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            expense['category'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(expense['description'] ?? 'No description'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('৳${(expense['amount'] as num).toStringAsFixed(2)}',
                                   style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                              Text(expense['expense_date'], style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}