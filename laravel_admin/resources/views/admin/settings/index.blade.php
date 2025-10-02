@extends('layouts.app')
@section('title','Settings')
@section('content')
<h3 style="margin:0 0 1rem;font-size:1.05rem;">الإعدادات (التطبيق: main)</h3>
<div class="card" style="max-width:520px;margin-bottom:1.25rem;">
    <form method="POST" action="{{ route('admin.settings.store') }}" class="grid" style="gap:1rem;">
        @csrf
        <label>المفتاح
            <input type="text" name="key" required />
        </label>
        <label>القيمة
            <textarea name="value"></textarea>
        </label>
        <div style="display:flex;justify-content:flex-end;">
            <button type="submit">حفظ / تحديث</button>
        </div>
    </form>
</div>
<div class="table-wrapper card">
<table>
    <thead><tr><th>#</th><th>المفتاح</th><th>القيمة</th><th></th></tr></thead>
    <tbody>
    @foreach($settings as $setting)
        <tr>
            <td>{{ $setting->id }}</td>
            <td>{{ $setting->key }}</td>
            <td style="max-width:320px;overflow-wrap:anywhere;">{{ $setting->value }}</td>
            <td>
                <form method="POST" action="{{ route('admin.settings.destroy',$setting) }}" onsubmit="return confirm('Delete setting?')">
                    @csrf @method('DELETE')
                    <button class="danger" style="padding:.4rem .7rem;">حذف</button>
                </form>
            </td>
        </tr>
    @endforeach
    </tbody>
</table>
</div>
@endsection