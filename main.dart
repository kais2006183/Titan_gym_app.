import 'package:flutter/material.dart';
import 'dart:convert'; // 👈 ضروري لتحويل البيانات إلى JSON للحفظ الآمن
import 'package:shared_preferences/shared_preferences.dart'; // 👈 استدعاء حزمة حفظ البيانات

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TitanGymApp());
}

// 🏛️ كلاس نموذج بيانات اللاعب
class Player {
  final String id;
  String name;        
  String phone;       
  String status;      
  String paymentStatus; 
  DateTime lastPaymentDate; 
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

// 📜 كلاس سجل المدفوعات التاريخي (مربوط بـ ID اللاعب لمنع تداخل الحسابات نهائياً)
class PaymentLog {
  String id; 
  String playerId; // 👈 لربط السجل باللاعب بشكل فريد لا يقبل الخطأ والتداخل
  String playerName;
  DateTime date; 
  String amount;
  int paidAmount;       
  int remainingAmount;  

  PaymentLog({
    required this.id,
    required this.playerId,
    required this.playerName,
    required this.date,
    required this.amount,
    required this.paidAmount,
    required this.remainingAmount,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'playerId': playerId,
      'playerName': playerName,
      'date': date.toIso8601String(),
      'amount': amount,
      'paidAmount': paidAmount,
      'remainingAmount': remainingAmount,
    };
  }

