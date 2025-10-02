@extends('layouts.app')
@section('title','Send Notification')
@section('content')
<div class="card" style="max-width:560px;">
    <h3 style="margin-top:0;font-size:1.05rem;">إرسال إشعار</h3>
    <form method="POST" action="{{ route('admin.notifications.store') }}" class="grid" style="gap:1rem;">
        @csrf
        <label>العنوان
            <input type="text" name="title" required />
        </label>
        <label>النص
            <textarea name="body"></textarea>
        </label>
        <label>الموضوع (اختياري)
            <input type="text" name="target_topic" />
        </label>
        <div style="display:flex;justify-content:space-between;">
            <a href="{{ route('admin.notifications.index') }}" class="btn" style="background:var(--color-surface);border:1px solid var(--color-border);">رجوع</a>
            <button type="submit">إرسال</button>
        </div>
    </form>
</div>
@endsection