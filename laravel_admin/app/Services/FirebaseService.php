<?php
namespace App\Services;

use App\Models\Notification;
use Kreait\Firebase\Contract\Messaging;
use Illuminate\Support\Facades\Log;

class FirebaseService
{
    public function __construct(private readonly Messaging $messaging) {}

    public function sendNotification(string $title, ?string $body = null, ?string $topic = null, array $payload = [], string $appId = 'main'): Notification
    {
        $notification = Notification::create([
            'title' => $title,
            'body' => $body,
            'target_topic' => $topic,
            'payload' => $payload,
            'app_id' => $appId,
            'sent_at' => now(),
        ]);

        try {
            $message = [
                'notification' => [
                    'title' => $title,
                    'body' => $body,
                ],
                'data' => array_map('strval',$payload),
            ];
            if ($topic) {
                $this->messaging->sendMulticast($message + ['topic' => $topic]);
            }
        } catch (\Throwable $e) {
            Log::error('Firebase send failed', ['error'=>$e->getMessage()]);
        }

        return $notification;
    }
}