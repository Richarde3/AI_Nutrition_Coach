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
      body: selectedIndex == 3
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