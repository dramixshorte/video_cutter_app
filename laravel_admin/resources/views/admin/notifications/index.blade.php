@extends('layouts.app')
@section('title','Notifications')
@section('content')
<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:1rem;">
    <h3 style="margin:0;font-size:1.05rem;">الإشعارات</h3>
    <a class="btn" href="{{ route('admin.notifications.create') }}">➕ إرسال</a>
</div>
<div class="table-wrapper card">
<table>
    <thead><tr><th>#</th><th>العنوان</th><th>الموضوع</th><th>التاريخ</th></tr></thead>
    <tbody>
    @foreach($notifications as $n)
        <tr>
            <td>{{ $n->id }}</td>
            <td>{{ $n->title }}</td>
            <td>{{ $n->target_topic ?? '-' }}</td>
            <td>{{ $n->sent_at ?? '-' }}</td>
        </tr>
    @endforeach
    </tbody>
</table>
{{ $notifications->links() }}
</div>
@endsection