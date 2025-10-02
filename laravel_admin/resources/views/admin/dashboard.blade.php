@extends('layouts.app')
@section('title','Dashboard')
@section('content')
<h3 style="margin:0 0 1rem;font-size:1.05rem;">إحصائيات سريعة</h3>
<div class="grid cols-4">
    <div class="card stat"><h5>المسلسلات</h5><strong>{{ $stats['series_count'] }}</strong></div>
    <div class="card stat"><h5>الحلقات</h5><strong>{{ $stats['episodes_count'] }}</strong></div>
    <div class="card stat"><h5>الإشعارات</h5><strong>{{ $stats['notifications_sent'] }}</strong></div>
    <div class="card stat"><h5>باقات العملات</h5><strong>{{ $stats['coin_packages'] }}</strong></div>
</div>
@endsection