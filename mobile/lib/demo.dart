import 'dart:convert';
import 'dart:math' as math;

import 'api.dart' show ApiException, Json;

/// Local demonstration data. Never used as a fallback for live API mutations.
class DemoStore {
  final Json state;
  DemoStore(this.state);
  static const password = 'Demo1234!';
  static const code = '12345678';
  int? get userId => state['current_user'] as int?;
  set userId(int? value) => state['current_user'] = value;
  List<Json> rows(String key) => (state[key] as List).cast<Json>();
  String now() => DateTime.now().toUtc().toIso8601String();
  Json byId(String key, dynamic id) => rows(key).firstWhere(
    (r) => '${r['id']}' == '$id',
    orElse: () => throw ApiException('This demo item was not found.', 404),
  );
  int nextId(String key) =>
      rows(key).fold<int>(0, (n, r) => math.max(n, r['id'] as int)) + 1;
  Json account() {
    if (userId == null) throw ApiException('Sign in to a demo account.', 401);
    return byId('users', userId);
  }

  Json publicUser(Json user) => {...user}..remove('password');
  Json ownProfile() {
    if (account()['role'] != 'professional') {
      throw ApiException('Use the professional demo account for this action.');
    }
    return rows('professionals').firstWhere((p) => p['user'] == userId);
  }