  factory PaymentLog.fromJson(Map<String, dynamic> json) {
    return PaymentLog(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      playerId: json['playerId'] ?? '', // أمان الجرد والنسخ السابقة
      playerName: json['playerName'],
      date: DateTime.parse(json['date']),
      amount: json['amount'],
      paidAmount: json['paidAmount'] ?? 100000,
      remainingAmount: json['remainingAmount'] ?? 0,
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
      home: const SplashScreen(), 
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
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
      backgroundColor: Color(0xFF121212),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, size: 80, color: Colors.amber),
            SizedBox(height: 20),
            Text(
              'TITAN',
              style: TextStyle(
                fontSize: 45,
                fontWeight: FontWeight.w900,
                color: Colors.amber,
                letterSpacing: 8,
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
    _loadDataFromStorage();
  }

  // 💾 دالة حفظ البيانات في ذاكرة الجهاز الأمنية
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

  // 🔔 دالة الفحص والتحويل الآلي للدورات الجديدة بعد انتهاء 30 يوماً
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
                      _saveDataToStorage();
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

  // 📜 السجل التاريخي للجرد (تم تحديث تصميمه بالكامل ليدعم شاشات الموبايل بنسبة 100%)
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
                    Text('📜 سجل المقبوضات التاريخي بالجرد', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                content: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.95, // 👈 متوافق تماماً مع الموبايل
                  height: 350,
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
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                title: Row(
                                  children: [
                                    Expanded( // 👈 يمنع التداخل ويقص الاسم الطويل بأدب
                                      child: Text(
                                        log.playerName, 
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isOldLog) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4)),
                                        child: const Text('قديم ⚠️', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                      ),
                                    ]
                                  ],
                                ),
                                subtitle: Column( // 👈 ترتيب عمودي لحفظ المساحة الأفقية بالموبايل
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('📅 التاريخ: $formattedDate', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                                    const SizedBox(height: 4),
                                    Text(
                                      log.amount, 
                                      style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ],
                                ),
                                trailing: IconButton( // 👈 أيقونة الحذف معزولة باليسار دون تداخل
                                  icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 24),
                                  onPressed: () {
                                    setState(() {
                                      setModalState(() {
                                        _globalPaymentLogs.removeAt(idx);
                                      });
                                      _saveDataToStorage();
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('🗑️ تم إزالة السجل المالي الخاطئ بنجاح!'), duration: Duration(milliseconds: 800)),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق ورجوع', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold))),
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
                                  color: notif.isRead ? Colors.grey.withOpacity(0.05) : Colors.amber.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: notif.isRead ? Colors.grey.withOpacity(0.2) : Colors.amber.withOpacity(0.3)),
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
                            border: Border.all(color: Colors.amber.withOpacity(0.2)),
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
                              const Text('المصمم والمطور الرئيسي: المبرمج قيس عزام', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13)),
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
                          _saveDataToStorage();
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

    // 🔍 البحث عن وجود دفعة غير مكتملة (ذمة متبقية) لهذا اللاعب بالـ ID الفريد لمنع تداخل الأسماء نهائياً
    PaymentLog? activePendingLog;
    try {
      activePendingLog = _globalPaymentLogs.lastWhere(
        (log) => log.playerId == player.id && log.remainingAmount > 0
      );
    } catch (_) {
      activePendingLog = null;
    }

    // متغيرات لحفظ حالة الدفع المؤقتة
    String finalRecordedLogAmount = _formatMoney(_currentSubscriptionFee);
    int tempPaidVal = _currentSubscriptionFee;
    int tempRemainingVal = 0;
    bool isUpdateLogOperation = false;

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
                
                // 💵 أولاً: التحقق من تحديث السجل المالي بدقة متناهية
                if (isUpdateLogOperation && activePendingLog != null) {
                  int logIndex = _globalPaymentLogs.indexWhere((l) => l.id == activePendingLog!.id);
                  if (logIndex != -1) {
                    _globalPaymentLogs[logIndex] = PaymentLog(
                      id: activePendingLog.id,
                      playerId: player.id,
                      playerName: player.name,
                      date: DateTime.now(), // تحديث تاريخ الحركة الأخيرة
                      amount: finalRecordedLogAmount,
                      paidAmount: tempPaidVal,
                      remainingAmount: tempRemainingVal,
                    );
                  }
                } 
                // ثانياً: تسجيل دفعة جديدة لأول مرة
                else if (currentPayment == 'تم الدفع' && player.paymentStatus == 'لم يتم الدفع') {
                  _globalPaymentLogs.add(PaymentLog(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    playerId: player.id,
                    playerName: player.name,
                    date: DateTime.now(), 
                    amount: finalRecordedLogAmount,
                    paidAmount: tempPaidVal,
                    remainingAmount: tempRemainingVal,
                  ));
                }
                
                player.paymentStatus = currentPayment;

                for (var day in days) {
                  player.program[day] = programControllers[day]!.text.trim();
                }
                
                _checkExpiringMembers(); 
                _saveDataToStorage();
              });
              Navigator.pop(context); 
            }

