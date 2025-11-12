## Backend Setup (fără Prisma)

1. Creează fișierul `.env` (pornește de la `.env.example` dacă există) cu:
   ```
   DATABASE_URL="postgresql://safety_user:PAROLA@localhost:5432/safety_app"
   PORT=4000
   JWT_ACCESS_SECRET="secret-lung-random"
   JWT_REFRESH_SECRET="alt-secret-lung-random"
   ACCESS_TOKEN_TTL="15m"
   REFRESH_TOKEN_TTL="7d"
   CLIENT_ORIGIN="http://localhost:3000"
   ```

2. Instalează dependențele:
   ```bash
   cd server
   npm install
   ```

3. (Opțional) Creează user-ul și baza de date:
   ```sql
   CREATE DATABASE safety_app;
   CREATE USER safety_user WITH PASSWORD 'PAROLA';
   GRANT CONNECT ON DATABASE safety_app TO safety_user;
   ```

4. Rolează serverul:
   ```bash
   npm run dev
   ```

   La pornire, serverul va crea automat tabelele `users` și `refresh_tokens` dacă nu există.

5. Comenzi utile:
   - `curl -X POST http://localhost:4000/auth/register -H "Content-Type: application/json" -d '{"email":"test@example.com","password":"Parola123!"}'`
   - `curl http://localhost:4000/auth/me -H "Authorization: Bearer <ACCESS_TOKEN>"` (după login)


