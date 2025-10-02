<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\RecordsActivity;

class CoinPackage extends Model
{
    use HasFactory, RecordsActivity;

    protected $fillable = [ 'name','coins','price','is_active','app_id' ];

    protected $casts = [ 'is_active' => 'boolean' ];
}