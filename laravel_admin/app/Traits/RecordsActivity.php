<?php
namespace App\Traits;

use App\Models\ActivityLog;
use Illuminate\Support\Facades\Auth;

trait RecordsActivity
{
    public static function bootRecordsActivity(): void
    {
        foreach (['created','updated','deleted'] as $event) {
            static::$event(function ($model) use ($event) {
                try {
                    $changes = null;
                    if ($event === 'updated') {
                        $changes = [
                            'old' => array_intersect_key($model->getOriginal(), $model->getDirty()),
                            'new' => $model->getDirty()
                        ];
                    } elseif ($event === 'created') {
                        $changes = ['new' => $model->attributesToArray()];
                    } elseif ($event === 'deleted') {
                        $changes = ['old' => $model->attributesToArray()];
                    }

                    ActivityLog::create([
                        'user_id' => Auth::id(),
                        'action' => $event,
                        'model_type' => get_class($model),
                        'model_id' => $model->getKey(),
                        'changes' => $changes,
                        'ip_address' => request()?->ip(),
                        'user_agent' => request()?->userAgent(),
                    ]);
                } catch (\Throwable $e) {
                    // swallow to not break main flow
                }
            });
        }
    }
}