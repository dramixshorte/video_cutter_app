<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\RecordsActivity;

class DailyGift extends Model
{
    use HasFactory, RecordsActivity;

    protected $fillable = [ 'name','day_number','coins','is_active','app_id' ];

    protected $casts = [ 'is_active' => 'boolean' ];
}