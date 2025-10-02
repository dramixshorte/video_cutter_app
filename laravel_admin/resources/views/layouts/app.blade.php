<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>لوحة الإدارة - @yield('title','الرئيسية')</title>
    <link rel="stylesheet" href="/css/app.css?v={{ time() }}" />
    @stack('head')
</head>
<body class="dark">
<div class="layout">
    <aside class="sidebar">
        <h1>لوحة التحكم</h1>
        <nav class="nav-group">
            <a href="{{ route('admin.dashboard') }}" class="{{ request()->routeIs('admin.dashboard') ? 'active' : '' }}">📊 <span>الاحصائيات</span></a>
            <a href="{{ route('admin.series.index') }}" class="{{ request()->routeIs('admin.series.*') ? 'active' : '' }}">🎬 <span>المسلسلات</span></a>
            <a href="{{ route('admin.settings.index') }}" class="{{ request()->routeIs('admin.settings.*') ? 'active' : '' }}">⚙️ <span>الإعدادات</span></a>
            <a href="{{ route('admin.notifications.index') }}" class="{{ request()->routeIs('admin.notifications.*') ? 'active' : '' }}">🔔 <span>الإشعارات</span></a>
            <a href="{{ route('admin.activity.index') }}" class="{{ request()->routeIs('admin.activity.*') ? 'active' : '' }}">📑 <span>النشاط</span></a>
        </nav>
        <div class="footer">الإصدار المبدئي • {{ date('Y') }}</div>
    </aside>
    <div class="main">
        <header class="topbar">
            <div class="actions">
                <button class="toggle-theme" id="themeToggle" type="button">الوضع الفاتح</button>
                <button class="toggle-theme" id="dirToggle" type="button">LTR</button>
            </div>
            <strong style="font-size:.8rem;color:var(--color-text-dim);">Video Cutter Admin</strong>
        </header>
        <div class="content-wrapper">
            @if(session('status'))<div class="flash">{{ session('status') }}</div>@endif
            @yield('content')
        </div>
    </div>
</div>
<script>
  const root = document.documentElement;
  const themeBtn = document.getElementById('themeToggle');
  const dirBtn = document.getElementById('dirToggle');
  let light = false; let rtl = true;
  themeBtn?.addEventListener('click', ()=>{
    light = !light;
    if(light){ root.classList.add('light'); themeBtn.textContent='الوضع الداكن'; }
    else { root.classList.remove('light'); themeBtn.textContent='الوضع الفاتح'; }
  });
  dirBtn?.addEventListener('click', ()=>{
    rtl = !rtl;
    if(rtl){ root.setAttribute('dir','rtl'); dirBtn.textContent='LTR'; }
    else { root.setAttribute('dir','ltr'); dirBtn.textContent='RTL'; }
  });
</script>
@stack('scripts')
</body>
</html>