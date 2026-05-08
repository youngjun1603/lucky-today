import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/draw.dart';
import '../models/external_prize.dart';
import '../models/point_transaction.dart';
import '../models/coupon.dart';
import '../config/prize_config.dart';
import 'prize_service.dart';
import 'external_point_api_service.dart';

class DatabaseService {
  // 싱글톤 패턴
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();
  
  // 메모리 기반 저장소 (웹에서 더 안정적)
  static final Map<String, Map<String, dynamic>> _users = {};
  static final Map<String, Map<String, dynamic>> _draws = {};
  static final Map<String, Map<String, dynamic>> _prizes = {};
  static final Map<String, Map<String, dynamic>> _transactions = {};
  static final Map<String, Map<String, dynamic>> _coupons = {};
  static String? _currentUserId;
  
  static bool _isInitialized = false;

  // 시스템 설정
  static int _betPoint1 = 5;
  static int _betPoint2 = 100;
  static int _maxDailyDraws = 5;

  // 광고 시청 무료 추첨 (하루 최대 3회, paid 횟수와 별도)
  static const int _maxDailyFreeDraws = 3;
  static final Map<String, int> _freeDrawCounts = {}; // key: userId_YYYY-MM-DD

  final PrizeService _prizeService = PrizeService();
  final ExternalPointApiService _externalApi = ExternalPointApiService();

  /// 데이터베이스 초기화
  Future<void> init() async {
    // SharedPreferences에서 데이터 로드
    await _loadFromStorage();

    // 사용자 데이터가 없으면 최초 시드
    if (_users.isEmpty) {
      print('🔄 데이터베이스 초기화 시작... (사용자 없음)');
      await _seedInitialData();
      await _saveToStorage();
      _isInitialized = true;
      print('✅ 데이터베이스 초기화 완료 (사용자 수: ${_users.length})');
      return;
    }

    // 사용자가 있어도 데모 계정 password 누락 여부를 항상 검사·복구
    final repaired = await _repairDemoAccounts();
    if (repaired) {
      print('🔧 데모 계정 password 복구 완료');
      await _saveToStorage();
    }

    _isInitialized = true;
    print('✅ 데이터베이스 준비 완료 (사용자 수: ${_users.length})');
  }

  /// 저장된 데모 계정에 password가 없을 경우 자동 복구
  Future<bool> _repairDemoAccounts() async {
    bool repaired = false;

    final demoAccounts = {
      'admin@demo.com': _hashPassword('admin1234'),
      'user@demo.com':  _hashPassword('user1234'),
    };

    for (final entry in demoAccounts.entries) {
      final email    = entry.key;
      final pwHash   = entry.value;
      final userData = _users[email];

      if (userData == null) {
        // 계정 자체가 없으면 새로 생성
        final newUser = User(
          id:       _prizeService.generateId(),
          email:    email,
          password: pwHash,
          role:     email.startsWith('admin') ? 'ADMIN' : 'USER',
          points:   100,
        );
        _users[email] = newUser.toJson();
        print('🆕 데모 계정 신규 생성: $email');
        repaired = true;
      } else if ((userData['password'] as String? ?? '').isEmpty) {
        // password 필드가 비어 있으면 복구
        userData['password'] = pwHash;
        _users[email] = userData;
        print('🔧 데모 계정 password 복구: $email');
        repaired = true;
      }
    }

    return repaired;
  }
  
  /// SharedPreferences에서 데이터 로드
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 사용자 데이터 로드
      final usersJson = prefs.getString('users');
      if (usersJson != null) {
        final decoded = jsonDecode(usersJson) as Map<String, dynamic>;
        _users.clear();
        decoded.forEach((key, value) {
          _users[key] = value as Map<String, dynamic>;
        });
        print('✅ 사용자 데이터 로드 완료: ${_users.length}명');
      }
      
      // 추첨 데이터 로드
      final drawsJson = prefs.getString('draws');
      if (drawsJson != null) {
        final decoded = jsonDecode(drawsJson) as Map<String, dynamic>;
        _draws.clear();
        decoded.forEach((key, value) {
          _draws[key] = value as Map<String, dynamic>;
        });
        print('✅ 추첨 데이터 로드 완료: ${_draws.length}건');
      }
      
      // 경품 데이터 로드
      final prizesJson = prefs.getString('prizes');
      if (prizesJson != null) {
        final decoded = jsonDecode(prizesJson) as Map<String, dynamic>;
        _prizes.clear();
        decoded.forEach((key, value) {
          _prizes[key] = value as Map<String, dynamic>;
        });
        print('✅ 경품 데이터 로드 완료: ${_prizes.length}개');
      }
      
      // 거래 데이터 로드
      final transactionsJson = prefs.getString('transactions');
      if (transactionsJson != null) {
        final decoded = jsonDecode(transactionsJson) as Map<String, dynamic>;
        _transactions.clear();
        decoded.forEach((key, value) {
          _transactions[key] = value as Map<String, dynamic>;
        });
        print('✅ 거래 데이터 로드 완료: ${_transactions.length}건');
      }
      
