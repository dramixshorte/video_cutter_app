@extends('layouts.app')
@section('title','Add Episode')
@section('content')
<div class="card" style="max-width:600px;">
    <h3 style="margin-top:0;font-size:1.05rem;">إضافة حلقة ({{ $series->title }})</h3>
    <form method="POST" action="{{ route('admin.series.episodes.store',$series) }}" class="grid" style="gap:1rem;">
        @csrf
        <label>العنوان
            <input type="text" name="title" required />
        </label>
        <label>الوصف
            <textarea name="description"></textarea>
        </label>
        <label>مسار الفيديو (مرجع)
            <input type="text" name="video_path" required />
        </label>
        <div style="display:flex; gap:1rem;">
            <label style="flex:1;">المدة (ثوانٍ)
                <input type="number" name="duration" />
            </label>
            <label style="flex:1;">الترتيب
                <input type="number" name="order_index" value="0" />
            </label>
            <label style="align-self:flex-end;margin-top:1.35rem;display:flex;flex-direction:row;align-items:center;gap:.4rem;font-weight:400;">
                <input type="checkbox" name="is_active" value="1" checked /> فعال
            </label>
        </div>
        <div style="display:flex;justify-content:space-between;">
            <a href="{{ route('admin.series.episodes.index',$series) }}" class="btn" style="background:var(--color-surface);border:1px solid var(--color-border);">رجوع</a>
            <button type="submit">حفظ</button>
        </div>
    </form>
</div>
@endsection