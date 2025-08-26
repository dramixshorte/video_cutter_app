<?php
// notification_test.php
require __DIR__ . '/vendor/autoload.php';
use Kreait\Firebase\Factory;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification;

// إعدادات الصفحة
header('Content-Type: text/html; charset=utf-8');
ini_set('display_errors', 1);
error_reporting(E_ALL);

// عداد عدد مرات الإرسال
session_start();
if (!isset($_SESSION['send_count'])) {
    $_SESSION['send_count'] = 0;
}
$_SESSION['send_count']++;

// بيانات الإشعار بنفس شكل الصورة تماماً
$notificationData = [
    'type' => 'new_series',
    'series_id' => '123',
    'series_title' => 'حاملة نظيفة في الشركة',
    'series_description' => 'وجدت تنمراً بين الموظفين، وقررت أن تنتكر كعاملة نظيفة لكشف الحقيقة.',
    'image_url' => 'https://i.ytimg.com/vi/drnwJuK_-lY/mqdefault.jpg',
    'send_count' => $_SESSION['send_count'],
    'timestamp' => date('Y-m-d H:i:s')
];

try {
    $factory = (new Factory)->withServiceAccount(__DIR__ . '/firebase-service-account.json');
    $messaging = $factory->createMessaging();

    // إنشاء الإشعار
    $notification = Notification::create(
        'حاملة نظيفة في الشركة',
        'وجدت تنمراً بين الموظفين، وقررت أن تنتكر كعاملة نظيفة لكشف الحقيقة.'
    );

    // تكوين الرسالة
    $message = CloudMessage::withTarget('topic', 'all')
        ->withNotification($notification)
        ->withData($notificationData)
        ->withAndroidConfig([
            'priority' => 'high',
            'notification' => [
                'channel_id' => 'professional_series_channel',
                'color' => '#FF0000',
                'sound' => 'notification_sound',
                'visibility' => 'public',
                'icon' => 'ic_notification',
                'tag' => 'series_123',
                'image' => 'https://i.ytimg.com/vi/drnwJuK_-lY/mqdefault.jpg'
            ]
        ])
        ->withApnsConfig([
            'payload' => [
                'aps' => [
                    'alert' => [
                        'title' => 'حاملة نظيفة في الشركة',
                        'body' => 'وجدت تنمراً بين الموظفين، وقررت أن تنتكر كعاملة نظيفة لكشف الحقيقة.'
                    ],
                    'sound' => 'default',
                    'mutable-content' => 1,
                    'badge' => 1,
                    'category' => 'series_notifications'
                ],
                'fcm_options' => [
                    'image' => 'https://i.ytimg.com/vi/drnwJuK_-lY/mqdefault.jpg'
                ]
            ]
        ]);

    $result = $messaging->send($message);
    $success = true;
    $error = '';
    
} catch (Exception $e) {
    $error = $e->getMessage();
    $success = false;
}
?>