            // 💵 الدالة المنبثقة الأولى لتحصيل دفعة أولى جديدة (مثال: دفع 75 الف وباقي 25 الف)
            void _promptInitialPaymentDialog() {
              final paidAmountController = TextEditingController(text: _currentSubscriptionFee.toString());
              int paidAmount = _currentSubscriptionFee;
              int remainingAmount = 0;

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (paymentContext) {
                  return StatefulBuilder(
                    builder: (paymentContext, setPaymentState) {
                      return Directionality(
                        textDirection: TextDirection.rtl,
                        child: AlertDialog(
                          backgroundColor: const Color(0xFF1E1E1E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.green)),
                          title: const Row(
                            children: [
                              Icon(Icons.payment, color: Colors.green),
                              SizedBox(width: 8),
                              Text('تفاصيل تحصيل الدفعة الماليّة الجديدة', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('قيمة الاشتراك الشهري المعتمد: ${_formatMoney(_currentSubscriptionFee)}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              const SizedBox(height: 15),
                              TextField(
                                controller: paidAmountController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'المبلغ المدفوع حالياً',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  suffixText: 'ل.س',
                                ),
                                onChanged: (value) {
                                  setPaymentState(() {
                                    int enteredAmount = int.tryParse(value) ?? 0;
                                    paidAmount = enteredAmount;
                                    remainingAmount = _currentSubscriptionFee - enteredAmount;
                                    if (remainingAmount < 0) remainingAmount = 0;
                                  });
                                },
                              ),
                              const SizedBox(height: 15),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: remainingAmount > 0 ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: remainingAmount > 0 ? Colors.red : Colors.green, width: 0.5),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('المبلغ المتبقي بذمة اللاعب:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    Text(
                                      _formatMoney(remainingAmount), 
                                      style: TextStyle(
                                        color: remainingAmount > 0 ? Colors.redAccent : Colors.greenAccent, 
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(paymentContext);
                                setDialogState(() {
                                  currentPayment = 'لم يتم الدفع';
                                });
                              },
                              child: const Text('إلغاء', style: TextStyle(color: Colors.white60)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.black),
                              onPressed: () {
                                setDialogState(() {
                                  tempPaidVal = paidAmount;
                                  tempRemainingVal = remainingAmount;
                                  isUpdateLogOperation = false;

                                  if (remainingAmount > 0) {
                                    finalRecordedLogAmount = "المدفوع: ${_formatMoney(paidAmount)} (المتبقي: ${_formatMoney(remainingAmount)})";
                                  } else {
                                    finalRecordedLogAmount = _formatMoney(paidAmount);
                                  }
                                });
                                Navigator.pop(paymentContext);
                              },
                              child: const Text('تأكيد الدفعة', style: TextStyle(fontWeight: FontWeight.bold)),
                            )
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            }

            // 💵 الدالة المنبثقة الثانية لتسجيل واستكمال الدفعة المتبقية (مثال: دفع 25 الف المتبقية)
            void _promptDebtCompletionDialog() {
              if (activePendingLog == null) return;

              final extraPaidController = TextEditingController();
              int extraPaid = 0;
              int newPaidTotal = activePendingLog.paidAmount;
              int newRemaining = activePendingLog.remainingAmount;

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (completionContext) {
                  return StatefulBuilder(
                    builder: (completionContext, setCompletionState) {
                      return Directionality(
                        textDirection: TextDirection.rtl,
                        child: AlertDialog(
                          backgroundColor: const Color(0xFF1E1E1E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.amber)),
                          title: const Row(
                            children: [
                              Icon(Icons.payment, color: Colors.amber),
                              SizedBox(width: 8),
                              Text('استكمال دفعة اللاعب المالية', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('الحالة الحالية بالسجلات:', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text('• المدفوع سابقاً: ${_formatMoney(activePendingLog!.paidAmount)}', style: const TextStyle(fontSize: 13, color: Colors.white70)),
                              Text('• الذمة المتبقية الحالية: ${_formatMoney(activePendingLog!.remainingAmount)}', style: const TextStyle(fontSize: 13, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                              const Divider(color: Colors.amber, height: 20),
                              TextField(
                                controller: extraPaidController,
                                keyboardType: TextInputType.number,
                                autofocus: true,
                                decoration: const InputDecoration(
                                  labelText: 'أدخل المبلغ المدفوع الآن لاستكمال الذمة',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  suffixText: 'ل.س',
                                ),
                                onChanged: (value) {
                                  setCompletionState(() {
                                    extraPaid = int.tryParse(value) ?? 0;
                                    
                                    // منع تجاوز الدفع عن الحد المتبقي لمنع الأخطاء الحسابية
                                    if (extraPaid > activePendingLog!.remainingAmount) {
                                      extraPaid = activePendingLog!.remainingAmount;
                                      extraPaidController.text = extraPaid.toString();
                                      extraPaidController.selection = TextSelection.fromPosition(TextPosition(offset: extraPaidController.text.length));
                                    }

                                    newPaidTotal = activePendingLog!.paidAmount + extraPaid;
                                    newRemaining = activePendingLog!.remainingAmount - extraPaid;
                                  });
                                },
                              ),
                              const SizedBox(height: 15),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: newRemaining > 0 ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: newRemaining > 0 ? Colors.red : Colors.green, width: 0.5),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('المدفوع الإجمالي الجديد:', style: TextStyle(fontSize: 12, color: Colors.white60)),
                                        Text(_formatMoney(newPaidTotal), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('الذمة المتبقية الجديدة:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                        Text(
                                          _formatMoney(newRemaining), 
                                          style: TextStyle(
                                            color: newRemaining > 0 ? Colors.redAccent : Colors.greenAccent, 
                                            fontWeight: FontWeight.bold, 
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(completionContext),
                              child: const Text('إلغاء', style: TextStyle(color: Colors.white60)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                              onPressed: () {
                                setDialogState(() {
                                  tempPaidVal = newPaidTotal;
                                  tempRemainingVal = newRemaining;
                                  isUpdateLogOperation = true;

                                  if (newRemaining > 0) {
                                    finalRecordedLogAmount = "المدفوع: ${_formatMoney(newPaidTotal)} (المتبقي: ${_formatMoney(newRemaining)})";
                                  } else {
                                    // ⚡️ تعديل السجل ليصبح مكتمل بالكامل ومتبقي 0
                                    finalRecordedLogAmount = "${_formatMoney(newPaidTotal)} (تم استكمال الدفعة - متبقي 0)";
                                  }
                                });
                                Navigator.pop(completionContext);
                              },
                              child: const Text('تأكيد التعديل وتحديث السجل', style: TextStyle(fontWeight: FontWeight.bold)),
                            )
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            }

            void handleAttemptToClose() {
              if (checkHasChanges() || isUpdateLogOperation) {
                showDialog(
                  context: context,
                  builder: (subContext) => Directionality(
                    textDirection: TextDirection.rtl,
                    child: AlertDialog(
                      backgroundColor: const Color(0xFF1C1A1A),
                      title: const Text('⚠️ تعديلات غير محفوظة', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                      content: const Text('لقد قمت بتغيير بعض البيانات أو الجداول الماليّة، هل تريد حفظ التعديلات قبل الخروج؟'),
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
                                  value: currentPayment,
                                  decoration: const InputDecoration(labelText: 'حالة الاشتراك الدورية', border: OutlineInputBorder()),
                                  items: ['تم الدفع', 'لم يتم الدفع'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                  onChanged: (val) {
                                    setDialogState(() {
                                      currentPayment = val!;
                                      if (currentPayment == 'تم الدفع' && activePendingLog == null) {
                                        _promptInitialPaymentDialog();
                                      }
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),

                          // 💡 زر تحديث واستكمال الدفعة المتبقية
                          if (activePendingLog != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.red.withOpacity(0.5), width: 1),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                                      const SizedBox(width: 6),
                                      Text(
                                        'ذمة مالية متبقية: ${_formatMoney(activePendingLog.remainingAmount)}',
                                        style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'اضغط على الزر أدناه لتسجيل الدفع الجديد وتحديث السجل تلقائياً.',
                                    style: TextStyle(fontSize: 11, color: Colors.white70),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 40,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.amber, 
                                        foregroundColor: Colors.black,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.monetization_on, size: 18),
                                      label: const Text('إدخال المبلغ المتبقي وتعديل السجل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      onPressed: _promptDebtCompletionDialog,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 15),
                          ],
                          
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
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.2), foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                              icon: const Icon(Icons.delete_forever),
                              label: const Text('🗑️ حذف هذا اللاعب نهائياً من النادي'),
                              onPressed: () {
                                setState(() {
                                  _members.removeWhere((m) => m.id == player.id);
                                  _saveDataToStorage();
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
                decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withOpacity(0.3))),
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
                                    color: player.daysLeft <= 5 ? Colors.red.withOpacity(0.2) : Colors.amber.withOpacity(0.1),
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
                              decoration: BoxDecoration(color: payColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: payColor)),
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