  factory DemoStore.fresh() {
    final store = DemoStore({
      'schema': 1,
      'current_user': 1,
      for (final key in [
        'users',
        'categories',
        'areas',
        'professionals',
        'bookings',
        'quotes',
        'reviews',
        'slots',
        'messages',
        'notifications',
        'reports',
        'promotions',
        'packages',
        'challenges',
      ])
        key: <Json>[],
    });
    store.rows('categories').addAll([
      {'id': 1, 'name': 'Electrician', 'icon': 'bolt'},
      {'id': 2, 'name': 'Web Developer', 'icon': 'code'},
      {'id': 3, 'name': 'Cleaner', 'icon': 'cleaning_services'},
      {'id': 4, 'name': 'Graphic Designer', 'icon': 'palette'},
      {'id': 5, 'name': 'AC Technician', 'icon': 'ac_unit'},
      {'id': 6, 'name': 'Carpenter', 'icon': 'handyman'},
    ]);
    store.rows('areas').addAll([
      {
        'id': 1,
        'name': 'Mirpur',
        'city': 'Dhaka',
        'latitude': 23.8223,
        'longitude': 90.3654,
      },
      {
        'id': 2,
        'name': 'Dhanmondi',
        'city': 'Dhaka',
        'latitude': 23.7461,
        'longitude': 90.3742,
      },
      {
        'id': 3,
        'name': 'Uttara',
        'city': 'Dhaka',
        'latitude': 23.8759,
        'longitude': 90.3795,
      },
    ]);
    final names = [
      'Nadia Rahman',
      'Rahim Uddin',
      'Sadia Ahmed',
      'Farzana Islam',
      'Tanim Hasan',
      'Imran Ali',
      'Karim Hossain',
    ];
    for (var i = 0; i < names.length; i++) {
      store.rows('users').add({
        'id': i + 1,
        'username': i == 0
            ? 'demo_customer'
            : i == 1
            ? 'demo_pro'
            : 'demo_pro_${i + 1}',
        'password': password,
        'first_name': names[i].split(' ').first,
        'last_name': names[i].split(' ').last,
        'email': 'demo${i + 1}@example.com',
        'phone': 'Demo contact',
        'role': i == 0 ? 'customer' : 'professional',
        'email_verified': false,
        'is_staff': false,
      });
    }
    final businesses = [
      'Rahim Electrical Works',
      'Sadia Web Studio',
      'Fresh Space Cleaning',
      'Tanim Design Desk',
      'Imran Cooling Services',
      'Karim Carpentry',
    ];
    final descriptions = [
      'Wiring, lighting and switchboard repairs for your home.',
      'Thoughtful websites for local businesses and online shops.',
      'Regular cleaning and move-in care for your home.',
      'Brand identities and practical graphic design for growing businesses.',
      'AC servicing, installation and cooling repairs.',
      'Furniture repairs, custom shelves and careful woodwork.',
    ];
    final prices = [450, 2500, 800, 1200, 700, 600];
    for (var i = 0; i < businesses.length; i++) {
      store.rows('professionals').add({
        'id': i + 1,
        'user': i + 2,
        'business_name': businesses[i],
        'bio': descriptions[i],
        'skills': store.rows('categories')[i]['name'],
        'experience_years': 3 + i,
        'category_ids': [i + 1],
        'area_ids': [1, i % 2 == 0 ? 3 : 2],
        'available': true,
        'verified': i < 4,
        'schedule_enabled': false,
        'starting_price': '${prices[i]}.00',
        'latitude': 23.79 + i * .008,
        'longitude': 90.37 + i * .004,
        'portfolio': [
          {
            'id': 100 + i,
            'title': 'Sample completed project',
            'description': descriptions[i],
            'image': null,
          },
        ],
      });
      store.rows('reviews').add({
        'id': i + 1,
        'professional': i + 1,
        'customer_name': 'Sample customer',
        'rating': i == 5 ? 4 : 5,
        'comment':
            'Careful work and clear communication. This is a sample review.',
        'created_at': store.now(),
      });
      for (var day = 1; day <= 3; day++) {
        final start = DateTime.now().add(Duration(days: day));
        final appointment = DateTime(
          start.year,
          start.month,
          start.day,
          10,
        ).toUtc();
        store.rows('slots').add({
          'id': i * 3 + day,
          'professional': i + 1,
          'starts_at': appointment.toIso8601String(),
          'ends_at': appointment
              .add(const Duration(hours: 1))
              .toIso8601String(),
        });
      }
    }
    store.rows('bookings').addAll([
      {
        'id': 1,
        'customer': 1,
        'professional': 1,
        'category': 1,
        'area': 1,
        'status': 'pending',
        'scheduled_at': store.rows('slots')[1]['starts_at'],
        'duration_minutes': 60,
        'slot': 2,
        'address': 'Sample home, Mirpur',
        'details': 'Please check the kitchen lights.',
        'quote': null,
        'agreed_price': null,
        'agreed_terms': '',
        'created_at': store.now(),
      },
      {
        'id': 2,
        'customer': 1,
        'professional': 1,
        'category': 1,
        'area': 1,
        'status': 'completed',
        'scheduled_at': DateTime.now()
            .subtract(const Duration(days: 2))
            .toUtc()
            .toIso8601String(),
        'duration_minutes': 60,
        'slot': null,
        'address': 'Sample home, Mirpur',
        'details': 'A completed demo job: try publishing a review.',
        'quote': null,
        'agreed_price': '450.00',
        'agreed_terms': 'Lighting repair',
        'created_at': store.now(),
      },
    ]);
    store.rows('quotes').add({
      'id': 1,
      'customer': 1,
      'professional': 1,
      'category': 1,
      'area': 1,
      'details': 'Replace a faulty switchboard.',
      'amount': '650.00',
      'response': 'Labour included; materials are separate.',
      'revision': 1,
      'created_at': store.now(),
    });
    store.rows('messages').add({
      'id': 1,
      'kind': 'bookings',
      'request': 1,
      'sender': 2,
      'body': 'Hello! You can try messaging here, then switch roles to reply.',
      'read_at': null,
      'created_at': store.now(),
    });
    final pricesAndDays = [(100, 1), (300, 7), (500, 15), (800, 30)];
    for (var i = 0; i < pricesAndDays.length; i++) {
      store.rows('packages').add({
        'id': i + 1,
        'name': ['Starter', 'Weekly', 'Half month', 'Monthly'][i],
        'price': '${pricesAndDays[i].$1}.00',
        'days': pricesAndDays[i].$2,
        'active': true,
      });
    }
    store.notify(
      1,
      'Welcome to the offline demo. Changes are saved only on this device.',
    );
    store.notify(
      2,
      'A demo customer has requested an appointment. Open Activity to respond.',
    );
    return store;
  }

