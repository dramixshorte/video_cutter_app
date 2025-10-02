<?php
namespace App\Services;

use App\Models\Setting;

class SettingsService
{
    public function get(string $key, string $appId = 'main', $default = null): mixed
    {
        return Setting::query()->where('app_id',$appId)->where('key',$key)->value('value') ?? $default;
    }

    public function set(string $key, string $value = null, string $appId = 'main'): void
    {
        Setting::updateOrCreate(['app_id'=>$appId,'key'=>$key],[ 'value'=>$value ]);
    }

    public function all(string $appId = 'main'): array
    {
        return Setting::query()->where('app_id',$appId)->pluck('value','key')->toArray();
    }
}