@extends('layouts.app')
@section('title','Episodes of ' . $series->title)
@section('content')
<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:1rem;">
    <h3 style="margin:0;font-size:1.05rem;">الحلقات: {{ $series->title }}</h3>
    <a class="btn" href="{{ route('admin.series.episodes.create',$series) }}">➕ إضافة</a>
</div>
<div class="table-wrapper card">
<table>
    <thead><tr><th>#</th><th>العنوان</th><th>فعال</th><th>ترتيب</th><th></th></tr></thead>
    <tbody>
    @foreach($episodes as $e)
        <tr>
            <td>{{ $e->id }}</td>
            <td>{{ $e->title }}</td>
            <td>{{ $e->is_active ? 'Yes':'No' }}</td>
            <td>{{ $e->order_index }}</td>
            <td style="display:flex;gap:.5rem;">
                <a href="{{ route('admin.series.episodes.edit',[$series,$e]) }}">Edit</a>
                <form method="POST" action="{{ route('admin.series.episodes.destroy',[$series,$e]) }}" onsubmit="return confirm('Delete episode?')">
                    @csrf @method('DELETE')
                    <button style="background:#b91c1c;color:#fff;">Delete</button>
                </form>
            </td>
        </tr>
    @endforeach
    </tbody>
</table>
{{ $episodes->links() }}
</div>
@endsection