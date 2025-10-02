@extends('layouts.app')
@section('title','سجل النشاط')
@section('content')
<h3 style="margin:0 0 1rem;font-size:1.05rem;">سجل النشاط</h3>
<div class="table-wrapper card" style="margin-bottom:1rem;">
<table>
  <thead>
    <tr><th>#</th><th>العملية</th><th>الموديل</th><th>المعرف</th><th>المستخدم</th><th>التغييرات</th><th>التاريخ</th></tr>
  </thead>
  <tbody>
  @foreach($logs as $log)
    <tr>
      <td>{{ $log->id }}</td>
      <td><span class="badge">{{ $log->action }}</span></td>
      <td style="font-size:.65rem;">{{ class_basename($log->model_type) }}</td>
      <td>{{ $log->model_id ?? '-' }}</td>
      <td>{{ $log->user?->name ?? 'System' }}</td>
      <td style="max-width:240px;overflow-wrap:anywhere; font-size:.6rem;">
        @if($log->changes)
          {{ json_encode($log->changes, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) }}
        @else - @endif
      </td>
      <td>{{ $log->created_at }}</td>
    </tr>
  @endforeach
  </tbody>
</table>
</div>
{{ $logs->links() }}
@endsection