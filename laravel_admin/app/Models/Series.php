<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use App\Traits\RecordsActivity;

class Series extends Model
{
    use HasFactory, RecordsActivity;

    protected $fillable = [
        'title','description','image_path','is_active','order_index','app_id'
    ];

    protected $casts = [
        'is_active' => 'boolean',
    ];

    public function episodes(): HasMany
    {
        return $this->hasMany(Episode::class)->orderBy('order_index');
    }
}