      // 쿠폰 데이터 로드
      final couponsJson = prefs.getString('coupons');
      if (couponsJson != null) {
        final decoded = jsonDecode(couponsJson) as Map<String, dynamic>;
        _coupons.clear();
        decoded.forEach((key, value) {
          _coupons[key] = value as Map<String, dynamic>;
        });
        print('✅ 쿠폰 데이터 로드 완료: ${_coupons.length}개');
      }
      
      // 현재 사용자 ID 로드
      _currentUserId = prefs.getString('currentUserId');

      // 시스템 설정 로드
      _betPoint1 = prefs.getInt('betPoint1') ?? 5;
      _betPoint2 = prefs.getInt('betPoint2') ?? 100;
      _maxDailyDraws = prefs.getInt('maxDailyDraws') ?? 5;

      // 무료 추첨 횟수 로드
      final freeDrawJson = prefs.getString('freeDrawCounts');
      if (freeDrawJson != null) {
        final decoded = jsonDecode(freeDrawJson) as Map<String, dynamic>;
        _freeDrawCounts.clear();
        decoded.forEach((key, value) {
          _freeDrawCounts[key] = value as int;
        });
      }

      print('✅ SharedPreferences 데이터 로드 완료');
    } catch (e) {
      print('❌ SharedPreferences 로드 실패: $e');
    }
  }
  
  /// SharedPreferences에 데이터 저장
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 사용자 데이터 저장
      await prefs.setString('users', jsonEncode(_users));
      
      // 추첨 데이터 저장
      await prefs.setString('draws', jsonEncode(_draws));
      
      // 경품 데이터 저장
      await prefs.setString('prizes', jsonEncode(_prizes));
      
      // 거래 데이터 저장
      await prefs.setString('transactions', jsonEncode(_transactions));
      
      // 쿠폰 데이터 저장
      await prefs.setString('coupons', jsonEncode(_coupons));
      
      // 현재 사용자 ID 저장 (null이면 반드시 삭제)
      if (_currentUserId != null) {
        await prefs.setString('currentUserId', _currentUserId!);
      } else {
        await prefs.remove('currentUserId');
      }
      
      // 시스템 설정 저장
      await prefs.setInt('betPoint1', _betPoint1);
      await prefs.setInt('betPoint2', _betPoint2);
      await prefs.setInt('maxDailyDraws', _maxDailyDraws);

      // 무료 추첨 횟수 저장
      await prefs.setString('freeDrawCounts', jsonEncode(_freeDrawCounts));

      print('✅ SharedPreferences 데이터 저장 완료');
    } catch (e) {
      print('❌ SharedPreferences 저장 실패: $e');
    }
  }

  /// 비밀번호 해싱
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  /// 초기 데이터 시드
  Future<void> _seedInitialData() async {
    // 사용자가 없으면 초기 데이터 생성
    if (_users.isEmpty) {
      print('👥 초기 사용자 생성 중...');
      
      // 관리자 계정
      final adminId = _prizeService.generateId();
      final admin = User(
        id: adminId,
        email: 'admin@demo.com',
        password: _hashPassword('admin1234'),
        role: 'ADMIN',
        points: 100,
      );
      _users['admin@demo.com'] = admin.toJson();
      print('✅ 관리자 계정 생성: admin@demo.com');

      // 일반 사용자 계정
      final userId = _prizeService.generateId();
      final user = User(
        id: userId,
        email: 'user@demo.com',
        password: _hashPassword('user1234'),
        role: 'USER',
        points: 100,
      );
      _users['user@demo.com'] = user.toJson();
      print('✅ 사용자 계정 생성: user@demo.com');
    }

    // 경품이 없으면 초기 경품 생성
    if (_prizes.isEmpty) {
      print('🎁 초기 경품 생성 중...');
      
      final prizeList = [
        ExternalPrize(
          id: _prizeService.generateId(),
          name: '스타벅스 아메리카노',
          value: 5000,
          stock: 10,
        ),
        ExternalPrize(
          id: _prizeService.generateId(),
          name: '배달앱 5000원 할인',
          value: 5000,
          stock: 15,
        ),
        ExternalPrize(
          id: _prizeService.generateId(),
          name: '편의점 상품권 3000원',
          value: 3000,
          stock: 20,
        ),
        ExternalPrize(
          id: _prizeService.generateId(),
          name: 'CGV 영화 관람권',
          value: 14000,
          stock: 5,
        ),
      ];

      for (final prize in prizeList) {
        _prizes[prize.id] = prize.toJson();
      }
      print('✅ 경품 ${prizeList.length}개 생성 완료');
    }
  }

  /// 로그인
  Future<User?> login(String email, String password) async {
    print('🔐 로그인 시도: $email');
    
    final userData = _users[email];
    print('📝 사용자 데이터 존재: ${userData != null}');

    if (userData == null) {
      print('❌ 사용자를 찾을 수 없음: $email');
      print('📊 현재 등록된 사용자: ${_users.keys.join(", ")}');
      return null;
    }

    final user = User.fromJson(userData);
    final hashedPassword = _hashPassword(password);
    
    // 안전한 substring (길이 체크)
    final hashPreview = hashedPassword.length >= 10 
        ? hashedPassword.substring(0, 10) 
        : hashedPassword;
    final storedHashPreview = user.password.length >= 10 
        ? user.password.substring(0, 10) 
        : user.password;
    
    print('🔑 비밀번호 해시: $hashPreview...');
    print('🔑 저장된 해시: $storedHashPreview...');

    if (user.password == hashedPassword) {
      _currentUserId = user.id;
      print('✅ 로그인 성공: ${user.email} (${user.role})');
      
      // 로그인 성공 시 저장
      await _saveToStorage();
      
      return user;
    }

    print('❌ 비밀번호 불일치');
    return null;
  }

  /// 키오스크 신뢰 로그인 — 비밀번호 없이 사용자 ID(이메일)로 직접 세션 설정
  /// 키오스크 기기는 물리적으로 신뢰된 환경이므로 비밀번호 검증 생략
  Future<User?> kioskLogin(String userId) async {
    final userData = _users[userId];
    if (userData == null) return null;
    _currentUserId = userId;
    await _saveToStorage();
    return User.fromJson(userData);
  }

  /// 회원가입
  Future<User?> register(String email, String password) async {
    print('📝 회원가입 시도: $email');
    
    // 이미 존재하는 이메일인지 확인
    if (_users.containsKey(email)) {
      print('❌ 이미 존재하는 이메일: $email');
      return null;
    }

    final newUser = User(
      id: _prizeService.generateId(),
      email: email,
      password: _hashPassword(password),
      role: 'USER',
      points: 100,
    );

    _users[email] = newUser.toJson();
    _currentUserId = newUser.id;
    
    print('✅ 회원가입 성공: $email (ID: ${newUser.id})');
    print('📊 현재 총 사용자 수: ${_users.length}');
    print('📊 등록된 사용자: ${_users.keys.join(", ")}');

    // 회원가입 후 저장
    await _saveToStorage();

    return newUser;
  }

  /// 로그아웃
  Future<void> logout() async {
    _currentUserId = null;
    await _saveToStorage();
  }

  /// 데이터베이스 초기화 (관리자 전용) - 테스트 계정만 유지
  Future<void> resetDatabase() async {
    print('🔄 데이터베이스 초기화 시작...');
    
    // 모든 데이터 삭제
    _users.clear();
    _draws.clear();
    _prizes.clear();
    _transactions.clear();
    _currentUserId = null;
    _isInitialized = false;
    
    print('🗑️ 기존 데이터 모두 삭제됨');
    
    // 초기 데이터 재생성 (테스트 계정만)
    await _seedInitialData();
    
    // 초기화 후 저장
    await _saveToStorage();
    
    _isInitialized = true;
    print('✅ 데이터베이스 초기화 완료');
    print('📊 사용자 수: ${_users.length}');
    print('📊 사용자 목록: ${_users.keys.join(", ")}');
  }
  
  /// 모든 사용자 목록 가져오기 (관리자 전용)
  Future<List<User>> getAllUsers() async {
    final users = <User>[];
    for (final userData in _users.values) {
      users.add(User.fromJson(userData));
    }
    return users;
  }
  
  /// 특정 사용자 삭제 (관리자 전용)
  Future<bool> deleteUser(String email) async {
    if (email == 'admin@demo.com' || email == 'user@demo.com') {
      print('⚠️ 테스트 계정은 삭제할 수 없습니다: $email');
      return false;
    }
    
    if (_users.containsKey(email)) {
      _users.remove(email);
      print('✅ 사용자 삭제됨: $email');
      print('📊 현재 사용자 수: ${_users.length}');
      return true;
    }
    
    return false;
  }

  /// 현재 로그인된 사용자 가져오기
  Future<User?> getCurrentUser() async {
    if (_currentUserId == null) return null;

    for (final userData in _users.values) {
      final user = User.fromJson(userData);
      if (user.id == _currentUserId) {
        return user;
      }
    }

    return null;
  }

  /// ID로 사용자 가져오기
  Future<User?> getUserById(String userId) async {
    for (final userData in _users.values) {
      final user = User.fromJson(userData);
      if (user.id == userId) {
        return user;
      }
    }
    return null;
  }

  /// 사용자의 남은 일일 추첨 횟수 조회
  Future<Map<String, int>> getUserDailyDrawStatus(String userId) async {
    final user = await getUserById(userId);
    if (user == null) {
      return {'remaining': 0, 'used': 0, 'max': _maxDailyDraws};
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // 마지막 추첨이 오늘이 아니면 횟수 초기화
    int dailyDrawCount = user.dailyDrawCount;
    if (user.lastDrawDate == null || 
        DateTime(user.lastDrawDate!.year, user.lastDrawDate!.month, user.lastDrawDate!.day)
            .isBefore(today)) {
      dailyDrawCount = 0;
    }

    return {
      'remaining': _maxDailyDraws - dailyDrawCount,
      'used': dailyDrawCount,
      'max': _maxDailyDraws,
    };
  }

  /// 포인트 배팅 및 추첨
  Future<Map<String, dynamic>> conductDraw(String userId, int betAmount) async {
    // 사용자 찾기
    User? user;
    String? userEmail;
    for (final entry in _users.entries) {
      final u = User.fromJson(entry.value);
      if (u.id == userId) {
        user = u;
        userEmail = entry.key;
        break;
      }
    }

    if (user == null) {
      throw Exception('사용자를 찾을 수 없습니다');
    }

    // 일일 추첨 횟수 체크 및 초기화
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // 마지막 추첨이 오늘이 아니면 횟수 초기화
    if (user.lastDrawDate == null || 
        DateTime(user.lastDrawDate!.year, user.lastDrawDate!.month, user.lastDrawDate!.day)
            .isBefore(today)) {
      user.dailyDrawCount = 0;
      print('🔄 일일 추첨 횟수 초기화: ${user.email}');
    }

    // 일일 최대 횟수 체크 (동적)
    if (user.dailyDrawCount >= _maxDailyDraws) {
      throw Exception('일일 최대 추첨 횟수($_maxDailyDraws회)를 초과했습니다. 내일 다시 시도해주세요.');
    }

    // 포인트 확인
    if (user.points < betAmount) {
      throw Exception('포인트가 부족합니다');
    }

    // 포인트 차감
    user.points -= betAmount;

    // 당첨 결정
    final fee = (betAmount * feeRate).round();
    final selected = _prizeService.pickPrize();
    final winAmount = (betAmount * selected.multiplier).round();
    final userNet = winAmount - betAmount;

    // 외부 상품 추첨
    String? externalName;
    int? externalValue;
    String? couponId;

    if (_prizeService.randomFloat01() < externalPrizeProb) {
      final availablePrizes = _prizes.values
          .map((p) => ExternalPrize.fromJson(p))
          .where((p) => p.stock > 0)
          .toList();

      if (availablePrizes.isNotEmpty) {
        final pickedPrize = availablePrizes[
            (_prizeService.randomFloat01() * availablePrizes.length).floor()];

        // 재고 감소
        pickedPrize.stock--;
        _prizes[pickedPrize.id] = pickedPrize.toJson();

        externalName = pickedPrize.name;
        externalValue = pickedPrize.value;
        
        // 쿠폰 자동 생성
        final coupon = await createCoupon(
          userId: userId,
          prizeId: pickedPrize.id,
          prizeName: pickedPrize.name,
          prizeValue: pickedPrize.value,
        );
        couponId = coupon.id;
        
        print('🎁 외부 경품 당첨: ${pickedPrize.name} (쿠폰 발급: ${coupon.couponCode})');
      }
    }

    // 포인트 지급
    user.points += winAmount;
    user.drawSeq++;
    
    // 일일 추첨 횟수 증가 및 날짜 업데이트
    user.dailyDrawCount++;
    user.lastDrawDate = now;
    
    print('✅ 추첨 완료: ${user.email} (오늘 ${user.dailyDrawCount}/$_maxDailyDraws회)');

    // 사용자 정보 업데이트
    _users[userEmail!] = user.toJson();

    // 추첨 기록 생성
    final draw = Draw(
      id: _prizeService.generateId(),
      userId: userId,
      round: user.drawSeq,
      betAmount: betAmount,
      feeAmount: fee,
      winAmount: winAmount,
      multiplier: selected.multiplier,
      prizeRange: selected.range,
      externalName: externalName,
      externalValue: externalValue,
      userNet: userNet,
    );

    _draws[draw.id] = draw.toJson();
    
    // 추첨 후 저장
    await _saveToStorage();

    return {
      'userPoints': user.points,
      'draw': draw.toJson(),
      'dailyDrawCount': user.dailyDrawCount,
      'maxDailyDraws': _maxDailyDraws,
    };
  }

  /// 사용자의 추첨 이력 가져오기
  Future<List<Draw>> getUserDrawHistory(String userId, {int limit = 20}) async {
    final draws = _draws.values
        .map((d) => Draw.fromJson(d))
        .where((d) => d.userId == userId)
        .toList();

    draws.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return draws.take(limit).toList();
  }

  /// 사용자 개인 통계 조회
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    final userDraws = _draws.values
        .map((d) => Draw.fromJson(d))
        .where((d) => d.userId == userId)
        .toList();

    int totalBet = 0;
    int totalWin = 0;
    int totalNet = 0;
    int externalPrizeCount = 0;
    final Map<String, int> prizeRangeCount = {};

    for (final draw in userDraws) {
      totalBet += draw.betAmount;
      totalWin += draw.winAmount;
      totalNet += draw.userNet;

      // 외부 경품 당첨 횟수
      if (draw.externalName != null && draw.externalName!.isNotEmpty) {
        externalPrizeCount++;
      }

      // 등급별 당첨 횟수
      prizeRangeCount[draw.prizeRange] = 
          (prizeRangeCount[draw.prizeRange] ?? 0) + 1;
    }

    // 수익률 계산
    final profitRate = totalBet > 0 ? (totalWin / totalBet * 100) : 0.0;

    return {
      'totalDraws': userDraws.length,
      'totalBet': totalBet,
      'totalWin': totalWin,
      'totalNet': totalNet,
      'profitRate': profitRate,
      'externalPrizeCount': externalPrizeCount,
      'prizeRangeCount': prizeRangeCount,
    };
  }

  /// 사용자의 외부 경품 당첨 이력
  Future<List<Draw>> getUserExternalPrizeHistory(String userId) async {
    final draws = _draws.values
        .map((d) => Draw.fromJson(d))
        .where((d) => 
            d.userId == userId && 
            d.externalName != null && 
            d.externalName!.isNotEmpty
        )
        .toList();

    draws.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return draws;
  }

  /// 전체 추첨 이력 가져오기 (관리자용)
  Future<List<Draw>> getAllDrawHistory({int limit = 50}) async {
    final draws = _draws.values.map((d) => Draw.fromJson(d)).toList();

    draws.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return draws.take(limit).toList();
  }

  /// 통계 계산 (관리자용)
  Future<Map<String, dynamic>> getStats() async {
    final draws = _draws.values.map((d) => Draw.fromJson(d)).toList();

    int totalRevenue = 0;
    int totalPayout = 0;
    int totalFreeDraws = 0;
    final Set<String> participants = {};

    for (final draw in draws) {
      totalRevenue += draw.feeAmount;
      totalPayout += draw.winAmount;
      participants.add(draw.userId);
      if (draw.betAmount == 0) totalFreeDraws++;
    }

    return {
      'totalRevenue': totalRevenue,
      'totalPayout': totalPayout,
      'totalParticipants': participants.length,
      'totalFreeDraws': totalFreeDraws,
    };
  }

  /// 고객 현황 조회 (관리자용)
  Future<List<Map<String, dynamic>>> getCustomerStats() async {
    final customerStats = <Map<String, dynamic>>[];

    for (final entry in _users.entries) {
      final user = User.fromJson(entry.value);
      
      // 해당 사용자의 추첨 이력
      final userDraws = _draws.values
          .map((d) => Draw.fromJson(d))
          .where((d) => d.userId == user.id)
          .toList();

      int totalBet = 0;
      int totalWin = 0;
      int externalPrizeCount = 0;

      for (final draw in userDraws) {
        totalBet += draw.betAmount;
        totalWin += draw.winAmount;
        if (draw.externalName != null && draw.externalName!.isNotEmpty) {
          externalPrizeCount++;
        }
      }

      customerStats.add({
        'user': user,
        'drawCount': userDraws.length,
        'totalBet': totalBet,
        'totalWin': totalWin,
        'totalNet': totalWin - totalBet,
        'externalPrizeCount': externalPrizeCount,
        'lastDrawDate': userDraws.isNotEmpty 
            ? userDraws.map((d) => d.createdAt).reduce(
                (a, b) => a.isAfter(b) ? a : b
              )
            : null,
      });
    }

    // 참여 횟수 많은 순으로 정렬
    customerStats.sort((a, b) => 
        (b['drawCount'] as int).compareTo(a['drawCount'] as int)
    );

    return customerStats;
  }

  /// 외부 경품 지급 현황 (관리자용)
  Future<List<Map<String, dynamic>>> getExternalPrizeGivenHistory() async {
    final prizeHistory = <Map<String, dynamic>>[];

    final draws = _draws.values
        .map((d) => Draw.fromJson(d))
        .where((d) => d.externalName != null && d.externalName!.isNotEmpty)
        .toList();

    draws.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    for (final draw in draws) {
      // 사용자 정보 가져오기
      User? user;
      for (final userData in _users.values) {
        final u = User.fromJson(userData);
        if (u.id == draw.userId) {
          user = u;
          break;
        }
      }

      prizeHistory.add({
        'draw': draw,
        'user': user,
      });
    }

    return prizeHistory;
  }

  /// 외부 경품 목록 가져오기
  Future<List<ExternalPrize>> getExternalPrizes() async {
    return _prizes.values.map((p) => ExternalPrize.fromJson(p)).toList();
  }

  /// 외부 경품 추가
  Future<void> addExternalPrize(String name, int value, int stock) async {
    final prize = ExternalPrize(
      id: _prizeService.generateId(),
      name: name,
      value: value,
      stock: stock,
    );
    _prizes[prize.id] = prize.toJson();
    
    // 경품 추가 후 저장
    await _saveToStorage();
  }

  /// 외부 경품 수정
  Future<void> updateExternalPrize(
      String id, String name, int value, int stock) async {
    final prizeData = _prizes[id];

    if (prizeData != null) {
      final prize = ExternalPrize.fromJson(prizeData);
      prize.name = name;
      prize.value = value;
      prize.stock = stock;
      _prizes[id] = prize.toJson();
      
      // 경품 수정 후 저장
      await _saveToStorage();
    }
  }

  /// 외부 경품 삭제
  Future<void> deleteExternalPrize(String id) async {
    _prizes.remove(id);
    
    // 경품 삭제 후 저장
    await _saveToStorage();
  }

  /// 외부 포인트 잔액 조회
  Future<int> getExternalPointBalance(String userId) async {
    final result = await _externalApi.getExternalBalance(userId);
    if (result['success'] == true) {
      return result['balance'] as int;
    }
    throw Exception('외부 포인트 잔액 조회 실패');
  }

  /// 포인트 충전 (외부 → 내부)
  Future<PointTransaction> chargePoints(String userId, int amount) async {
    // 거래 기록 생성
    final transaction = PointTransaction(
      id: _prizeService.generateId(),
      userId: userId,
      type: 'CHARGE',
      amount: amount,
      status: 'PENDING',
      memo: '외부 포인트 충전',
    );

    _transactions[transaction.id] = transaction.toJson();

    try {
      // 외부 API 호출
      final result = await _externalApi.chargePoints(
        userId: userId,
        amount: amount,
        transactionId: transaction.id,
      );

      if (result['success'] == true) {
        // 사용자 포인트 증가
        User? user;
        String? userEmail;
        for (final entry in _users.entries) {
          final u = User.fromJson(entry.value);
          if (u.id == userId) {
            user = u;
            userEmail = entry.key;
            break;
          }
        }

        if (user != null && userEmail != null) {
          user.points += amount;
          _users[userEmail] = user.toJson();

          // 거래 완료 처리
          transaction.status = 'COMPLETED';
          transaction.externalTransactionId =
              result['externalTransactionId'] as String?;
          transaction.completedAt = DateTime.now();
          _transactions[transaction.id] = transaction.toJson();
          
          // 충전 완료 후 저장
          await _saveToStorage();

          return transaction;
        } else {
          throw Exception('사용자를 찾을 수 없습니다');
        }
      } else {
        // 거래 실패
        transaction.status = 'FAILED';
        transaction.memo = result['error'] as String? ?? '충전 실패';
        _transactions[transaction.id] = transaction.toJson();
        throw Exception(transaction.memo);
      }
    } catch (e) {
      // 오류 발생 시 실패 처리
      transaction.status = 'FAILED';
      transaction.memo = e.toString();
      _transactions[transaction.id] = transaction.toJson();
      rethrow;
    }
  }

  /// 포인트 환전 (내부 → 외부)
  Future<PointTransaction> withdrawPoints(String userId, int amount) async {
    // 사용자 찾기
    User? user;
    String? userEmail;
    for (final entry in _users.entries) {
      final u = User.fromJson(entry.value);
      if (u.id == userId) {
        user = u;
        userEmail = entry.key;
        break;
      }
    }

    if (user == null) {
      throw Exception('사용자를 찾을 수 없습니다');
    }

    // 포인트 부족 확인
    if (user.points < amount) {
      throw Exception('포인트가 부족합니다');
    }

    // 거래 기록 생성
    final transaction = PointTransaction(
      id: _prizeService.generateId(),
      userId: userId,
      type: 'WITHDRAW',
      amount: amount,
      status: 'PENDING',
      memo: '외부 포인트로 환전',
    );

    _transactions[transaction.id] = transaction.toJson();

    try {
      // 외부 API 호출
      final result = await _externalApi.withdrawPoints(
        userId: userId,
        amount: amount,
        transactionId: transaction.id,
      );

      if (result['success'] == true) {
        // 사용자 포인트 차감
        user.points -= amount;
        _users[userEmail!] = user.toJson();

        // 거래 완료 처리
        transaction.status = 'COMPLETED';
        transaction.externalTransactionId =
            result['externalTransactionId'] as String?;
        transaction.completedAt = DateTime.now();
        _transactions[transaction.id] = transaction.toJson();
        
        // 환전 완료 후 저장
        await _saveToStorage();

        return transaction;
      } else {
        // 거래 실패
        transaction.status = 'FAILED';
        transaction.memo = result['error'] as String? ?? '환전 실패';
        _transactions[transaction.id] = transaction.toJson();
        throw Exception(transaction.memo);
      }
    } catch (e) {
      // 오류 발생 시 실패 처리
      transaction.status = 'FAILED';
      transaction.memo = e.toString();
      _transactions[transaction.id] = transaction.toJson();
      rethrow;
    }
  }

  /// 포인트 거래 내역 조회
  Future<List<PointTransaction>> getPointTransactions(String userId,
      {int limit = 20}) async {
    final transactions = _transactions.values
        .map((t) => PointTransaction.fromJson(t))
        .where((t) => t.userId == userId)
        .toList();

    transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return transactions.take(limit).toList();
  }

  /// 시스템 설정 조회
  Future<Map<String, int>> getSystemSettings() async {
    return {
      'betPoint1': _betPoint1,
      'betPoint2': _betPoint2,
      'maxDailyDraws': _maxDailyDraws,
    };
  }

  /// 시스템 설정 업데이트
  Future<void> updateSystemSettings({
    int? betPoint1,
    int? betPoint2,
    int? maxDailyDraws,
  }) async {
    if (betPoint1 != null && betPoint1 > 0) {
      _betPoint1 = betPoint1;
      print('✅ 배팅 포인트 1: ${_betPoint1}P로 변경');
    }
    
    if (betPoint2 != null && betPoint2 > 0) {
      _betPoint2 = betPoint2;
      print('✅ 배팅 포인트 2: ${_betPoint2}P로 변경');
    }
    
    if (maxDailyDraws != null && maxDailyDraws > 0) {
      _maxDailyDraws = maxDailyDraws;
      print('✅ 일일 최대 배팅 횟수: ${_maxDailyDraws}회로 변경');
    }
    
    // 시스템 설정 변경 후 저장
    await _saveToStorage();
  }

  /// 현재 배팅 포인트 가져오기
  int getBetPoint1() => _betPoint1;
  int getBetPoint2() => _betPoint2;

  /// 현재 일일 최대 배팅 횟수 가져오기
  int getMaxDailyDraws() => _maxDailyDraws;

  // ── 광고 시청 무료 추첨 ────────────────────────────────────────

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 오늘 남은 무료 추첨 횟수 조회
  Future<Map<String, int>> getUserDailyFreeDrawStatus(String userId) async {
    final key = '${userId}_${_todayKey()}';
    final used = _freeDrawCounts[key] ?? 0;
    return {
      'remaining': _maxDailyFreeDraws - used,
      'used': used,
      'max': _maxDailyFreeDraws,
    };
  }

  /// 광고 시청 후 무료 배팅 실행 (포인트 차감 없음)
  Future<Map<String, dynamic>> conductFreeDraw(String userId) async {
    // 사용자 찾기
    User? user;
    String? userEmail;
    for (final entry in _users.entries) {
      final u = User.fromJson(entry.value);
      if (u.id == userId) {
        user = u;
        userEmail = entry.key;
        break;
      }
    }
    if (user == null) throw Exception('사용자를 찾을 수 없습니다');

    // 일일 무료 횟수 확인
    final freeKey = '${userId}_${_todayKey()}';
    final usedFree = _freeDrawCounts[freeKey] ?? 0;
    if (usedFree >= _maxDailyFreeDraws) {
      throw Exception('오늘 무료 추첨 횟수($_maxDailyFreeDraws회)를 모두 사용했습니다. 내일 다시 도전하세요!');
    }

    // 가상 베팅금 = betPoint1 (prize 계산에만 사용, 실제 차감 없음)
    final virtualBet = _betPoint1;
    final selected = _prizeService.pickPrize();
    final winAmount = (virtualBet * selected.multiplier).round();

    // 외부 경품 추첨
    String? externalName;
    int? externalValue;
    if (_prizeService.randomFloat01() < externalPrizeProb) {
      final availablePrizes = _prizes.values
          .map((p) => ExternalPrize.fromJson(p))
          .where((p) => p.stock > 0)
          .toList();

      if (availablePrizes.isNotEmpty) {
        final pickedPrize = availablePrizes[
            (_prizeService.randomFloat01() * availablePrizes.length).floor()];
        pickedPrize.stock--;
        _prizes[pickedPrize.id] = pickedPrize.toJson();
        externalName = pickedPrize.name;
        externalValue = pickedPrize.value;

        await createCoupon(
          userId: userId,
          prizeId: pickedPrize.id,
          prizeName: pickedPrize.name,
          prizeValue: pickedPrize.value,
        );
        print('🎁 무료 추첨 외부 경품: ${pickedPrize.name}');
      }
    }

    // 포인트 지급 (차감 없이 winAmount만 추가)
    user.points += winAmount;
    user.drawSeq++;
    _users[userEmail!] = user.toJson();

    // 무료 횟수 증가
    _freeDrawCounts[freeKey] = usedFree + 1;

    // 추첨 기록 (betAmount=0)
    final draw = Draw(
      id: _prizeService.generateId(),
      userId: userId,
      round: user.drawSeq,
      betAmount: 0,
      feeAmount: 0,
      winAmount: winAmount,
      multiplier: selected.multiplier,
      prizeRange: selected.range,
      externalName: externalName,
      externalValue: externalValue,
      userNet: winAmount,
    );

    _draws[draw.id] = draw.toJson();
    await _saveToStorage();

    print('✅ 무료 추첨 완료: ${user.email} +${winAmount}P (오늘 ${usedFree + 1}/$_maxDailyFreeDraws회)');

    return {
      'userPoints': user.points,
      'draw': draw.toJson(),
      'freeDrawsUsed': usedFree + 1,
      'maxFreeDraws': _maxDailyFreeDraws,
    };
  }
  
  /// 당일 높은 경품 당첨자 목록 (상위 10명)
  Future<List<Map<String, dynamic>>> getTodayTopWinners({int limit = 10}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // 오늘 추첨된 기록 필터링
    final todayDraws = _draws.values
        .map((d) => Draw.fromJson(d))
        .where((draw) {
          final drawDate = DateTime(
            draw.createdAt.year,
            draw.createdAt.month,
            draw.createdAt.day,
          );
          return drawDate.isAtSameMomentAs(today);
        })
        .toList();
    
    // 당첨 금액 높은 순으로 정렬
    todayDraws.sort((a, b) => b.winAmount.compareTo(a.winAmount));
    
    // 상위 N개만 선택
    final topDraws = todayDraws.take(limit).toList();
    
    // 사용자 정보 포함하여 반환
    final winners = <Map<String, dynamic>>[];
    for (final draw in topDraws) {
      // 사용자 찾기
      User? winner;
      for (final userData in _users.values) {
        final user = User.fromJson(userData);
        if (user.id == draw.userId) {
          winner = user;
          break;
        }
      }
      
      if (winner != null) {
        // 이름 마스킹 (예: 홍길동 → 홍**)
        String maskedName = _maskName(winner.email);
        
        winners.add({
          'name': maskedName,
          'winAmount': draw.winAmount,
          'betAmount': draw.betAmount,
          'multiplier': draw.multiplier,
          'prizeRange': draw.prizeRange,
          'createdAt': draw.createdAt,
        });
      }
    }
    
    return winners;
  }
  
  /// 이름 마스킹 처리 (이메일 → 이름 형태로 변환)
  String _maskName(String email) {
    // 이메일에서 @ 앞부분 추출
    final username = email.split('@')[0];
    
    // 첫 글자만 보이고 나머지는 ** 처리
    if (username.length <= 1) {
      return '$username**';
    } else if (username.length <= 3) {
      return '${username[0]}**';
    } else {
      // 3글자 이상이면 첫 글자 + **
      return '${username[0]}**';
    }
  }
  
  /// 쿠폰 코드 생성 (16자리 난수)
  String _generateCouponCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    
    // 4자리씩 4그룹 (XXXX-XXXX-XXXX-XXXX)
    final parts = List.generate(4, (index) {
      return List.generate(4, (i) => chars[random.nextInt(chars.length)]).join();
    });
    
    return parts.join('-');
  }
  
  /// 쿠폰 생성 (외부 경품 당첨 시 자동 생성)
  Future<Coupon> createCoupon({
    required String userId,
    required String prizeId,
    required String prizeName,
    required int prizeValue,
  }) async {
    final coupon = Coupon(
      id: _prizeService.generateId(),
      userId: userId,
      prizeId: prizeId,
      prizeName: prizeName,
      prizeValue: prizeValue,
      couponCode: _generateCouponCode(),
    );
    
    _coupons[coupon.id] = coupon.toJson();
    
    // 쿠폰 생성 후 저장
    await _saveToStorage();
    
    print('✅ 쿠폰 생성: ${coupon.prizeName} (코드: ${coupon.couponCode})');
    
    return coupon;
  }
  
  /// 사용자의 쿠폰 목록 조회
  Future<List<Coupon>> getUserCoupons(String userId, {String? status}) async {
    final coupons = _coupons.values
        .map((c) => Coupon.fromJson(c))
        .where((c) => c.userId == userId)
        .toList();
    
    // 상태 필터링
    if (status != null) {
      return coupons.where((c) => c.status == status).toList();
    }
    
    // 발급일 기준 최신순 정렬
    coupons.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
    
    return coupons;
  }
  
  /// 쿠폰 사용 처리
  Future<void> useCoupon(String couponId) async {
    final couponData = _coupons[couponId];
    if (couponData == null) {
      throw Exception('쿠폰을 찾을 수 없습니다');
    }
    
    final coupon = Coupon.fromJson(couponData);
    
    if (coupon.isUsed) {
      throw Exception('이미 사용된 쿠폰입니다');
    }
    
    // 쿠폰 사용 처리
    final updatedCoupon = Coupon(
      id: coupon.id,
      userId: coupon.userId,
      prizeId: coupon.prizeId,
      prizeName: coupon.prizeName,
      prizeValue: coupon.prizeValue,
      couponCode: coupon.couponCode,
      issuedAt: coupon.issuedAt,
      usedAt: DateTime.now(),
      isUsed: true,
      status: 'USED',
    );
    
    _coupons[couponId] = updatedCoupon.toJson();
    
    // 쿠폰 사용 후 저장
    await _saveToStorage();
    
    print('✅ 쿠폰 사용 완료: ${coupon.prizeName}');
  }
  
  /// 쿠폰 상세 조회
  Future<Coupon?> getCoupon(String couponId) async {
    final couponData = _coupons[couponId];
    if (couponData == null) return null;
    
    return Coupon.fromJson(couponData);
  }
  
  /// 사용 가능한 쿠폰 개수
  Future<int> getActiveCouponCount(String userId) async {
    final coupons = await getUserCoupons(userId, status: 'ACTIVE');
    return coupons.length;
  }
}
