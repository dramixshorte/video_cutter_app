@extends('layouts.app')
@section('title','Series')
@section('content')
<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:1rem;">
    <h3 style="margin:0;font-size:1.1rem;">المسلسلات</h3>
    <a class="btn" href="{{ route('admin.series.create') }}">➕ إضافة</a>
</div>
<div class="table-wrapper card">
<table>
    <thead><tr><th>ID</th><th>Title</th><th>Active</th><th>Order</th><th>Episodes</th><th></th></tr></thead>
    <tbody>
    @foreach($series as $s)
        <tr>
            <td>{{ $s->id }}</td>
            <td><a href="{{ route('admin.series.episodes.index',$s) }}">{{ $s->title }}</a></td>
            <td>{{ $s->is_active ? 'Yes':'No' }}</td>
            <td>{{ $s->order_index }}</td>
            <td>{{ $s->episodes()->count() }}</td>
            <td style="display:flex;gap:.5rem;">
                <a href="{{ route('admin.series.edit',$s) }}">Edit</a>
                <form method="POST" action="{{ route('admin.series.destroy',$s) }}" onsubmit="return confirm('Delete series?')">
                    @csrf @method('DELETE')
                    <button style="background:#b91c1c;color:#fff;">Delete</button>
                </form>
            </td>
        </tr>
    @endforeach
    </tbody>
</table>
{{ $series->links() }}
</div>
@endsection