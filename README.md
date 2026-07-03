# Kore - Aplicație mobilă pentru siguranță personală

Kore - Anderca Armina-Florena

## Descrierea aplicației

Aplicația a fost creată pentru a fi de ajutor în orice tip de situație de urgență. Aceasta a fost dezvoltată pentru Android, fiind testată pe un dispozitiv fizic (Samsung Galaxy A13, Android 13).

Aceasta ajută utilizatorii să își asigure siguranța personală prin monitorizarea în timp real a mediului înconjurător și prin trimiterea rapidă a alertelor de urgență. Sistemul oferă funcționalități avansate precum detectarea automată a sunetelor care pot indica o alertă (țipete, spargeri, aglomerație) cu ajutorul unui model de inteligență artificială (YAMNet), monitorizarea mișcărilor bruște și un cronometru de siguranță  care declanșează SOS-ul. Aplicația oferă suport offline pentru trimiterea alertelor prin SMS direct prin rețeaua GSM și simulează apeluri false.

Link către repository: https://github.com/Armina24/Licenta_SafetyAPP

---

## Structura Proiectului

Acest proiect este format din două componente principale:

* **Backend** (server): Server backend realizat în Node.js cu Express.js și PostgreSQL pentru autentificare, gestionarea profilurilor, sincronizarea contactelor de urgență și stocarea istoricului de alerte.
* **Frontend** (aplicația propriu-zisă): Aplicație mobilă cross-platform realizată în Flutter (Dart) pentru dispozitive Android și iOS.

---

## Cerințe preliminare

Înainte de a rula acest proiect, asigură-te că ai instalat următoarele:

* **Node.js** (versiunea 18 sau mai nouă)
* **PostgreSQL** (instalare locală sau server la distanță)
* **Git**
* **Flutter SDK** (versiunea 3.9.2 sau mai nouă)
* **Dart SDK** (inclus automat în Flutter)
* **Visual Studio Code** (editor recomandat)
* Dispozitiv fizic Android (cu depanarea USB activată)

---

## Instalare & Configurare

### 1. Clonează Repository-ul

```bash
git clone <your-repository-url>
cd safety_app
```

### 2. Configurare Backend

1. Navighează în directorul backend:
   ```bash
   cd server
   ```
2. Instalează dependențele necesare:
   ```bash
   npm install
   ```
3. Configurează variabilele de mediu: Creează un fișier `.env` în directorul principal al backend-ului (`server/`):
   ```env
   DATABASE_URL="postgresql://safety_user:PAROLA_TA@localhost:5432/safety_app"
   PORT=4000
   JWT_ACCESS_SECRET="cheie-secreta-jwt"
   JWT_REFRESH_SECRET="cheie-secreta-jwt-refresh"
   ACCESS_TOKEN_TTL="15m"
   REFRESH_TOKEN_TTL="7d"
   GOOGLE_WEB_CLIENT_ID="ID-UL_GOOGLE.apps.googleusercontent.com"
   CLIENT_ORIGIN="http://localhost:3000"
   DB_SSL=false
   EMAIL_FROM="EMAIL-UL_TAU"
   EMAIL_PASS="PAROLA_EMAIL-ULUI"
   ```
4. Configurează baza de date PostgreSQL:
   - Asigură-te că serverul PostgreSQL este pornit.
   - Conectează-te la serverul PostgreSQL și creează baza de date și utilizatorul:
     ```sql
     CREATE DATABASE safety_app;
     CREATE USER safety_user WITH PASSWORD 'PAROLA_TA';
     GRANT CONNECT ON DATABASE safety_app TO safety_user;
     ```
   - La pornire, serverul Node.js va detecta automat baza de date și va genera toate tabelele necesare (`users`, `refresh_tokens`, `user_profiles`, `emergency_contacts`, `alerts_history`, `location_share_sessions`).
5. Pornește serverul backend:
   ```bash
   npm run dev
   ```
   Serverul va porni în modul de dezvoltare pe portul 4000 (implicit).

### 3. Configurare Frontend

1. Întoarce-te în directorul rădăcină (unde se află proiectul Flutter):
   ```bash
   cd ..
   ```
2. Instalează dependențele Flutter:
   ```bash
   flutter pub get
   ```
3. Configurarea URL-ului backend-ului:
   - În mod implicit, URL-ul serverului este definit în [api_client.dart](file:///c:/Users/Armina/Flutter/Licenta/safety_app/lib/services/api_client.dart) (care alege automat `http://localhost:4000` pentru Web/iOS și `http://192.168.1.134:4000` sau IP-ul local pentru emulatorul Android).
   - Pentru a rula pe un dispozitiv fizic sau a direcționa aplicația către o altă adresă IP a serverului, utilizează parametrul `--dart-define` la lansare:
     ```bash
     flutter run --dart-define=API_BASE_URL=http://<IP_CALCULATOR_DEZVOLTARE>:4000
     ```

---

## Testarea aplicației

Având în vedere că aplicația a fost dezvoltată și testată cu precădere pe un dispozitiv Android, iată pașii necesari:

1. Activează **USB Debugging** (din setările telefonului, secțiunea "Developer options" - pentru a o activa, mergi la "About phone" și apasă de 7 ori pe "Build number") pe dispozitivul Android fizic.
2. Asigură-te că atât telefonul cât și calculatorul de dezvoltare sunt conectate în **aceeași rețea Wi-Fi**.
3. Rulează comanda următoare pentru a vedea dacă dispozitivul Android este conectat corect:
   ```bash
   flutter devices
   ```
4. Apoi rulează, o singură dată este suficent, comanda:

   ```bash
   flutter run -d <id-ul-dispozitivului-tau>
   ```
5. Apoi rulează, de fiecare dată, comanda:
   ```bash
   flutter run
   ```

---

## Rularea clasică a aplicației

După ce au fost parcurși toți pașii pentru instalare și configurare, iată cele 2 comenzi necesare pentru a rula simultan frontend-ul și backend-ul în timpul dezvoltării:

1. **Terminal 1 - Backend**:
   ```bash
   cd server
   npm run dev
   ```
2. **Terminal 2 - Frontend**:
   ```bash
   flutter run
   ```

---

## Probleme frecvente

* **PostgreSQL Connection Error**: Asigură-te că serviciul PostgreSQL rulează local pe calculator și că datele de conectare (utilizator, parolă, bază de date) din `.env` coincid exact cu cele configurate în PostgreSQL.
* **Network Error / Connection Refused pe dispozitivul fizic**: Dacă rulezi aplicația pe un telefon fizic, asigură-te că atât telefonul cât și calculatorul de dezvoltare sunt conectate în **aceeași rețea Wi-Fi**. De asemenea, pornește aplicația utilizând parametrul `--dart-define` specificând IP-ul local al calculatorului tău (nu `localhost` sau `127.0.0.1`).
* **Permisiuni lipsă**: Anumite funcționalități (cum ar fi localizarea GPS, rularea serviciului de fundal sau capturarea audio în timp real) necesită acceptarea permisiunilor de către utilizator la prima rulare. Asigură-te că ai permis accesul la Locație, SMS, Notificări și Microfon.