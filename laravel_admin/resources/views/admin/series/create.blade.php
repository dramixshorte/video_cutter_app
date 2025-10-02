@extends('layouts.app')
@section('title','Create Series')
@section('content')
<div class="card" style="max-width:560px;">
    <h3 style="margin-top:0;font-size:1.05rem;">إضافة مسلسل جديد</h3>
    <form method="POST" action="{{ route('admin.series.store') }}" class="grid" style="gap:1rem;">
        @csrf
        <label>العنوان
            <input type="text" name="title" required />
        </label>
        <label>الوصف
            <textarea name="description"></textarea>
        </label>
        <div style="display:flex;gap:1rem;">
            <label style="flex:1;">الترتيب
                <input type="number" name="order_index" value="0" />
            </label>
            <label style="align-self:flex-end;margin-top:1.35rem;display:flex;flex-direction:row;align-items:center;gap:.4rem;font-weight:400;">
                <input type="checkbox" name="is_active" value="1" checked /> فعال
            </label>
        </div>
        <div style="display:flex;justify-content:flex-end;gap:.5rem;">
            <a href="{{ route('admin.series.index') }}" class="btn" style="background:var(--color-surface);border:1px solid var(--color-border);">رجوع</a>
            <button type="submit">حفظ</button>
        </div>
    </form>
</div>
@endsection