<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class AdmobConfig extends Model
{
    use HasFactory;

    protected $fillable = [ 'app_id','banner_ad_unit','interstitial_ad_unit','rewarded_ad_unit','is_active' ];

    protected $casts = [ 'is_active' => 'boolean' ];
}