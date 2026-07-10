import 'package:flutter/material.dart';
import 'dart:convert'; // 👈 ضروري لتحويل البيانات إلى JSON
import 'package:shared_preferences/shared_preferences.dart'; // 👈 استدعاء حزمة الحفظ

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TitanGymApp());
}

// 🏛️ كلاس نموذج بيانات اللاعب (التوقيت الحقيقي)
class Player {
  final String id;
  String name;        // قابلة للتعديل داخل الواجهات
  String phone;       // قابلة للتعديل داخل الواجهات
  String status;      // قابلة للتعديل داخل الواجهات
  String paymentStatus; // قابلة للتعديل داخل الواجهات
  DateTime lastPaymentDate; // قابلة للتعديل داخل الواجهات
  final Map<String, String> program;

  Player({
    required this.id,
    required this.name,
    required this.phone,
    required this.status,
    required this.paymentStatus,
    required this.lastPaymentDate,
    required this.program,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'status': status,
      'paymentStatus': paymentStatus,
      'lastPaymentDate': lastPaymentDate.toIso8601String(),
      'program': program,
    };
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      status: json['status'],
      paymentStatus: json['paymentStatus'],
      lastPaymentDate: DateTime.parse(json['lastPaymentDate']),
      program: Map<String, String>.from(json['program'] ?? {}),
    );
  }

  int get daysLeft {
    int daysPassed = DateTime.now().difference(lastPaymentDate).inDays;
    int remainder = 30 - (daysPassed % 30);
    return remainder;
  }
}

// 🔔 كلاس نموذج التنبيهات
class GymNotification {
  String id;
  String message;
  bool isRead; 

  GymNotification({
    required this.id,
    required this.message,
    this.isRead = false,
  });
}

// 📜 كلاس سجل المدفوعات التاريخي
class PaymentLog {
  String playerName;
  DateTime date; 
  String amount;

  PaymentLog({required this.playerName, required this.date, required this.amount});

  Map<String, dynamic> toJson() {
    return {
      'playerName': playerName,
      'date': date.toIso8601String(),
      'amount': amount,
    };
  }

  factory PaymentLog.fromJson(Map<String, dynamic> json) {
    return PaymentLog(
      playerName: json['playerName'],
      date: DateTime.parse(json['date']),
      amount: json['amount'],
    );
  }
}

class TitanGymApp extends StatelessWidget {
  const TitanGymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.amber,
      ),
      // 👈 جعلنا التطبيق يبدأ من شاشة الترحيب الرائعة
      home: const SplashScreen(), 
    );
  }
}

