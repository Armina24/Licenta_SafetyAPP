# Troubleshooting - De Ce Nu Apar Datele în Tabele

## Problema 1: "Contactele nu apar în tabela `emergency_contacts`"

### Verifică 1️⃣: Backend-ul este pornit?
```bash
# Terminal 1: Start backend
cd server
npm run dev

# Ar trebui să vezi:
# API listening on http://0.0.0.0:4000
```

### Verifică 2️⃣: Utilizatorul este autentificat?
- Contactele se salvează doar pentru utilizatorii loggați
- Verifică dacă `accessToken` este salvat în `shared_preferences`

### Verifică 3️⃣: API URL corect?
```dart
// În api_client.dart
// Dacă ești pe Android emulator:
return 'http://10.0.2.2:4000'; // ← CORRECT pentru emulator
// NU: 'http://localhost:4000' (aceasta e eroare comună!)

// Dacă ești pe device real:
return 'http://192.168.0.103:4000'; // Schimbă cu IP-ul PC-ului tău
```

### Verifică 4️⃣: Se trimit requesturile la server?
Adaugă logging în `emergency_contacts_service.dart`:
```dart
debugPrint('➡️ POST /api/emergency-contacts');
final response = await _client.post(
  _api.buildUri('/api/emergency-contacts'),
  headers: {...},
  body: jsonEncode(body),
);
debugPrint('⬅️ Response: ${response.statusCode}');
debugPrint('Body: ${response.body}');
```

### Verifică 5️⃣: Token-ul este valid?
```bash
# Testează authentication
curl -X POST http://localhost:4000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"password123"}'

# Ar trebui să primești:
# {"accessToken":"eyJ...","refreshToken":"eyJ..."}
```

---

## Problema 2: "Alertele nu apar în `alerts_history`"

### Verifică 1️⃣: SOS-ul se trimite?
```dart
// Adaugă debugging în home_page.dart _sendSos()
debugPrint('📍 Sending SOS...');
final result = await _emergencyService.sendManualSos();
debugPrint('📊 Result: ${result.success}');
debugPrint('📧 Message: ${result.userMessage}');
```

### Verifică 2️⃣: AlertsService este apelat?
```dart
// Verifică dacă logarea la server se întâmplă:
debugPrint('📡 Logging alert to server...');
try {
  await AlertsService.instance.logAlert(
    status: result.success ? 'sent' : 'failed',
    contactsReached: result.success ? 1 : 0,
    message: result.userMessage,
  );
  debugPrint('✅ Alert logged successfully');
} catch (e) {
  debugPrint('❌ Failed to log alert: $e');
}
```

### Verifică 3️⃣: Server primește POST?
```bash
# Testează endpoint-ul direct
curl -X POST http://localhost:4000/api/alerts \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "status": "sent",
    "contactsReached": 1,
    "message": "Test alert"
  }'

# Ar trebui să primești un 201 response
```

### Verifică 4️⃣: Baza de date primește datele?
```bash
# Conectează-te la PostgreSQL
psql -U safety_user -d safety_app

# Verifică tabelul
SELECT * FROM alerts_history ORDER BY timestamp DESC LIMIT 10;

# Ar trebui să vezi rândurile tale nou adăugate
```

---

## Problema 3: "Profilul nu se actualizează"

### Verifică 1️⃣: getName() face request?
```dart
// În profile_page.dart _editName()
debugPrint('📝 Updating profile...');
await prefs.setString('fullName', _nameEditController.text);

debugPrint('➡️ Sending to server...');
await ProfileService.instance.updateProfile(
  displayName: _nameEditController.text,
);
debugPrint('✅ Profile updated');
```

### Verifică 2️⃣: Server primește update?
```bash
curl -X POST http://localhost:4000/api/profile \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"displayName":"John Doe"}'
```

### Verifică 3️⃣: Baza de date?
```bash
psql -U safety_user -d safety_app
SELECT * FROM user_profiles WHERE user_id = 1;
```

---

## Problema 4: "Iau 401 Unauthorized"

### Soluție:
Token-ul a expirat sau nu este valid.

```dart
// În services/auth_service.dart, adaugă refresh token logic:
if (response.statusCode == 401) {
  // Token expired, try refresh
  final prefs = await SharedPreferences.getInstance();
  final refreshToken = prefs.getString('refreshToken');
  
  if (refreshToken != null) {
    try {
      final newTokens = await _refreshAccessToken(refreshToken);
      // Retry original request with new token
    } catch (_) {
      // Need to re-login
    }
  }
}
```

---

## Problema 5: "Network error - connection refused"

### Causes:
1. Backend nu este pornit
2. URL-ul API este greșit
3. Firewall-ul blochează conexiunea

### Solutions:
```bash
# 1. Verifica dacă backend-ul rulează
lsof -i :4000  # Mac/Linux
netstat -ano | findstr :4000  # Windows

# 2. Testează conexiunea
ping 192.168.0.103  # Schimbă cu IP-ul tău

# 3. Testează portul
curl http://192.168.0.103:4000/health
# Ar trebui să primești: {"status":"ok"}
```

---

## Checklist de Debugging

- [ ] Backend rulează pe `npm run dev`
- [ ] Database (PostgreSQL) este conectat
- [ ] `.env` în server are valori corecte
- [ ] `API_BASE_URL` în app este corect pentru device-ul tău
- [ ] Utilizatorul este logat (are token valid)
- [ ] Network requests ajung la server (verific în console)
- [ ] Server răspunde cu 200/201 statusuri
- [ ] Datele sunt în baza de date (verific cu `psql`)

---

## Comenzi Utile

### Check server health
```bash
curl http://localhost:4000/health
```

### Check PostgreSQL connection
```bash
psql -U safety_user -d safety_app -c "SELECT version();"
```

### View all contacts
```bash
psql -U safety_user -d safety_app -c "SELECT * FROM emergency_contacts;"
```

### View all alerts
```bash
psql -U safety_user -d safety_app -c "SELECT * FROM alerts_history ORDER BY timestamp DESC;"
```

### View user profiles
```bash
psql -U safety_user -d safety_app -c "SELECT * FROM user_profiles;"
```

### Clear all test data
```bash
psql -U safety_user -d safety_app -c "DELETE FROM emergency_contacts; DELETE FROM alerts_history; DELETE FROM user_profiles;"
```

---

## Teste Manual

### Test 1: Add Contact
1. Open app
2. Go to Contacts page
3. Add a contact: "Mom, +40712345678"
4. Check PostgreSQL:
   ```bash
   SELECT * FROM emergency_contacts WHERE name = 'Mom';
   ```
   Should see the entry

### Test 2: Send SOS
1. Click SOS button
2. Check if AlertsService.instance.logAlert() was called
3. Check PostgreSQL:
   ```bash
   SELECT * FROM alerts_history ORDER BY timestamp DESC LIMIT 1;
   ```
   Should see the alert

### Test 3: Update Profile
1. Go to Profile
2. Change display name
3. Check PostgreSQL:
   ```bash
   SELECT * FROM user_profiles WHERE user_id = YOUR_USER_ID;
   ```
   Should see updated name

---

## Contact Support
Dacă problemele persistă:
1. Verifica console logs în Android Studio / terminal
2. Verifica server logs
3. Verifica PostgreSQL logs
4. Crează un issue cu screenshot-uri și logs