  void notify(int recipient, String message) => rows('notifications').add({
    'id': nextId('notifications'),
    'user': recipient,
    'message': message,
    'read': false,
    'created_at': now(),
  });
  bool participant(Json row) =>
      row['customer'] == userId ||
      byId('professionals', row['professional'])['user'] == userId;
  Json requestRow(String kind, dynamic id) {
    account();
    final row = byId(kind, id);
    if (!participant(row)) {
      throw ApiException('This request belongs to another demo account.', 403);
    }
    return row;
  }

  Json profile(Json row, {Json? query}) {
    final owner = byId('users', row['user']);
    final reviews = rows('reviews')
        .where((r) => r['professional'] == row['id'])
        .toList();
    final activePromotions = rows('promotions').where(
      (p) =>
          p['professional'] == row['id'] &&
          DateTime.parse(p['expires_at']).isAfter(DateTime.now()) &&
          '${p['category']}' == '${query?['category']}' &&
          '${p['area']}' == '${query?['area']}',
    );
    double? distance;
    final lat = double.tryParse('${query?['lat']}'),
        lng = double.tryParse('${query?['lng']}');
    if (lat != null &&
        lng != null &&
        row['latitude'] != null &&
        row['longitude'] != null) {
      final dLat = (row['latitude'] as num).toDouble() - lat;
      final dLng = (row['longitude'] as num).toDouble() - lng;
      distance =
          math.sqrt(
            dLat * dLat + math.pow(dLng * math.cos(lat * math.pi / 180), 2),
          ) *
          111.2;
    }
    return {
      ...row,
      'name': '${owner['first_name']} ${owner['last_name']}',
      'phone': owner['phone'],
      'categories': [
        for (final id in row['category_ids']) byId('categories', id),
      ],
      'areas': [for (final id in row['area_ids']) byId('areas', id)],
      'rating': reviews.isEmpty
          ? 0.0
          : reviews.fold<double>(0, (n, r) => n + (r['rating'] as num)) /
                reviews.length,
      'review_count': reviews.length,
      'distance_km': distance,
      'promoted': activePromotions.isNotEmpty,
    };
  }

  Json presentedRequest(String kind, Json row) {
    final result = {
      ...row,
      'professional_name': byId(
        'professionals',
        row['professional'],
      )['business_name'],
      'customer_name':
          '${byId('users', row['customer'])['first_name']} ${byId('users', row['customer'])['last_name']}',
      'category_name': byId('categories', row['category'])['name'],
      'area_name': byId('areas', row['area'])['name'],
    };
    if (kind == 'quotes') {
      result['booking_id'] = rows('bookings')
          .where((b) => b['quote'] == row['id'])
          .firstOrNull?['id'];
    } else {
      result['review'] = rows('reviews')
          .where((r) => r['booking'] == row['id'])
          .firstOrNull;
    }
    return result;
  }

  Json page(Iterable<Json> values, String path, Json query) {
    final list = values.toList();
    final number = int.tryParse('${query['page']}') ?? 1;
    final offset = math.max(0, number - 1) * 30;
    return {
      'count': list.length,
      'results': list.skip(offset).take(30).toList(),
      'next': offset + 30 < list.length
          ? 'https://demo.invalid/api/$path?page=${number + 1}'
          : null,
      'previous': number > 1
          ? 'https://demo.invalid/api/$path?page=${number - 1}'
          : null,
    };
  }