// 🔔 شاشة الترحيب (Splash Screen) المضافة
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // مؤقت زمني يظهر كلمة TITAN لمدة 3 ثوانٍ ثم ينتقل تلقائياً للشاشة الرئيسية
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainDashboard()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF121212), // متناسق مع اللون العام للتطبيق
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, size: 80, color: Colors.amber), // أيقونة رياضية
            SizedBox(height: 20),
            Text(
              'TITAN',
              style: TextStyle(
                fontSize: 45,
                fontWeight: FontWeight.w900,
                color: Colors.amber,
                letterSpacing: 8, // تباعد فخم للحروف
              ),
            ),
            SizedBox(height: 10),
            Text(
              'GYM MANAGER',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white38,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  // المتغيرات الأساسية المعرفة بشكل نظيف بداخل كلاس الـ State
  int _currentSubscriptionFee = 100000; 
  String _searchQuery = "";
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  final List<Player> _members = [];
  final List<PaymentLog> _globalPaymentLogs = [];
  final List<GymNotification> _expiryNotifications = [];

  @override
  void initState() {
    super.initState();
    _loadDataFromStorage(); // تحميل فوري ومستقر عند فتح الواجهة الرئيسية
  }

  // 💾 دالة حفظ البيانات في ذاكرة الجهاز
  Future<void> _saveDataToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      String membersJson = jsonEncode(_members.map((m) => m.toJson()).toList());
      String logsJson = jsonEncode(_globalPaymentLogs.map((l) => l.toJson()).toList());
      
      await prefs.setString('titan_members', membersJson);
      await prefs.setString('titan_logs', logsJson);
      await prefs.setInt('titan_fee', _currentSubscriptionFee);
    } catch (e) {
      debugPrint("خطأ أثناء حفظ البيانات: $e");
    }
  }

  // 📖 دالة تحميل البيانات عند فتح التطبيق
  Future<void> _loadDataFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final String? membersRaw = prefs.getString('titan_members');
      final String? logsRaw = prefs.getString('titan_logs');
      final int? savedFee = prefs.getInt('titan_fee');

      setState(() {
        if (savedFee != null) {
          _currentSubscriptionFee = savedFee;
        }
        
        if (membersRaw != null && membersRaw.isNotEmpty) {
          final List decoded = jsonDecode(membersRaw);
          _members.clear();
          _members.addAll(decoded.map((m) => Player.fromJson(m)).toList());
        }
        
        if (logsRaw != null && logsRaw.isNotEmpty) {
          final List decoded = jsonDecode(logsRaw);
          _globalPaymentLogs.clear();
          _globalPaymentLogs.addAll(decoded.map((l) => PaymentLog.fromJson(l)).toList());
        }
        
        _checkExpiringMembers();
      });
    } catch (e) {
      debugPrint("خطأ أثناء تحميل البيانات: $e");
    }
  }

  // 🔔 دالة الفحص والتحويل الآلي للدورات الجديدة
  void _checkExpiringMembers() {
    DateTime now = DateTime.now();
    bool hasChanges = false;

    for (var member in _members) {
      int daysPassed = now.difference(member.lastPaymentDate).inDays;
      
      if (daysPassed >= 30) {
        int chunksOf30Days = daysPassed ~/ 30;
        
        member.lastPaymentDate = member.lastPaymentDate.add(Duration(days: chunksOf30Days * 30));
        member.paymentStatus = 'لم يتم الدفع';
        hasChanges = true;
        
        String notifId = "${member.id}-${DateTime.now().millisecondsSinceEpoch}";
        _expiryNotifications.add(GymNotification(
          id: notifId,
          message: "⚠️ انتهى شهر اللاعب [ ${member.name} ]. تم تدوير العداد تلقائياً لـ 30 يوماً وبانتظار تحصيل مال الدورة الجديدة.",
          isRead: false, 
        ));
      }
    }
    if (hasChanges) {
      _saveDataToStorage();
    }
  }

  String _formatMoney(int amount) {
    return "${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} ل.س";
  }

  void _showAddMemberDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.amber)),
            title: const Text('➕ إضافة لاعب جديد في TITAN', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم اللاعب الجديد', prefixIcon: Icon(Icons.person, color: Colors.amber))),
                const SizedBox(height: 10),
                TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone, color: Colors.amber))),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.white60))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                onPressed: () {
                  if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
                    setState(() {
                      _members.add(Player(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameController.text.trim(),
                        phone: phoneController.text.trim(),
                        status: 'نشط',
                        paymentStatus: 'لم يتم الدفع',
                        lastPaymentDate: DateTime.now(), 
                        program: {},
                      ));
                      _saveDataToStorage(); // حفظ فوري ومستقر بعد الإضافة
                    });
                    Navigator.pop(context);
                  }
                },
                child: const Text('حفظ اللاعب', style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      },
    );
  }

  void _showPaymentLogsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: const Color(0xFF161616),
                title: const Row(
                  children: [
                    Icon(Icons.receipt_long, color: Colors.green),
                    SizedBox(width: 10),
                    Text('📜 سجل المقبوضات التاريخي بالجرد', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
                content: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.85,
                  height: 300,
                  child: _globalPaymentLogs.isEmpty
                      ? const Center(child: Text('السجل فارغ تماماً حتى الآن.', style: TextStyle(color: Colors.white38)))
                      : ListView.builder(
                          itemCount: _globalPaymentLogs.length,
                          itemBuilder: (context, idx) {
                            final log = _globalPaymentLogs[idx];
                            final int logAgeInDays = DateTime.now().difference(log.date).inDays;
                            final bool isOldLog = logAgeInDays > 30;
                            final String formattedDate = "${log.date.year}-${log.date.month.toString().padLeft(2, '0')}-${log.date.day.toString().padLeft(2, '0')}";

                            return Card(
                              color: const Color(0xFF222222),
                              child: ListTile(
                                title: Row(
                                  children: [
                                    Text(log.playerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    if (isOldLog) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4)),
                                        child: const Text('قديم ⚠️', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                      ),
                                    ]
                                  ],
                                ),
                                subtitle: Text('📅 التاريخ: $formattedDate'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(log.amount, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                                      onPressed: () {
                                        setState(() {
                                          setModalState(() {
                                            _globalPaymentLogs.removeAt(idx);
                                          });
                                          _saveDataToStorage(); // حفظ التعديل بعد الحذف المالي
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('🗑️ تم إزالة السجل المالي الخاطئ بنجاح!'), duration: Duration(milliseconds: 800)),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق ورجوع', style: TextStyle(color: Colors.amber))),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: const Color(0xFF1C1A1A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.amber, width: 0.5)),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notifications_active, color: Colors.amber),
                        const SizedBox(width: 10),
                        Text('مركز تنبيهات TITAN (${_expiryNotifications.length})', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  ],
                ),
                content: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.85,
                  height: 300,
                  child: _expiryNotifications.isEmpty
                      ? const Center(child: Text('جرس الإشعارات فارغ حالياً! 👍', style: TextStyle(color: Colors.white54)))
                      : ListView.builder(
                          itemCount: _expiryNotifications.length,
                          itemBuilder: (context, idx) {
                            final notif = _expiryNotifications[idx];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: notif.isRead ? Colors.grey.withValues(alpha: 0.05) : Colors.amber.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: notif.isRead ? Colors.grey.withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: notif.isRead ? Colors.grey.shade700 : Colors.red.shade900,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            notif.isRead ? "مقروء" : "غير مقروء",
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                        ),
                                        const Icon(Icons.circle, size: 8, color: Colors.amber),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(notif.message, style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.3)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                    onPressed: () {
                      setState(() {
                        for (var notif in _expiryNotifications) {
                          notif.isRead = true;
                        }
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('تمت المراجعة وقراءة الكل', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSettingsDialog() {
    final feeController = TextEditingController(text: _currentSubscriptionFee.toString());

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSettingsState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: const Color(0xFF161616),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.amber)),
                title: const Row(
                  children: [
                    Icon(Icons.settings, color: Colors.amber),
                    SizedBox(width: 10),
                    Text('⚙️ إعدادات النظام والمعلومات', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                  ],
                ),
                content: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.85,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('💰 تعديل قيمة الاشتراك الشهري للنادي:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: feeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                            suffixText: 'ل.س',
                            prefixIcon: Icon(Icons.money, color: Colors.green),
                          ),
                        ),
                        const SizedBox(height: 25),
                        
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF222222),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.amber, size: 20),
                                  SizedBox(width: 6),
                                  Text('حول النظام والملكية الفكرية', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 14)),
                                ],
                              ),
                              const Divider(color: Colors.amber, height: 15),
                              const Text('اسم النظام: TITAN GYM MANAGER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 4),
                              const Text('المصمم والمطور الرئيسي: المبرمج قيس عزام', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13)), // تم الالتزام بتعديل اللقب قيس عزام
                              const SizedBox(height: 8),
                              Text(
                                'الشرح التفصيلي:\nهو نظام تفاعلي متكامل ومصمم خصيصاً لإدارة الصالات الرياضية والنوادي الاحترافية. يتيح للكوتش تتبع ملفات اللاعبين، فرز النشطين، صياغة البرامج الرياضية الأسبوعية لكل بطل بشكل مرن عبر نصوص تلميحية مهمشة، وحماية الجرد المحاسبي عبر سجل مقبوضات تاريخي مستقل باليوم والسنة. كما يتضمن نظام حماية ذكي يفحص تلقائياً مرور 30 يوماً على الاشتراكات لقلب الحالة وضمان الحقوق المالية.',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade400, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                    onPressed: () {
                      if (feeController.text.isNotEmpty) {
                        setState(() {
                          _currentSubscriptionFee = int.parse(feeController.text.trim());
                          _saveDataToStorage(); // حفظ القيمة الجديدة بالذاكرة
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('💰 تم تحديث قيمة الاشتراك إلى: ${_formatMoney(_currentSubscriptionFee)}')));
                      }
                    },
                    child: const Text('حفظ الإعدادات', style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showMemberDetailsDialog(Player player) {
    String currentStatus = player.status;
    String currentPayment = player.paymentStatus;
    
    final editNameController = TextEditingController(text: player.name);
    final editPhoneController = TextEditingController(text: player.phone);

    final days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    Map<String, TextEditingController> programControllers = {};
    for (var day in days) {
      programControllers[day] = TextEditingController(text: player.program[day] ?? '');
    }

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            
            bool checkHasChanges() {
              if (editNameController.text.trim() != player.name) return true;
              if (editPhoneController.text.trim() != player.phone) return true;
              if (currentStatus != player.status) return true;
              if (currentPayment != player.paymentStatus) return true;
              for (var day in days) {
                if (programControllers[day]!.text.trim() != (player.program[day] ?? '')) {
                  return true;
                }
              }
              return false;
            }

            void executeSaveAction() {
              setState(() {
                player.name = editNameController.text.trim();
                player.phone = editPhoneController.text.trim();
                player.status = currentStatus;
                
                if (currentPayment == 'تم الدفع' && player.paymentStatus == 'لم يتم الدفع') {
                  _globalPaymentLogs.add(PaymentLog(
                    playerName: player.name,
                    date: DateTime.now(), 
                    amount: _formatMoney(_currentSubscriptionFee),
                  ));
                }
                
                player.paymentStatus = currentPayment;

                for (var day in days) {
                  player.program[day] = programControllers[day]!.text.trim();
                }
                
                _checkExpiringMembers(); 
                _saveDataToStorage(); // حفظ فوري بعد الحفظ بالتعديل
              });
              Navigator.pop(context); 
            }

            void handleAttemptToClose() {
              if (checkHasChanges()) {
                showDialog(
                  context: context,
                  builder: (subContext) => Directionality(
                    textDirection: TextDirection.rtl,
                    child: AlertDialog(
                      backgroundColor: const Color(0xFF1C1A1A),
                      title: const Text('⚠️ تعديلات غير محفوظة', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                      content: const Text('لقد قمت بتغيير بعض البيانات أو الجداول، هل تريد حفظ التعديلات قبل الخروج؟'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(subContext); 
                            Navigator.pop(context);    
                          },
                          child: const Text('خروج بدون حفظ', style: TextStyle(color: Colors.redAccent)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                          onPressed: () {
                            Navigator.pop(subContext); 
                            executeSaveAction();       
                          },
                          child: const Text('نعم، حفظ التعديلات', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                Navigator.pop(context); 
              }
            }

            return PopScope(
              canPop: false, 
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) return;
                handleAttemptToClose(); 
              },
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: AlertDialog(
                  backgroundColor: const Color(0xFF161616),
                  insetPadding: const EdgeInsets.all(10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.amber, width: 1.5)),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('👤 إدارة الملف والبرنامج', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60), 
                        onPressed: handleAttemptToClose, 
                      ),
                    ],
                  ),
                  content: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.9,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(controller: editNameController, decoration: const InputDecoration(labelText: 'تعديل اسم اللاعب', prefixIcon: Icon(Icons.edit, color: Colors.amber))),
                          const SizedBox(height: 8),
                          TextField(controller: editPhoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'تعديل رقم الهاتف', prefixIcon: Icon(Icons.phone_android, color: Colors.amber))),
                          const SizedBox(height: 15),

                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: currentStatus,
                                  decoration: const InputDecoration(labelText: 'حالة الالتزام', border: OutlineInputBorder()),
                                  items: ['نشط', 'غير نشط'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                  onChanged: (val) => setDialogState(() => currentStatus = val!),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: currentPayment,
                                  decoration: const InputDecoration(labelText: 'حالة الاشتراك الدورية', border: OutlineInputBorder()),
                                  items: ['تم الدفع', 'لم يتم الدفع'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                  onChanged: (val) => setDialogState(() => currentPayment = val!),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          const Text('🏋️‍♂️ جدول التدريبات الأسبوعي للكابتن:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.amber)),
                          const Divider(color: Colors.amber),
                          ...days.map((day) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  SizedBox(width: 70, child: Text(day, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70))),
                                  Expanded(
                                    child: TextField(
                                      controller: programControllers[day],
                                      decoration: InputDecoration(
                                        isDense: true, 
                                        contentPadding: const EdgeInsets.all(8), 
                                        border: const OutlineInputBorder(),
                                        hintText: 'لم يحدد', 
                                        hintStyle: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 15),

                          const Divider(color: Colors.red),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withValues(alpha: 0.2), foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                              icon: const Icon(Icons.delete_forever),
                              label: const Text('🗑️ حذف هذا اللاعب نهائياً من النادي'),
                              onPressed: () {
                                setState(() {
                                  _members.removeWhere((m) => m.id == player.id);
                                  _saveDataToStorage(); // حفظ فوري بعد الحذف لتثبيت التعديل
                                });
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف اللاعب وإلغاء قيوده تماماً')));
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                      onPressed: executeSaveAction, 
                      child: const Text('حفظ كل التعديلات المذكورة', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredMembers = _members.where((m) {
      final name = m.name.toLowerCase();
      final phone = m.phone;
      return name.contains(_searchQuery.toLowerCase()) || phone.contains(_searchQuery);
    }).toList();

    int activeCount = _members.where((m) => m.status == 'نشط').length;
    int unreadNotificationsCount = _expiryNotifications.where((n) => !n.isRead).length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: _isSearching 
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: 'ابحث باسم البطل أو رقم تلفونه الحالي...', hintStyle: TextStyle(color: Colors.white54), border: InputBorder.none),
                onChanged: (val) => setState(() => _searchQuery = val),
              )
            : const Text('🏛️ نـادي TITAN الـريـاضـي', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
          centerTitle: true,
          backgroundColor: const Color(0xFF1A1A1A),
          elevation: 5,
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.clear : Icons.search, color: Colors.amber),
              onPressed: () {
                setState(() {
                  if (_isSearching) {
                    _isSearching = false;
                    _searchQuery = "";
                    _searchController.clear();
                  } else {
                    _isSearching = true;
                  }
                });
              },
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications, color: Colors.amber),
                  onPressed: _showNotificationsDialog,
                ),
                if (unreadNotificationsCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: Text(
                        '$unreadNotificationsCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
              ],
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.amber),
              onPressed: _showSettingsDialog,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withValues(alpha: 0.3))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text('👥 إجمالي المشتركين: ${_members.length}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Text('⚡ اللاعبين الملتزمين (النشطين): $activeCount', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.amber)),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12)),
                      onPressed: _showAddMemberDialog, 
                      icon: const Icon(Icons.person_add),
                      label: const Text('إضافة لاعب جديد', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1A1A), foregroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 12), side: const BorderSide(color: Colors.green, width: 0.5)),
                      onPressed: _showPaymentLogsDialog, 
                      icon: const Icon(Icons.folder_shared),
                      label: const Text('📜 سجل الجرد المالي', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              
              const Align(
                alignment: Alignment.centerRight,
                child: Text('👥 لوردات وأبطال النادي:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70)),
              ),
              const SizedBox(height: 10),
              
              Expanded(
                child: filteredMembers.isEmpty 
                  ? const Center(child: Text('لا يوجد نتائج متوافقة مع المدخلات!', style: TextStyle(color: Colors.white38)))
                  : ListView.builder(
                      itemCount: filteredMembers.length,
                      itemBuilder: (context, index) {
                        final player = filteredMembers[index];
                        Color payColor = player.paymentStatus == 'تم الدفع' ? Colors.green : Colors.red;
                        Color statusColor = player.status == 'نشط' ? Colors.amber : Colors.grey;

                        return Card(
                          color: const Color(0xFF1A1A1A),
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            onTap: () => _showMemberDetailsDialog(player), 
                            leading: CircleAvatar(backgroundColor: statusColor, child: const Icon(Icons.fitness_center, color: Colors.black)),
                            title: Row(
                              children: [
                                Text(player.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: player.daysLeft <= 5 ? Colors.red.withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: player.daysLeft <= 5 ? Colors.red : Colors.amber, width: 0.5)
                                  ),
                                  child: Text(
                                    "⏳ ${player.daysLeft} يوم متبقي",
                                    style: TextStyle(fontSize: 10, color: player.daysLeft <= 5 ? Colors.red : Colors.amber, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text('الهاتف: ${player.phone} \nالحالة: ${player.status}'),
                            isThreeLine: true,
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: payColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: payColor)),
                              child: Text(player.paymentStatus, style: TextStyle(color: payColor, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}