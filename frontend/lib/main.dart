import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI栄養コーチ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;

  Future<void> login() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/login'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'username': emailController.text.trim(),
          'password': passwordController.text,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'] as String;

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(token: token),
          ),
        );
      } else {
        setState(() {
          errorMessage = 'ログイン失敗：${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = '通信エラー：$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI栄養コーチ'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'ログイン',
                  style: TextStyle(fontSize: 28),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'メールアドレス',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'パスワード',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: isLoading ? null : login,
                  child: Text(isLoading ? 'ログイン中...' : 'ログイン'),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final String token;

  const HomePage({super.key, required this.token});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;

  static const List<String> titles = [
    'ホーム',
    '食事記録',
    'おすすめ',
    'マイページ',
  ];

  static const List<IconData> pageIcons = [
    Icons.home_outlined,
    Icons.restaurant_outlined,
    Icons.lightbulb_outline,
    Icons.person_outline,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[selectedIndex]),
      ),
      body: selectedIndex == 1
    ? MealPage(token: widget.token)
    : selectedIndex == 3
        ? ProfilePage(token: widget.token)
        : Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  pageIcons[selectedIndex],
                  size: 64,
                  color: Colors.green,
                ),
                const SizedBox(height: 16),
                Text(
                  '${titles[selectedIndex]}画面',
                  style: const TextStyle(fontSize: 24),
                ),
              ],
            ),
          ),    
      
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'ホーム',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant),
            label: '食事記録',
          ),
          NavigationDestination(
            icon: Icon(Icons.lightbulb_outline),
            selectedIcon: Icon(Icons.lightbulb),
            label: 'おすすめ',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'マイページ',
          ),
        ],
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  final String token;

  const ProfilePage({super.key, required this.token});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? profile;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/profiles/me'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          profile = jsonDecode(response.body) as Map<String, dynamic>;
          errorMessage = null;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = '取得失敗：${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = '通信エラー：$e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Text(
          errorMessage!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    final data = profile!;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    const Text(
      'プロフィール情報',
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    ),
    IconButton(
      icon: const Icon(Icons.edit_outlined),
      tooltip: 'プロフィールを編集',
      onPressed: () async {
        final updated = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileEditPage(
              token: widget.token,
              profile: Map<String, dynamic>.from(profile!),
            ),
          ),
        );

        if (updated == true) {
          fetchProfile();
        }
      },
    ),
  ],
),
const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.cake_outlined),
          title: const Text('年齢'),
          trailing: Text('${data['age']}歳'),
        ),
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: const Text('性別'),
          trailing: Text('${data['gender']}'),
        ),
        ListTile(
          leading: const Icon(Icons.height),
          title: const Text('身長'),
          trailing: Text('${data['height_cm']} cm'),
        ),
        ListTile(
          leading: const Icon(Icons.monitor_weight_outlined),
          title: const Text('体重'),
          trailing: Text('${data['weight_kg']} kg'),
        ),
        ListTile(
          leading: const Icon(Icons.directions_run),
          title: const Text('活動レベル'),
          trailing: Text('${data['activity_level']}'),
        ),
        ListTile(
          leading: const Icon(Icons.flag_outlined),
          title: const Text('目標'),
          trailing: Text('${data['goal']}'),
        ),
      ],
    );
  }
}