<!DOCTYPE html>
<html dir="rtl">
<head>
    <meta charset="UTF-8">
    <title>تجربة الإشعارات - تطبيق المسلسلات</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #0c0c0c 0%, #1a1a1a 100%);
            color: white;
            text-align: center;
            padding: 20px;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        
        .container {
            background: rgba(40, 40, 40, 0.8);
            padding: 30px;
            border-radius: 20px;
            backdrop-filter: blur(10px);
            max-width: 600px;
            width: 100%;
            margin: 20px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.6);
            border: 1px solid rgba(255, 0, 0, 0.3);
        }
        
        h1 {
            color: #e50914;
            margin-bottom: 25px;
            font-size: 28px;
            font-weight: bold;
            text-shadow: 0 0 10px rgba(229, 9, 20, 0.5);
        }
        
        .status-box {
            padding: 20px;
            border-radius: 15px;
            margin: 20px 0;
            background: rgba(30, 30, 30, 0.9);
            border: 1px solid rgba(255, 0, 0, 0.2);
        }
        
        .success {
            background: linear-gradient(135deg, #1a5c1e 0%, #0f3b12 100%);
            border: none;
        }
        
        .error {
            background: linear-gradient(135deg, #8B0000 0%, #600000 100%);
            border: none;
        }
        
        .info {
            background: linear-gradient(135deg, #1E3A5F 0%, #0F1F33 100%);
            border: none;
            margin: 15px 0;
        }
        
        h2 {
            margin-bottom: 15px;
            font-size: 22px;
            font-weight: 600;
        }
        
        p {
            margin: 8px 0;
            font-size: 16px;
            line-height: 1.5;
        }
        
        strong {
            color: #e50914;
            font-weight: 600;
        }
        
        .button-group {
            display: flex;
            flex-direction: column;
            gap: 15px;
            margin: 25px 0;
        }
        
        button {
            background: linear-gradient(135deg, #e50914 0%, #b8070f 100%);
            color: white;
            border: none;
            padding: 18px 35px;
            font-size: 18px;
            font-weight: 600;
            border-radius: 12px;
            cursor: pointer;
            transition: all 0.3s ease;
            box-shadow: 0 4px 15px rgba(229, 9, 20, 0.4);
        }
        
        button:hover {
            transform: translateY(-2px);
            box-shadow: 0 6px 20px rgba(229, 9, 20, 0.6);
            background: linear-gradient(135deg, #ff1a27 0%, #e50914 100%);
        }
        
        button:active {
            transform: translateY(0);
        }
        
        .secondary-button {
            background: linear-gradient(135deg, #333333 0%, #222222 100%);
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.3);
        }
        
        .secondary-button:hover {
            background: linear-gradient(135deg, #444444 0%, #333333 100%);
            box-shadow: 0 6px 20px rgba(0, 0, 0, 0.4);
        }
        
        .data-box {
            background: rgba(0, 0, 0, 0.3);
            padding: 15px;
            border-radius: 10px;
            margin: 15px 0;
            text-align: left;
            font-family: 'Courier New', monospace;
            font-size: 14px;
            max-height: 200px;
            overflow-y: auto;
            color: #ccc;
        }
        
        .icon {
            font-size: 24px;
            margin-right: 10px;
            vertical-align: middle;
        }
        
        .notification-preview {
            background: linear-gradient(to right, #1a1a1a, #2a2a2a);
            border-radius: 15px;
            padding: 15px;
            margin: 20px 0;
            text-align: right;
            border: 1px solid #333;
        }
        
        .notification-title {
            color: #fff;
            font-weight: bold;
            font-size: 18px;
            margin-bottom: 10px;
        }
        
        .notification-body {
            color: #ccc;
            margin-bottom: 15px;
        }
        
        .notification-image {
            width: 100%;
            border-radius: 10px;
            margin: 10px 0;
        }
        
        @media (max-width: 600px) {
            .container {
                padding: 20px;
                margin: 10px;
            }
            
            h1 {
                font-size: 24px;
            }
            
            button {
                padding: 15px 25px;
                font-size: 16px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎬 تجربة إشعارات المسلسلات</h1>
        
        <div class="notification-preview">
            <div class="notification-title">حاملة نظيفة في الشركة</div>
            <div class="notification-body">وجدت تنمراً بين الموظفين، وقررت أن تنتكر كعاملة نظيفة لكشف الحقيقة.</div>
            <img src="https://i.ytimg.com/vi/drnwJuK_-lY/mqdefault.jpg" class="notification-image" alt="معاينة الإشعار">
            <div style="color: #888; font-size: 14px;">معاينة شكل الإشعار كما سيظهر في التطبيق</div>
        </div>
        
        <?php if ($success): ?>
        <div class="status-box success">
            <h2>✅ تم إرسال الإشعار بنجاح!</h2>
            <p><span class="icon">📋</span><strong>العنوان:</strong> حاملة نظيفة في الشركة</p>
            <p><span class="icon">📝</span><strong>النص:</strong> وجدت تنمراً بين الموظفين، وقررت أن تنتكر كعاملة نظيفة لكشف الحقيقة.</p>
            <p><span class="icon">🔢</span><strong>عدد المرات:</strong> <?php echo $_SESSION['send_count']; ?></p>
            
            <div class="data-box">
                <strong>📦 البيانات المرسلة:</strong><br>
                <?php 
                echo json_encode($notificationData, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
                ?>
            </div>
        </div>
        <?php else: ?>
        <div class="status-box error">
            <h2>❌ فشل إرسال الإشعار</h2>
            <p><?php echo htmlspecialchars($error); ?></p>
        </div>
        <?php endif; ?>

        <div class="status-box info">
            <p>💡 كل ما تضغط تحديث الصفحة يرسل إشعار جديد للتطبيق</p>
            <p>📱 الإشعار يصل لكل الأجهزة المشتركة في Topic "all"</p>
        </div>

        <div class="button-group">
            <button onclick="location.reload()">
                🔄 تحديث الصفحة وإرسال إشعار جديد
            </button>
        </div>
        
        <div class="status-box info">
            <p>📱 تأكد من أن التطبيق مفتوح أو في الخلفية</p>
            <p>🔔 يجب أن تكون الإشعارات مفعلة في التطبيق</p>
            <p>🌐 Topic: <strong>all</strong></p>
            <p>📊 الإشعارات المرسلة: <strong><?php echo $_SESSION['send_count']; ?></strong></p>
        </div>
    </div>

    <script>
        // إضافة تأثيرات عند التحميل
        document.addEventListener('DOMContentLoaded', function() {
            const container = document.querySelector('.container');
            container.style.opacity = '0';
            container.style.transform = 'translateY(20px)';
            
            setTimeout(() => {
                container.style.transition = 'all 0.5s ease';
                container.style.opacity = '1';
                container.style.transform = 'translateY(0)';
            }, 100);
        });
    </script>
</body>
</html>