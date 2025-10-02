<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Notification extends Model
{
    use HasFactory;

    protected $fillable = [ 'title','body','target_topic','payload','sent_at','app_id' ];

    protected $casts = [
        'payload' => 'array',
        'sent_at' => 'datetime'
    ];
}