class ProfileEditPage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> profile;

  const ProfileEditPage({
    super.key,
    required this.token,
    required this.profile,
  });

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  late final TextEditingController ageController;
  late final TextEditingController heightController;
  late final TextEditingController weightController;

  late String gender;
  late String activityLevel;
  late String goal;

  bool isSaving = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();

    final data = widget.profile;

    ageController = TextEditingController(
      text: '${data['age']}',
    );
    heightController = TextEditingController(
      text: '${data['height_cm']}',
    );
    weightController = TextEditingController(
      text: '${data['weight_kg']}',
    );

    gender = '${data['gender']}';
    activityLevel = '${data['activity_level']}';
    goal = '${data['goal']}';
  }

  @override
  void dispose() {
    ageController.dispose();
    heightController.dispose();
    weightController.dispose();
    super.dispose();
  }

  Future<void> saveProfile() async {
    final age = int.tryParse(ageController.text.trim());
    final height = double.tryParse(heightController.text.trim());
    final weight = double.tryParse(weightController.text.trim());

    if (age == null ||
        age <= 0 ||
        height == null ||
        height <= 0 ||
        weight == null ||
        weight <= 0) {
      setState(() {
        errorMessage = '年齢・身長・体重には正しい数値を入力してください。';
      });
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      final response = await http.patch(
        Uri.parse('http://127.0.0.1:8000/profiles/me'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'age': age,
          'gender': gender,
          'height_cm': height,
          'weight_kg': weight,
          'activity_level': activityLevel,
          'goal': goal,
        }),
      );

      if (!mounted) return;

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          errorMessage =
              '更新失敗：${response.statusCode}\n${response.body}';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = '通信エラー：$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール編集'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextField(
                controller: ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '年齢',
                  suffixText: '歳',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: gender,
                decoration: const InputDecoration(
                  labelText: '性別',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'male',
                    child: Text('男性'),
                  ),
                  DropdownMenuItem(
                    value: 'female',
                    child: Text('女性'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => gender = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: heightController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '身長',
                  suffixText: 'cm',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: weightController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '体重',
                  suffixText: 'kg',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: activityLevel,
                decoration: const InputDecoration(
                  labelText: '活動レベル',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'sedentary',
                    child: Text('低い'),
                  ),
                  DropdownMenuItem(
                    value: 'light',
                    child: Text('やや低い'),
                  ),
                  DropdownMenuItem(
                    value: 'moderate',
                    child: Text('普通'),
                  ),
                  DropdownMenuItem(
                    value: 'active',
                    child: Text('高い'),
                  ),
                  DropdownMenuItem(
                    value: 'very_active',
                    child: Text('非常に高い'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => activityLevel = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: goal,
                decoration: const InputDecoration(
                  labelText: '目標',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'lose',
                    child: Text('減量'),
                  ),
                  DropdownMenuItem(
                    value: 'maintain',
                    child: Text('維持'),
                  ),
                  DropdownMenuItem(
                    value: 'gain',
                    child: Text('増量'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => goal = value);
                  }
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isSaving ? null : saveProfile,
                child: Text(isSaving ? '保存中...' : '変更を保存'),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class FoodListPage extends StatefulWidget {
  final String token;

  const FoodListPage({
    super.key,
    required this.token,
  });

  @override
  State<FoodListPage> createState() => _FoodListPageState();
}

class _FoodListPageState extends State<FoodListPage> {
  List<Map<String, dynamic>> foods = [];
  String searchQuery = '';
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchFoods();
  }

  Future<void> fetchFoods() async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/foods'),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        setState(() {
          foods = data
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          isLoading = false;
          errorMessage = null;
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = '食品一覧の取得に失敗しました：${response.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = '通信エラー：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredFoods = foods.where((food) {
      final name = food['name'].toString().toLowerCase();
      return name.contains(searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              labelText: '食品を検索',
              hintText: '例：鶏むね肉',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                searchQuery = value.trim();
              });
            },
          ),
        ),
        Expanded(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : errorMessage != null
                  ? Center(
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                  : filteredFoods.isEmpty
                      ? const Center(
                          child: Text('該当する食品がありません'),
                        )
                      : ListView.builder(
                          itemCount: filteredFoods.length,
                          itemBuilder: (context, index) {
                            final food = filteredFoods[index];

                            final calories = food['calories'];
                            final protein = food['protein'];
                            final fat = food['fat'];
                            final carbohydrate = food['carbohydrate'];

                            return InkWell(
  onTap: () async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => MealRecordCreatePage(
          token: widget.token,
          food: food,
        ),
      ),
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('食事を登録しました'),
        ),
      );
    }
  },
  child: Card(
    margin: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 6,
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            food['name'].toString(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text('カロリー：$calories kcal'),
          const SizedBox(height: 4),
          Text(
            'P：$protein g  '
            'F：$fat g  '
            'C：$carbohydrate g',
          ),
        ],
      ),
    ),
  ),
);
                          },
                        ),
        ),
      ],
    );
  }
}

class MealRecordCreatePage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> food;

  const MealRecordCreatePage({
    super.key,
    required this.token,
    required this.food,
  });

  @override
  State<MealRecordCreatePage> createState() =>
      _MealRecordCreatePageState();
}

class _MealRecordCreatePageState extends State<MealRecordCreatePage> {
  final amountController = TextEditingController(text: '100');

  DateTime selectedDate = DateTime.now();
  String mealType = 'breakfast';

