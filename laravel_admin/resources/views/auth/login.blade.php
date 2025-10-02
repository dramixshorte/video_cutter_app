<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1.0" />
    <title>تسجيل الدخول</title>
    <link rel="stylesheet" href="/css/app.css?v={{ time() }}" />
    <style>
      body { display:flex; align-items:center; justify-content:center; min-height:100vh; }
      .login-card { width:100%; max-width:380px; background:var(--color-surface); padding:1.75rem 1.5rem; border:1px solid var(--color-border); border-radius:var(--radius-md); box-shadow:var(--shadow-md); }
      .login-card h1 { margin:0 0 1.2rem; font-size:1.1rem; text-align:center; }
      .error-msg { background:#7f1d1d; color:#fff; padding:.55rem .75rem; font-size:.7rem; border-radius:var(--radius-sm); margin-top:.4rem; }
    </style>
</head>
<body>
  <div class="login-card">
    <h1>لوحة الإدارة</h1>
    <form method="POST" action="{{ route('login.attempt') }}" class="grid" style="gap:1rem;">
      @csrf
      <label>البريد الإلكتروني
        <input type="email" name="email" value="{{ old('email') }}" required autofocus />
        @error('email')<div class="error-msg">{{ $message }}</div>@enderror
      </label>
      <label>كلمة المرور
        <input type="password" name="password" required />
      </label>
      <label style="display:flex; flex-direction:row; align-items:center; gap:.5rem; font-weight:400;">
        <input type="checkbox" name="remember" value="1" /> تذكرني
      </label>
      <button type="submit" style="width:100%;">دخول</button>
    </form>
  </div>
</body>
</html>