  bool conflicts(int professional, DateTime start, DateTime end) =>
      rows('bookings').any((b) {
        if (b['professional'] != professional ||
            !['pending', 'accepted'].contains(b['status'])) {
          return false;
        }
        final booked = DateTime.parse(b['scheduled_at']);
        return booked.isBefore(end) &&
            booked
                .add(Duration(minutes: b['duration_minutes'] as int))
                .isAfter(start);
      });
  Json createBooking(Json body, {Json? quote}) {
    if (account()['role'] != 'customer') {
      throw ApiException('Use a customer demo account to book.');
    }
    final pro = byId(
      'professionals',
      quote?['professional'] ?? body['professional'],
    );
    if (pro['available'] != true) {
      throw ApiException('This professional is unavailable.');
    }
    final start = DateTime.tryParse('${body['scheduled_at']}');
    final duration = int.tryParse('${body['duration_minutes'] ?? 60}');
    if (start == null ||
        !start.isAfter(DateTime.now()) ||
        duration == null ||
        duration < 30 ||
        duration > 480) {
      throw ApiException('Choose a future appointment lasting 30–480 minutes.');
    }
    final end = start.add(Duration(minutes: duration));
    if (pro['schedule_enabled'] == true && body['slot'] == null) {
      throw ApiException('Choose a published appointment.');
    }
    if (body['slot'] != null) {
      final slot = byId('slots', body['slot']);
      if (slot['professional'] != pro['id'] ||
          DateTime.parse(slot['starts_at']) != start ||
          DateTime.parse(slot['ends_at']) != end) {
        throw ApiException('Choose a matching published appointment.');
      }
    }
    if (conflicts(pro['id'], start, end)) {
      throw ApiException('This appointment is reserved. Choose another time.');
    }
    final category = quote?['category'] ?? body['category'],
        area = quote?['area'] ?? body['area'];
    if (!(pro['category_ids'] as List).contains(category) ||
        !(pro['area_ids'] as List).contains(area)) {
      throw ApiException(
        'Choose one of this professional’s services and areas.',
      );
    }
    if ('${body['address'] ?? ''}'.trim().isEmpty) {
      throw ApiException('Enter the service address.');
    }
    final row = {
      'id': nextId('bookings'),
      'professional': pro['id'],
      'customer': userId,
      'category': category,
      'area': area,
      'details': quote?['details'] ?? body['details'],
      'scheduled_at': start.toUtc().toIso8601String(),
      'duration_minutes': duration,
      'slot': body['slot'],
      'address': body['address'],
      'status': 'pending',
      'quote': quote?['id'],
      'agreed_price': quote?['amount'],
      'agreed_terms': quote?['response'] ?? '',
      'created_at': now(),
    };
    rows('bookings').insert(0, row);
    notify(pro['user'], 'New demo booking #${row['id']}.');
    return presentedRequest('bookings', row);
  }

  dynamic handle(String method, String path, {Json? body, Json? query}) {
    // Return copies so UI edits cannot mutate the store without a request.
    return jsonDecode(
      jsonEncode(_handle(method, path, body ?? {}, query ?? {})),
    );
  }

