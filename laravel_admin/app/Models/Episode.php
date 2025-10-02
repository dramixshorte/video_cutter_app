<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use App\Traits\RecordsActivity;

class Episode extends Model
{
    use HasFactory, RecordsActivity;

    protected $fillable = [
        'series_id','title','description','video_path','duration','is_active','order_index','app_id'
    ];

    protected $casts = [
        'is_active' => 'boolean',
    ];

    public function series(): BelongsTo
    {
        return $this->belongsTo(Series::class);
    }
}