  bool isSaving = false;
  String? errorMessage;

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  Future<void> selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (date != null) {
      setState(() {
        selectedDate = date;
      });
    }
  }

  Future<void> saveMealRecord() async {
    final amount = double.tryParse(amountController.text.trim());

    if (amount == null || !amount.isFinite || amount <= 0) {
      setState(() {
        errorMessage = '摂取量には0より大きい数値を入力してください。';
      });
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    final dateString =
        '${selectedDate.year.toString().padLeft(4, '0')}-'
        '${selectedDate.month.toString().padLeft(2, '0')}-'
        '${selectedDate.day.toString().padLeft(2, '0')}';

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/meal-records'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'food_id': widget.food['id'],
          'meal_date': dateString,
          'meal_type': mealType,
          'amount_g': amount,
        }),
      );

      if (!mounted) return;

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          errorMessage =
              '登録失敗：${response.statusCode}\n${response.body}';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = '通信エラー：$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final foodName = widget.food['name'].toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('食事を記録'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                foodName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                title: const Text('食事日'),
                subtitle: Text(dateStringForDisplay(selectedDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: selectDate,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: mealType,
                decoration: const InputDecoration(
                  labelText: '食事区分',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'breakfast',
                    child: Text('朝食'),
                  ),
                  DropdownMenuItem(
                    value: 'lunch',
                    child: Text('昼食'),
                  ),
                  DropdownMenuItem(
                    value: 'dinner',
                    child: Text('夕食'),
                  ),
                  DropdownMenuItem(
                    value: 'snack',
                    child: Text('間食'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => mealType = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '摂取量',
                  suffixText: 'g',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isSaving ? null : saveMealRecord,
                child: Text(isSaving ? '登録中...' : '食事を登録'),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String dateStringForDisplay(DateTime date) {
  return '${date.year}年${date.month}月${date.day}日';
}

class MealHistoryPage extends StatefulWidget {
  final String token;

  const MealHistoryPage({
    super.key,
    required this.token,
  });

  @override
  State<MealHistoryPage> createState() => _MealHistoryPageState();
}

class _MealHistoryPageState extends State<MealHistoryPage> {
  List<Map<String, dynamic>> records = [];
  bool isLoading = true;
  String? errorMessage;
  int? deletingId;

  @override
  void initState() {
    super.initState();
    fetchRecords();
  }

  Future<void> fetchRecords() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/meal-records'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        setState(() {
          records = data
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = '取得失敗：${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = '通信エラー：$e';
        isLoading = false;
      });
    }
  }

  Future<void> deleteRecord(int recordId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('食事記録を削除'),
        content: const Text('この食事記録を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      deletingId = recordId;
    });

    try {
      final response = await http.delete(
        Uri.parse('http://127.0.0.1:8000/meal-records/$recordId'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (!mounted) return;

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        await fetchRecords();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('食事記録を削除しました'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('削除失敗：${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('通信エラー：$e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          deletingId = null;
        });
      }
    }
  }

  String mealTypeLabel(String value) {
    switch (value) {
      case 'breakfast':
        return '朝食';
      case 'lunch':
        return '昼食';
      case 'dinner':
        return '夕食';
      case 'snack':
        return '間食';
      default:
        return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Text(errorMessage!),
      );
    }

    if (records.isEmpty) {
      return const Center(
        child: Text('食事記録がありません'),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchRecords,
      child: ListView.builder(
        itemCount: records.length,
        itemBuilder: (context, index) {
          final record = records[index];
          final id = record['id'] as int;

          return Card(
            margin: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            child: ListTile(
              title: Text(record['food_name'].toString()),
              subtitle: Text(
                '${record['meal_date']} ・ '
                '${mealTypeLabel(record['meal_type'].toString())}\n'
                '${record['amount_g']}g ・ '
                '${record['calories']} kcal\n'
                'P：${record['protein']}g  '
                'F：${record['fat']}g  '
                'C：${record['carbohydrate']}g',
              ),
              isThreeLine: true,
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: deletingId != null
                    ? null
                    : () => deleteRecord(id),
              ),
            ),
          );
        },
      ),
    );
  }
}

class MealPage extends StatefulWidget {
  final String token;

  const MealPage({
    super.key,
    required this.token,
  });

  @override
  State<MealPage> createState() => _MealPageState();
}

class _MealPageState extends State<MealPage> {
  int selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('食品を探す'),
                icon: Icon(Icons.search),
              ),
              ButtonSegment(
                value: 1,
                label: Text('食事履歴'),
                icon: Icon(Icons.history),
              ),
            ],
            selected: {selectedTab},
            onSelectionChanged: (selection) {
              setState(() {
                selectedTab = selection.first;
              });
            },
          ),
        ),
        Expanded(
          child: selectedTab == 0
              ? FoodListPage(token: widget.token)
              : MealHistoryPage(token: widget.token),
        ),
      ],
    );
  }
}