  dynamic _handle(String method, String path, Json body, Json query) {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    final kind = parts.first;
    if (kind == 'demo' && parts.last == 'notification') {
      account();
      notify(userId!, 'This is a local demo notification. No push was sent.');
      return {'detail': 'Demo notification added.'};
    }
    if (kind == 'health') {
      return {
        'service': 'SkillConnect',
        'status': 'ok',
        'demo_payments': true,
        'online_payments': false,
        'payment_sandbox': true,
      };
    }
    if (kind == 'auth') {
      if (parts[1] == 'register') {
        if (rows('users').any(
          (u) =>
              u['username'] == body['username'] ||
              '${u['email']}'.toLowerCase() == '${body['email']}'.toLowerCase(),
        )) {
          throw ApiException(
            'This demo username or email is already registered.',
          );
        }
        if ('${body['password'] ?? ''}'.length < 8 ||
            !['customer', 'professional'].contains(body['role'])) {
          throw ApiException(
            'Use a valid demo role and a password of at least 8 characters.',
          );
        }
        final row = {
          ...body,
          'id': nextId('users'),
          'is_staff': false,
          'email_verified': false,
        };
        rows('users').add(row);
        if (row['role'] == 'professional') {
          rows('professionals').add({
            'id': nextId('professionals'),
            'user': row['id'],
            'business_name': '${row['first_name']}’s business',
            'bio': '',
            'skills': '',
            'experience_years': 0,
            'category_ids': <int>[],
            'area_ids': <int>[],
            'available': true,
            'verified': false,
            'schedule_enabled': false,
            'starting_price': '0.00',
            'latitude': null,
            'longitude': null,
            'portfolio': <Json>[],
          });
        }
        return publicUser(row);
      }
      if (parts[1] == 'login') {
        final row = rows('users')
            .where(
              (u) =>
                  (u['username'] == body['username'] ||
                      '${u['email']}'.toLowerCase() ==
                          '${body['username']}'.trim().toLowerCase()) &&
                  u['password'] == body['password'],
            )
            .firstOrNull;
        if (row == null) {
          throw ApiException(
            'Incorrect demo email, username or password.',
            401,
          );
        }
        userId = row['id'];
        return publicUser(row);
      }
      if (parts[1] == 'logout') {
        userId = null;
        return null;
      }
      final verification = parts[1] == 'email-verification';
      final email = verification ? account()['email'] : body['email'];
      final target = rows('users')
          .where((u) => '${u['email']}'.toLowerCase() == '$email'.toLowerCase())
          .firstOrNull;
      if (!['password-reset', 'email-verification'].contains(parts[1])) {
        throw ApiException('This demo action is unavailable.');
      }
      final challenges = rows('challenges');
      if (parts.length == 2) {
        challenges.removeWhere(
          (c) => c['email'] == email && c['purpose'] == parts[1],
        );
        if (target != null) {
          challenges.add({
            'id': nextId('challenges'),
            'email': email,
            'purpose': parts[1],
            'used': false,
            'attempts': 0,
            'expires_at': DateTime.now()
                .add(const Duration(minutes: 15))
                .toUtc()
                .toIso8601String(),
          });
        }
        return {
          'detail': 'Demo code: $code. No email is sent in offline mode.',
        };
      }
      final challenge = challenges
          .where((c) => c['email'] == email && c['purpose'] == parts[1])
          .firstOrNull;
      if (target == null ||
          challenge == null ||
          challenge['used'] == true ||
          challenge['attempts'] >= 5 ||
          DateTime.parse(challenge['expires_at']).isBefore(DateTime.now())) {
        throw ApiException('Request a new demo code.');
      }
      challenge['attempts']++;
      if (body['code'] != code) throw ApiException('Use demo code $code.');
      if (verification) {
        target['email_verified'] = true;
      } else {
        if ('${body['new_password'] ?? ''}'.length < 8) {
          throw ApiException('Use at least 8 characters.');
        }
        target['password'] = body['new_password'];
        if (userId == target['id']) userId = null;
      }
      challenge['used'] = true;
      return {
        'detail': verification
            ? 'Demo email marked verified.'
            : 'Demo password updated.',
      };
    }
    if (kind == 'me') {
      final row = account();
      if (method == 'PATCH') {
        if (body['email'] != null && body['email'] != row['email']) {
          if (rows(
            'users',
          ).any((u) => u['id'] != row['id'] && u['email'] == body['email'])) {
            throw ApiException('Email already used in the demo.');
          }
          row['email_verified'] = false;
          rows('challenges').removeWhere((c) => c['email'] == row['email']);
        }
        for (final key in ['first_name', 'last_name', 'email', 'phone']) {
          if (body.containsKey(key)) row[key] = body[key];
        }
      }
      return publicUser(row);
    }
    if (kind == 'categories' || kind == 'areas' || kind == 'packages') {
      return rows(kind);
    }
    if (kind == 'professionals') {
      if (parts.length > 1) {
        final pro = byId(kind, parts[1]);
        if (parts.length == 2) return profile(pro);
        if (parts[2] == 'reviews') {
          return page(
            rows('reviews').where((r) => r['professional'] == pro['id']),
            path,
            query,
          );
        }
        if (parts[2] == 'availability') {
          return {
            'schedule_enabled': pro['schedule_enabled'],
            'slots': pro['available'] != true
                ? []
                : rows('slots')
                      .where(
                        (s) =>
                            s['professional'] == pro['id'] &&
                            DateTime.parse(s['starts_at'])
                                .isAfter(DateTime.now()) &&
                            !conflicts(
                              pro['id'],
                              DateTime.parse(s['starts_at']),
                              DateTime.parse(s['ends_at']),
                            ),
                      )
                      .toList(),
          };
        }
      }
      var list = rows(kind).map((p) => profile(p, query: query)).where((p) {
        final text = '${query['q'] ?? ''}'.toLowerCase();
        return (query['category'] == null ||
                (p['category_ids'] as List).any(
                  (id) => '$id' == '${query['category']}',
                )) &&
            (query['area'] == null ||
                (p['area_ids'] as List).any(
                  (id) => '$id' == '${query['area']}',
                )) &&
            (query['available'] != true && query['available'] != 'true' ||
                p['available'] == true) &&
            (p['rating'] as num) >=
                (double.tryParse('${query['min_rating']}') ?? 0) &&
            (query['max_distance'] == null ||
                p['distance_km'] != null &&
                    p['distance_km'] <=
                        double.parse('${query['max_distance']}')) &&
            '${p['business_name']} ${p['skills']}'.toLowerCase().contains(text);
      }).toList();
      list.sort(
        (a, b) => query['sort'] == 'distance'
            ? ((a['distance_km'] ?? double.infinity) as num).compareTo(
                (b['distance_km'] ?? double.infinity) as num,
              )
            : query['sort'] == 'rating'
            ? (b['rating'] as num).compareTo(a['rating'] as num)
            : ((b['rating'] as num) + (b['promoted'] == true ? .3 : 0))
                  .compareTo(
                    (a['rating'] as num) + (a['promoted'] == true ? .3 : 0),
                  ),
      );
      return page(list, path, query);
    }
    if (kind == 'profile') {
      final pro = ownProfile();
      if (method == 'PATCH') {
        for (final key in [
          'business_name',
          'bio',
          'skills',
          'experience_years',
          'starting_price',
          'latitude',
          'longitude',
          'category_ids',
          'area_ids',
          'available',
          'schedule_enabled',
        ]) {
          if (body.containsKey(key)) pro[key] = body[key];
        }
      }
      return profile(pro);
    }
    if (kind == 'portfolio') {
      final pro = ownProfile(),
          portfolio = (ownProfile()['portfolio'] as List).cast<Json>();
      if (method == 'DELETE') {
        portfolio.removeWhere((p) => '${p['id']}' == parts[1]);
        return null;
      }
      final row = {
        ...body,
        'id': portfolio.fold<int>(0, (n, p) => math.max(n, p['id'] as int)) + 1,
        'image': body['image'],
      };
      (pro['portfolio'] as List).add(row);
      return row;
    }
    if (kind == 'slots') {
      final pro = ownProfile();
      if (method == 'GET') {
        return page(
          rows(kind).where(
            (s) =>
                s['professional'] == pro['id'] &&
                DateTime.parse(s['ends_at']).isAfter(DateTime.now()),
          ),
          path,
          query,
        );
      }
      if (method == 'DELETE') {
        final slot = byId(kind, parts[1]);
        if (slot['professional'] != pro['id']) {
          throw ApiException('This slot belongs to another demo professional.');
        }
        if (rows('bookings').any((b) => b['slot'] == slot['id'])) {
          throw ApiException('This slot has booking history.');
        }
        rows(kind).remove(slot);
        return null;
      }
      final start = DateTime.parse(body['starts_at']),
          end = DateTime.parse(body['ends_at']);
      final duration = end.difference(start).inMinutes;
      if (!start.isAfter(DateTime.now()) ||
          start.isAfter(DateTime.now().add(const Duration(days: 90))) ||
          duration < 30 ||
          duration > 480) {
        throw ApiException(
          'Choose a future 30–480 minute appointment within 90 days.',
        );
      }
      if (rows(kind).any(
            (s) =>
                s['professional'] == pro['id'] &&
                DateTime.parse(s['starts_at']).isBefore(end) &&
                DateTime.parse(s['ends_at']).isAfter(start),
          ) ||
          conflicts(pro['id'], start, end)) {
        throw ApiException('This appointment overlaps another reservation.');
      }
      final row = {...body, 'id': nextId(kind), 'professional': pro['id']};
      rows(kind).add(row);
      return row;
    }
    if (kind == 'bookings' || kind == 'quotes') {
      account();
      if (parts.length == 1) {
        if (method == 'GET') {
          return page(
            rows(kind).where(participant).map((r) => presentedRequest(kind, r)),
            path,
            query,
          );
        }
        if (kind == 'bookings') return createBooking(body);
        if (account()['role'] != 'customer') {
          throw ApiException('Use a customer demo account to request a quote.');
        }
        final pro = byId('professionals', body['professional']);
        if (!pro['available'] ||
            !(pro['category_ids'] as List).contains(body['category']) ||
            !(pro['area_ids'] as List).contains(body['area'])) {
          throw ApiException(
            'Choose an available professional and matching service area.',
          );
        }
        final row = {
          ...body,
          'id': nextId(kind),
          'customer': userId,
          'amount': null,
          'response': '',
          'revision': 0,
          'created_at': now(),
        };
        rows(kind).insert(0, row);
        notify(pro['user'], 'New demo quotation #${row['id']}.');
        return presentedRequest(kind, row);
      }
      final row = requestRow(kind, parts[1]);
      if (parts.length == 2) return presentedRequest(kind, row);
      final isPro =
          byId('professionals', row['professional'])['user'] == userId;
      if (parts[2] == 'messages') {
        final messages = rows('messages')
            .where((m) => m['kind'] == kind && m['request'] == row['id']);
        if (parts.length > 3) {
          for (final m in messages.where(
            (m) => m['sender'] != userId && m['id'] <= body['through_id'],
          )) {
            m['read_at'] ??= now();
          }
          return {'detail': 'Demo messages marked read.'};
        }
        if (method == 'GET') {
          return page(
            messages.toList().reversed.map(
              (m) => {
                ...m,
                'sender_name': '${byId('users', m['sender'])['first_name']}',
              },
            ),
            path,
            query,
          );
        }
        if ('${body['body'] ?? ''}'.trim().isEmpty ||
            '${body['body']}'.length > 2000) {
          throw ApiException('Write a message of up to 2,000 characters.');
        }
        final message = {
          ...body,
          'id': nextId('messages'),
          'kind': kind,
          'request': row['id'],
          'sender': userId,
          'read_at': null,
          'created_at': now(),
        };
        rows('messages').add(message);
        notify(
          isPro
              ? row['customer']
              : byId('professionals', row['professional'])['user'],
          'New demo message on $kind #${row['id']}.',
        );
        return message;
      }
      if (parts[2] == 'status') {
        final options = isPro
            ? {
                'pending': ['accepted', 'rejected'],
                'accepted': ['completed'],
              }
            : {
                'pending': ['cancelled'],
                'accepted': ['cancelled'],
              };
        if (!(options[row['status']] ?? []).contains(body['status'])) {
          throw ApiException('This status change is not allowed.');
        }
        row['status'] = body['status'];
        notify(
          isPro
              ? row['customer']
              : byId('professionals', row['professional'])['user'],
          'Demo booking #${row['id']} is ${row['status']}.',
        );
        return presentedRequest(kind, row);
      }
      if (parts[2] == 'reply') {
        if (!isPro) {
          throw ApiException('Only this demo professional can reply.');
        }
        if (rows('bookings').any((b) => b['quote'] == row['id'])) {
          throw ApiException('This estimate has already been accepted.');
        }
        if ((double.tryParse('${body['amount']}') ?? 0) <= 0 ||
            '${body['response'] ?? ''}'.trim().isEmpty) {
          throw ApiException('Enter a price and included work.');
        }
        row['amount'] = body['amount'];
        row['response'] = body['response'];
        row['revision']++;
        notify(row['customer'], 'Your demo quotation has an estimate.');
        return presentedRequest(kind, row);
      }
      if (parts[2] == 'accept') {
        if (row['customer'] != userId) {
          throw ApiException('Only the demo customer can accept.');
        }
        final existing = rows('bookings')
            .where((b) => b['quote'] == row['id'])
            .firstOrNull;
        if (existing != null) return presentedRequest('bookings', existing);
        if (row['amount'] == null ||
            body['quote_revision'] != row['revision']) {
          throw ApiException('Refresh the estimate before accepting.');
        }
        return createBooking(body, quote: row);
      }
    }
    if (kind == 'reviews') {
      final booking = requestRow('bookings', body['booking']);
      if (booking['customer'] != userId ||
          booking['status'] != 'completed' ||
          rows(kind).any((r) => r['booking'] == booking['id'])) {
        throw ApiException('Review your completed demo booking once.');
      }
      final rating = int.tryParse('${body['rating']}');
      if (rating == null || rating < 1 || rating > 5) {
        throw ApiException('Choose a rating from 1 to 5.');
      }
      final row = {
        ...body,
        'id': nextId(kind),
        'professional': booking['professional'],
        'customer_name': account()['first_name'],
        'created_at': now(),
      };
      rows(kind).add(row);
      return row;
    }
    if (kind == 'reports') {
      account();
      if (method == 'GET') {
        return page(rows(kind).where((r) => r['user'] == userId), path, query);
      }
      final row = {
        ...body,
        'id': nextId(kind),
        'user': userId,
        'resolved': false,
        'resolution': '',
        'created_at': now(),
      };
      rows(kind).insert(0, row);
      return row;
    }
    if (kind == 'notifications') {
      account();
      final mine = rows(kind).where((n) => n['user'] == userId);
      if (method == 'POST') {
        for (final n in mine) {
          n['read'] = true;
        }
        return {'detail': 'Demo notifications marked read.'};
      }
      return page(mine.toList().reversed, path, query);
    }
    if (kind == 'promotions') {
      final pro = ownProfile();
      if (method == 'GET') {
        return page(
          rows(kind).where((p) => p['professional'] == pro['id']),
          path,
          query,
        );
      }
      if (!(pro['category_ids'] as List).contains(body['category']) ||
          !(pro['area_ids'] as List).contains(body['area'])) {
        throw ApiException('Choose one of your services and areas.');
      }
      final package = byId('packages', body['package']);
      final row = {
        ...body,
        'id': nextId(kind),
        'professional': pro['id'],
        'package_name': package['name'],
        'category_name': byId('categories', body['category'])['name'],
        'area_name': byId('areas', body['area'])['name'],
        'price_paid': package['price'],
        'status': 'paid',
        'active': true,
        'starts_at': now(),
        'created_at': now(),
        'expires_at': DateTime.now()
            .add(Duration(days: package['days'] as int))
            .toUtc()
            .toIso8601String(),
      };
      rows(kind).insert(0, row);
      notify(userId!, 'Demo promotion activated. No money was charged.');
      return row;
    }
    if (kind == 'analytics') {
      final user = account(), mine = rows('bookings').where(participant);
      return {
        'bookings': mine.length,
        'completed': mine.where((b) => b['status'] == 'completed').length,
        'pending': mine.where((b) => b['status'] == 'pending').length,
        'quotes': rows('quotes').where(participant).length,
        if (user['role'] == 'professional')
          'rating': profile(ownProfile())['rating'],
        if (user['role'] == 'professional')
          'active_promotions': rows('promotions')
              .where(
                (p) =>
                    p['professional'] == ownProfile()['id'] &&
                    DateTime.parse(p['expires_at']).isAfter(DateTime.now()),
              )
              .length,
      };
    }
    throw ApiException(
      'This action requires a live service and is unavailable in the offline demo.',
    );
  }
}
