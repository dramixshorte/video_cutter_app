<?php



ini_set('zlib.output_compression', 'On');
ini_set('zlib.output_compression_level', '6');



// تحسين الأداء ومنع انقطاع الاتصال
ignore_user_abort(true);
set_time_limit(0);
ob_start();
session_write_close();
gc_enable();



// تمكين تسجيل الأخطاء
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/api_errors.log');

header('Access-Control-Allow-Origin: *');
header('Content-Type: application/json');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');








require __DIR__ . '/vendor/autoload.php';
use Kreait\Firebase\Factory;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification;

// إعدادات Firebase
$factory = (new Factory)->withServiceAccount(__DIR__ . '/firebase-service-account.json');
$messaging = $factory->createMessaging();



// معلومات اتصال قاعدة البيانات
$servername = "localhost";
$username = "dramaxboxbbs_series";
$password = "dramaxboxbbs_series";
$dbname = "dramaxboxbbs_series";

$conn = new mysqli($servername, $username, $password, $dbname);
if ($conn->connect_error) {
    logError("Connection failed: " . $conn->connect_error);
    die(json_encode(['status' => 'error', 'message' => 'Database connection failed']));
}
$conn->set_charset("utf8mb4");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit();
}

$action = $_GET['action'] ?? '';

try {
    switch ($action) {
        case 'upload_image':
            handleImageUpload($conn);
            break;
        case 'check_series':
            checkSeries($conn);
            break;
            case 'test_notification':
    testNotification($conn);
    break;
        case 'create_series':
            createSeries($conn);
            break;
       case 'upload_episode':
            uploadEpisode($conn);
        case 'get_series':
            getSeries($conn);
            break;
             // الدوال الجديدة لإدارة المسلسلات
        case 'get_all_series':
            getAllSeries($conn);
            break;
        case 'delete_series':
            deleteSeriesWithEpisodes($conn);
            break;
        case 'get_episodes':
            getSeriesEpisodes($conn);
            break;
        case 'delete_episode':
            deleteEpisode($conn);
            break;
        case 'update_episode':
            updateEpisode($conn);
            break;
            
      case 'manage_admob':
        manageAdmobSettings($conn);
        break;
    case 'manage_coin_packages':
        manageCoinPackages($conn);
        break;
    case 'manage_daily_gifts':
        manageDailyGifts($conn);
        break;
    case 'manage_users':
        manageUsers($conn);
        break;
    case 'manage_vip_packages':
        manageVipPackages($conn);
        break;
    case 'manage_app_settings':
        manageAppSettings($conn);
        break;
    case 'get_app_config':
        getAppConfig($conn);
        break;
    case 'update_app_config':
        updateAppConfig($conn);
        break;
    case 'get_admob_config':
        getAdmobConfig($conn);
        break;
    case 'update_admob_config':
        updateAdmobConfig($conn);
        break;
    case 'get_dashboard_stats':
        getDashboardStats($conn);
        break;
            
            
            
        default:
            echo json_encode(['status' => 'error', 'message' => 'Invalid action']);
            break;
    }
} catch (Exception $e) {
    logError("API Error: " . $e->getMessage());
    echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
}

$conn->close();

// ====================== LOG FUNCTIONS ======================
function logError($message) {
    error_log("[" . date('Y-m-d H:i:s') . "] ERROR: $message\n", 3, __DIR__ . '/api_errors.log');
}
function logActivity($message) {
    error_log("[" . date('Y-m-d H:i:s') . "] ACTIVITY: $message\n", 3, __DIR__ . '/api_activity.log');
}

// ====================== MAIN FUNCTIONS ======================




function getAllSeries($conn) {
    $query = "
        SELECT 
            s.id, 
            s.name, 
            s.image_path,
            COUNT(e.id) as episodes_count,
            s.created_at
        FROM 
            series s
        LEFT JOIN 
            episodes e ON s.id = e.series_id
        GROUP BY 
            s.id
        ORDER BY 
            s.created_at DESC
    ";
    
    $result = $conn->query($query);
    
    if (!$result) {
        logError("Query failed: " . $conn->error);
        echo json_encode(['status' => 'error', 'message' => 'Database error']);
        return;
    }
    
    $series = [];
    while ($row = $result->fetch_assoc()) {
        $series[] = [
            'id' => (int)$row['id'],
            'name' => $row['name'],
            'image_path' => $row['image_path'],
            'episodes_count' => (int)$row['episodes_count'],
            'created_at' => $row['created_at']
        ];
    }
    
    echo json_encode([
        'status' => 'success',
        'data' => $series,
        'count' => count($series)
    ]);
}

/**
 * جلب حلقات مسلسل معين (بدون get_result)
 */
function getSeriesEpisodes($conn) {
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!isset($input['series_id'])) {
        echo json_encode(['status' => 'error', 'message' => 'Series ID is required']);
        return;
    }

    $series_id = (int)$input['series_id'];
    $episodes = [];
    
    $stmt = $conn->prepare("
        SELECT 
            id, 
            series_id,
            title, 
            episode_number,
            video_path,
            created_at
        FROM 
            episodes
        WHERE 
            series_id = ?
        ORDER BY 
            episode_number ASC
    ");
    
    if (!$stmt) {
        logError("Prepare failed: " . $conn->error);
        echo json_encode(['status' => 'error', 'message' => 'Database error']);
        return;
    }
    
    $stmt->bind_param("i", $series_id);
    $stmt->execute();
    
    // بديل عن get_result()
    $stmt->bind_result($id, $series_id, $title, $episode_number, $video_path, $created_at);
    
    while ($stmt->fetch()) {
        $episodes[] = [
            'id' => $id,
            'series_id' => $series_id,
            'title' => $title,
            'episode_number' => $episode_number,
            'video_path' => $video_path,
            'created_at' => $created_at
        ];
    }
    
    $stmt->close();
    
    echo json_encode([
        'status' => 'success',
        'data' => $episodes,
        'count' => count($episodes)
    ]);
}

/**
 * حذف مسلسل مع جميع حلقاته وملفاته
 */
function deleteSeriesWithEpisodes($conn) {
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!isset($input['series_id']) || !isset($input['image_path'])) {
        echo json_encode(['status' => 'error', 'message' => 'Series ID and image path are required']);
        return;
    }

    $series_id = (int)$input['series_id'];
    $image_path = basename($input['image_path']);

    $conn->autocommit(false);
    
    try {
        // 1. حذف ملفات الحلقات أولاً
        $episodes_dir = __DIR__ . '/series_episodes/';
        $episodes_stmt = $conn->prepare("SELECT video_path FROM episodes WHERE series_id = ?");
        $episodes_stmt->bind_param("i", $series_id);
        $episodes_stmt->execute();
        $episodes_stmt->bind_result($video_path);
        
        while ($episodes_stmt->fetch()) {
            $video_file = $episodes_dir . basename($video_path);
            if (file_exists($video_file)) {
                unlink($video_file);
            }
        }
        $episodes_stmt->close();
        
        // 2. حذف الحلقات من قاعدة البيانات
        $delete_episodes = $conn->prepare("DELETE FROM episodes WHERE series_id = ?");
        $delete_episodes->bind_param("i", $series_id);
        $delete_episodes->execute();
        
        // 3. حذف المسلسل من قاعدة البيانات
        $delete_series = $conn->prepare("DELETE FROM series WHERE id = ?");
        $delete_series->bind_param("i", $series_id);
        $delete_series->execute();
        
        // 4. حذف صورة المسلسل
        $image_file = __DIR__ . '/series_images/' . $image_path;
        if (file_exists($image_file)) {
            unlink($image_file);
        }
        
        $conn->commit();
        logActivity("Deleted series ID: $series_id");
        echo json_encode(['status' => 'success', 'message' => 'Series deleted successfully']);
        
    } catch (Exception $e) {
        $conn->rollback();
        logError("deleteSeriesWithEpisodes: " . $e->getMessage());
        echo json_encode(['status' => 'error', 'message' => 'Failed to delete series']);
    } finally {
        $conn->autocommit(true);
        if (isset($delete_episodes)) $delete_episodes->close();
        if (isset($delete_series)) $delete_series->close();
    }
}

/**
 * حذف حلقة معينة
 */
function deleteEpisode($conn) {
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!isset($input['episode_id']) || !isset($input['video_path'])) {
        echo json_encode(['status' => 'error', 'message' => 'Episode ID and video path are required']);
        return;
    }

    $episode_id = (int)$input['episode_id'];
    $video_path = basename($input['video_path']);
    
    $conn->autocommit(false);
    
    try {
        // 1. حذف الحلقة من قاعدة البيانات
        $stmt = $conn->prepare("DELETE FROM episodes WHERE id = ?");
        $stmt->bind_param("i", $episode_id);
        $stmt->execute();
        
        // 2. حذف ملف الفيديو
        $video_file = __DIR__ . '/series_episodes/' . $video_path;
        if (file_exists($video_file)) {
            unlink($video_file);
        }
        
        $conn->commit();
        logActivity("Deleted episode ID: $episode_id");
        echo json_encode(['status' => 'success', 'message' => 'Episode deleted successfully']);
        
    } catch (Exception $e) {
        $conn->rollback();
        logError("deleteEpisode: " . $e->getMessage());
        echo json_encode(['status' => 'error', 'message' => 'Failed to delete episode']);
    } finally {
        $conn->autocommit(true);
        if (isset($stmt)) $stmt->close();
    }
}

/**
 * تحديث معلومات الحلقة
 */
function updateEpisode($conn) {
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!isset($input['episode_id']) || !isset($input['title'])) {
        echo json_encode(['status' => 'error', 'message' => 'Episode ID and title are required']);
        return;
    }

    $episode_id = (int)$input['episode_id'];
    $title = $conn->real_escape_string($input['title']);
    
    try {
        $stmt = $conn->prepare("UPDATE episodes SET title = ? WHERE id = ?");
        $stmt->bind_param("si", $title, $episode_id);
        $stmt->execute();
        
        if ($stmt->affected_rows > 0) {
            logActivity("Updated episode ID: $episode_id");
            echo json_encode(['status' => 'success', 'message' => 'Episode updated successfully']);
        } else {
            echo json_encode(['status' => 'info', 'message' => 'No changes were made']);
        }
        
    } catch (Exception $e) {
        logError("updateEpisode: " . $e->getMessage());
        echo json_encode(['status' => 'error', 'message' => 'Failed to update episode']);
    } finally {
        if (isset($stmt)) $stmt->close();
    }
}




















function handleImageUpload($conn) {
    // سجل محاولة الرفع
    logActivity("Starting image upload process");

    if (!isset($_FILES['image'])) {
        throw new Exception('No image file uploaded');
    }

    $target_dir = "series_images/";
    
    // سجل حالة المجلد
    if (!file_exists($target_dir)) {
        logActivity("Image directory doesn't exist, attempting to create");
        if (!mkdir($target_dir, 0755, true)) {
            throw new Exception('Failed to create image directory');
        }
        logActivity("Image directory created successfully");
    } else {
        logActivity("Image directory exists");
    }

    // سجل صلاحيات المجلد
    if (!is_writable($target_dir)) {
        logActivity("Image directory is not writable");
        throw new Exception('Image directory is not writable');
    }

    $image = $_FILES['image'];
    $image_name = basename($image['name']);
    $image_type = strtolower(pathinfo($image_name, PATHINFO_EXTENSION));
    
    // سجل معلومات الملف
    logActivity("Uploading file: $image_name, Size: {$image['size']}, Type: $image_type");

    // التحقق من نوع الملف
    $allowed_types = ['jpg', 'jpeg', 'png', 'gif'];
    if (!in_array($image_type, $allowed_types)) {
        throw new Exception('Only JPG, JPEG, PNG & GIF files are allowed');
    }

    // التحقق من حجم الملف (5MB كحد أقصى)
    if ($image['size'] > 5 * 1024 * 1024) {
        throw new Exception('Image exceeds maximum size of 5MB');
    }

    // إنشاء اسم فريد للملف
    $new_filename = 'img_' . uniqid() . '.' . $image_type;
    $target_path = $target_dir . $new_filename;

    // سجل محاولة نقل الملف
    logActivity("Attempting to move file to: $target_path");

    if (move_uploaded_file($image['tmp_name'], $target_path)) {
        logActivity("Image uploaded successfully: $new_filename");
        
        // إرجاع المسار الكامل للصورة
        $full_image_path =   $new_filename;
        
        echo json_encode([
            'status' => 'success', 
            'image_path' => $full_image_path,
            'image_name' => $new_filename
        ]);
    } else {
        $error = error_get_last();
        logActivity("Failed to move uploaded file: " . ($error['message'] ?? 'Unknown error'));
        throw new Exception('Failed to upload image. Error: ' . ($error['message'] ?? 'Unknown error'));
    }
}



function uploadEpisode($conn) {
    if (!isset($_POST['series_id']) || !isset($_POST['episode_number'])) {
        throw new Exception('Missing required fields');
    }
  // بداية تسجيل تفاصيل الرفع
    logActivity("====== بدء رفع حلقة جديدة ======");
    
  
    
    if (!isset($_POST['episode_number'])) {
        logActivity("ERROR: episode_number not provided");
        throw new Exception('Missing episode_number');
    }

    $series_id = intval($_POST['series_id']);
    $episode_number = intval($_POST['episode_number']);
    $title = $conn->real_escape_string($_POST['title'] ?? '');
    
    logActivity("المعطيات المستلمة:");
    logActivity("series_id: $series_id");
    logActivity("episode_number: $episode_number");
    logActivity("title: $title");

    if (!isset($_FILES['video'])) {
        logActivity("ERROR: No video file uploaded");
        throw new Exception('No video uploaded');
    }
    
    $video = $_FILES['video'];
    logActivity("معلومات ملف الفيديو:");
    logActivity(print_r($video, true));
    // بدء المعاملة
    $conn->autocommit(false);
    $success = false;
    $target_path = '';
    $series_id = intval($_POST['series_id']);
    
    try {
        $episode_number = intval($_POST['episode_number']);
        $title = $conn->real_escape_string($_POST['title'] ?? '');

        if (!isset($_FILES['video'])) throw new Exception('No video uploaded');
        $video = $_FILES['video'];
        
        // التحقق من صحة الفيديو
        $video_type = strtolower(pathinfo($video['name'], PATHINFO_EXTENSION));
        $allowed = ['mp4', 'avi', 'mov', 'mkv', 'webm'];
        if (!in_array($video_type, $allowed)) throw new Exception('Invalid video type');
        if ($video['size'] > 500 * 1024 * 1024) throw new Exception('Video exceeds 500MB');

        $target_dir = "series_episodes/";
        if (!file_exists($target_dir)) {
            if (!mkdir($target_dir, 0755, true)) {
                throw new Exception('Failed to create episodes directory');
            }
        }

        // التأكد من وجود المسلسل
        $stmt = $conn->prepare("SELECT name, image_path FROM series WHERE id = ?");
        $stmt->bind_param("i", $series_id);
        $stmt->execute();
        $stmt->bind_result($series_name, $series_image);
        if (!$stmt->fetch()) throw new Exception('Series not found');
        $stmt->close();

        // التحقق من وجود الحلقة وحذفها إذا كانت موجودة
        $chk = $conn->prepare("SELECT id, video_path FROM episodes WHERE series_id = ? AND episode_number = ?");
        $chk->bind_param("ii", $series_id, $episode_number);
        $chk->execute();
        $chk->store_result();
        
        $old_video_path = '';
        if ($chk->num_rows > 0) {
            $chk->bind_result($old_id, $old_path);
            $chk->fetch();
            $old_video_path = $old_path;
            
            // حذف الحلقة القديمة من قاعدة البيانات
            $delete = $conn->prepare("DELETE FROM episodes WHERE id = ?");
            $delete->bind_param("i", $old_id);
            $delete->execute();
            $delete->close();
        }
        $chk->close();

        // رفع الفيديو الجديد
        $filename = "ep_{$series_id}_{$episode_number}_" . time() . '.' . $video_type;
        $target_path = $target_dir . $filename;

        if (move_uploaded_file($video['tmp_name'], $target_path)) {
            // حذف الفيديو القديم إذا كان موجودًا
            if (!empty($old_video_path) && file_exists($target_dir . $old_video_path)) {
                @unlink($target_dir . $old_video_path);
            }
            
            // إدراج الحلقة الجديدة
            $insert = $conn->prepare("INSERT INTO episodes (series_id, title, episode_number, video_path) VALUES (?, ?, ?, ?)");
            $insert->bind_param("isis", $series_id, $title, $episode_number, $filename);

            if ($insert->execute()) {
                // إرسال إشعار
               // $notificationTitle = "🎥 حلقة جديدة: {$series_name}";
              //  $notificationBody = "الحلقة $episode_number: $title";

              //  global $messaging;
               // if ($messaging !== null) {
                  ///  $message = CloudMessage::withTarget('topic', 'all')
                      //  ->withNotification(Notification::create($notificationTitle, $notificationBody))
                       // ->withData([
                         //   'type' => 'new_episode',
                         //   'series_id' => $series_id,
                            //'episode_number' => $episode_number,
                           // 'series_image' => $series_image
                       // ]);
                    
                  //  try {
                       /// $messaging->send($message);
                       // logActivity("Notification sent for new episode: {$series_name} - Ep $episode_number");
                  ///  } catch (Exception $e) {
                       /// logError("Failed to send notification: " . $e->getMessage());
                  ///  }
               // }

                $conn->commit();
                $success = true;
                echo json_encode([
                    'status' => 'success',
                    'message' => 'Episode uploaded successfully',
                    'file_name' => $filename
                ]);
            } else {
                throw new Exception('Database insert failed');
            }
        } else {
            throw new Exception('Failed to move uploaded file');
        }
    } catch (Exception $e) {
        $conn->rollback();
        
        // حذف الملف الذي تم رفعه في حالة الفشل
        if (!empty($target_path) && file_exists($target_path)) {
            @unlink($target_path);
        }
        
        logError("Error in uploadEpisode: " . $e->getMessage());
        throw $e;
    } finally {
        $conn->autocommit(true);
    }
}










// دالة مساعدة لتنسيق حجم الملف
function formatBytes($size, $precision = 2) {
    $base = log($size, 1024);
    $suffixes = array('B', 'KB', 'MB', 'GB', 'TB');
    return round(pow(1024, $base - floor($base)), $precision) . ' ' . $suffixes[floor($base)];
}


function testNotification($conn) {
    global $messaging;
    
    try {
        $testData = [
            'type' => 'test',
            'series_id' => '999',
            'series_title' => 'اختبار الإشعار',
            'series_description' => 'هذا إشعار اختبار من API',
            'image_url' => 'https://i.ytimg.com/vi/drnwJuK_-lY/mqdefault.jpg',
            'send_count' => '1',
            'timestamp' => date('Y-m-d H:i:s')
        ];
        
        $notification = \Kreait\Firebase\Messaging\Notification::create(
            'اختبار الإشعار',
            'هذا إشعار اختبار من API'
        );
        
        $message = \Kreait\Firebase\Messaging\CloudMessage::withTarget('topic', 'all')
            ->withNotification($notification)
            ->withData($testData);
        
        $result = $messaging->send($message);
        
        echo json_encode([
            'status' => 'success',
            'message' => 'تم إرسال إشعار الاختبار بنجاح',
            'result' => $result
        ]);
        
    } catch (Exception $e) {
        logError("Test notification failed: " . $e->getMessage());
        echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
    }
}

// دالة موثوقة لإرسال الإشعارات مع إعادة المحاولة
function sendReliableNotification($messaging, $title, $body, $data, $imageUrl = null) {
    $maxRetries = 3;
    $retryDelay = 1; // ثانية واحدة بين المحاولات
    
    for ($attempt = 1; $attempt <= $maxRetries; $attempt++) {
        try {
            $notification = \Kreait\Firebase\Messaging\Notification::create($title, $body);
            
            $androidConfig = [
                'priority' => 'high',
                'notification' => [
                    'channel_id' => 'professional_series_channel',
                    'color' => '#FF0000',
                    'sound' => 'notification_sound',
                    'visibility' => 'public',
                    'icon' => 'ic_notification',
                    'tag' => 'series_' . ($data['series_id'] ?? 'default'),
                    'click_action' => 'FLUTTER_NOTIFICATION_CLICK'
                ]
            ];
            
            if ($imageUrl) {
                $androidConfig['notification']['image'] = $imageUrl;
            }
            
            $apnsConfig = [
                'payload' => [
                    'aps' => [
                        'alert' => [
                            'title' => $title,
                            'body' => $body
                        ],
                        'sound' => 'default',
                        'mutable-content' => 1,
                        'badge' => 1,
                        'category' => 'series_notifications'
                    ]
                ]
            ];
            
            if ($imageUrl) {
                $apnsConfig['payload']['fcm_options']['image'] = $imageUrl;
            }
            
            $message = \Kreait\Firebase\Messaging\CloudMessage::withTarget('topic', 'all')
                ->withNotification($notification)
                ->withData($data)
                ->withAndroidConfig($androidConfig)
                ->withApnsConfig($apnsConfig);
            
            $result = $messaging->send($message);
            
            logActivity("تم إرسال الإشعار بنجاح: $title (محاولة $attempt)");
            return ['success' => true, 'result' => $result, 'attempts' => $attempt];
            
        } catch (Exception $e) {
            logError("فشل إرسال الإشعار (محاولة $attempt): " . $e->getMessage());
            
            if ($attempt === $maxRetries) {
                return ['success' => false, 'error' => $e->getMessage(), 'attempts' => $attempt];
            }
            
            // انتظر قبل المحاولة التالية
            sleep($retryDelay);
            $retryDelay *= 2; // زيادة فترة الانتظار مع كل محاولة
        }
    }
    
    return ['success' => false, 'error' => 'فشل بعد جميع المحاولات', 'attempts' => $maxRetries];
}






function createSeries($conn) {
    $data = json_decode(file_get_contents('php://input'), true);
    global $messaging;
    
    $name = $conn->real_escape_string($data['name'] ?? '');
    $original_image_path = $data['image_path'] ?? '';
    $replace_existing = isset($data['replace_existing']) ? (bool)$data['replace_existing'] : false;
    
    if (empty($name)) throw new Exception('Series name is required');
    if (empty($original_image_path)) throw new Exception('Image path is required');

    // إنشاء وصف ثابت للإشعار
    $series_description = "شاهد أفضل المسلسلات متاحة الآن: " . $name;
    
    // بدء المعاملة لضمان السلامة
    $conn->autocommit(false);
    $success = false;
    $old_series_id = null;
    $old_image_path = '';
    $old_episodes = [];

    try {
        // التحقق من وجود مسلسل بنفس الاسم
        $check_sql = "SELECT id, image_path FROM series WHERE name = ? LIMIT 1";
        $stmt = $conn->prepare($check_sql);
        $stmt->bind_param("s", $name);
        $stmt->execute();
        $stmt->store_result();
        
        if ($stmt->num_rows > 0) {
            if (!$replace_existing) {
                throw new Exception('Series already exists');
            }
            
            $stmt->bind_result($old_series_id, $old_image_path);
            $stmt->fetch();
            
            // الحصول على معلومات الحلقات القديمة
            $episodes_sql = "SELECT id, video_path FROM episodes WHERE series_id = ?";
            $episodes_stmt = $conn->prepare($episodes_sql);
            $episodes_stmt->bind_param("i", $old_series_id);
            $episodes_stmt->execute();
            $result = $episodes_stmt->get_result();
            $old_episodes = $result->fetch_all(MYSQLI_ASSOC);
            $episodes_stmt->close();
            
            // حذف المسلسل القديم وحلقاته
            $delete_episodes = $conn->prepare("DELETE FROM episodes WHERE series_id = ?");
            $delete_episodes->bind_param("i", $old_series_id);
            $delete_episodes->execute();
            $delete_episodes->close();
            
            $delete_series = $conn->prepare("DELETE FROM series WHERE id = ?");
            $delete_series->bind_param("i", $old_series_id);
            $delete_series->execute();
            $delete_series->close();
        }
        
        // الخطوة 1: إدراج المسلسل بصورة مؤقتة للحصول على الـ ID
        $temp_image_path = $conn->real_escape_string($original_image_path);
        $insert_sql = "INSERT INTO series (name, image_path, isFeatured) VALUES (?, ?, 0)";
        $insert_stmt = $conn->prepare($insert_sql);
        $insert_stmt->bind_param("ss", $name, $temp_image_path);
        
        if ($insert_stmt->execute()) {
            $series_id = $insert_stmt->insert_id;
            
            // الخطوة 2: إنشاء اسم جديد للصورة
            $random_number = rand(1000, 9999);
            $prefix = substr(preg_replace('/[^a-zA-Z]/', '', $name), 0, 2);
            $prefix = strtolower($prefix ?: 'sr');
            
            $file_extension = pathinfo($original_image_path, PATHINFO_EXTENSION);
            $new_image_name = $prefix . $series_id . $random_number . '.' . $file_extension;
            $new_image_path = $conn->real_escape_string($new_image_name);
            
            // الخطوة 3: نقل/إعادة تسمية ملف الصورة
            $upload_dir = "series_images/";
            $original_file = $upload_dir . basename($original_image_path);
            $new_file = $upload_dir . $new_image_name;
            
            if (!file_exists($original_file)) {
                throw new Exception('Original image file not found: ' . $original_file);
            }
            
            if (!rename($original_file, $new_file)) {
                throw new Exception('Failed to rename/move image file');
            }
            
            // الخطوة 4: تحديث المسلسل باسم الصورة الجديد
            $update_sql = "UPDATE series SET image_path = ? WHERE id = ?";
            $update_stmt = $conn->prepare($update_sql);
            $update_stmt->bind_param("si", $new_image_path, $series_id);
            $update_stmt->execute();
            $update_stmt->close();
            
            $success = true;
            
            // ========== إرسال الإشعار كما في صفحة HTML ==========
            $base_url = "https://dramaxbox.bbs.tr/App";
            $full_image_url = $base_url . "/series_images/" . $new_image_name;
            
            try {
                // بيانات الإشعار مع النظام الموثوق
                $notificationData = [
                    'type' => 'new_series',
                    'series_id' => (string)$series_id,
                    'series_title' => $name,
                    'series_description' => $series_description,
                    'image_url' => $full_image_url,
                    'timestamp' => date('Y-m-d H:i:s'),
                    'click_action' => 'FLUTTER_NOTIFICATION_CLICK'
                ];
                
                // استخدام النظام الموثوق لإرسال الإشعار مع إعادة المحاولة
                $notificationResult = sendReliableNotification(
                    $messaging, 
                    '🎬 ' . $name, 
                    $series_description, 
                    $notificationData, 
                    $full_image_url
                );
                
                if ($notificationResult['success']) {
                    logActivity("تم إرسال إشعار مسلسل جديد بنجاح: " . $name . " (محاولات: " . $notificationResult['attempts'] . ")");
                    $notification_sent = true;
                } else {
                    logError("فشل إرسال إشعار مسلسل جديد: " . $notificationResult['error'] . " (محاولات: " . $notificationResult['attempts'] . ")");
                    $notification_sent = false;
                }
                
            } catch (Exception $e) {
                logError("خطأ في نظام الإشعارات: " . $e->getMessage());
                $notification_sent = false;
                // لا نوقف العملية إذا فشل الإشعار، نستمر لأن المسلسل تم إنشاؤه بنجاح
            }
            // ========== نهاية جزء الإشعارات ==========
            
            // حذف الملفات القديمة إذا تم الاستبدال
            if ($replace_existing && $old_series_id) {
                // حذف الصورة القديمة
                if (!empty($old_image_path) && file_exists($upload_dir . $old_image_path)) {
                    @unlink($upload_dir . $old_image_path);
                }
                
                // حذف الحلقات القديمة
                foreach ($old_episodes as $episode) {
                    if (!empty($episode['video_path']) && file_exists("series_episodes/" . $episode['video_path'])) {
                        @unlink("series_episodes/" . $episode['video_path']);
                    }
                }
            }
            
            $conn->commit();
            echo json_encode([
                'status' => 'success', 
                'series_id' => $series_id,
                'name' => $name,
                'image_path' => $new_image_path,
                'replaced_old' => $replace_existing,
                'notification_sent' => isset($notification_sent) ? $notification_sent : false,
                'notification_message' => $series_description,
                'notification_attempts' => isset($notificationResult) ? $notificationResult['attempts'] : 0
            ]);
        } else {
            throw new Exception('Error creating series: ' . $conn->error);
        }
    } catch (Exception $e) {
        $conn->rollback();
        
        // في حالة الخطأ، حاول استعادة الملف الأصلي إذا كان قد تم نقله
        if (isset($new_file) && isset($original_file) && !file_exists($original_file) && file_exists($new_file)) {
            rename($new_file, $original_file);
        }
        
        logError("Error in createSeries: " . $e->getMessage());
        throw $e;
    } finally {
        $conn->autocommit(true);
        if (isset($stmt)) $stmt->close();
        if (isset($insert_stmt)) $insert_stmt->close();
    }
}







function checkSeries($conn) {
    $data = json_decode(file_get_contents('php://input'), true);
    $name = $conn->real_escape_string($data['name'] ?? '');
    if (empty($name)) throw new Exception('Series name is required');

    $sql = "SELECT id, name, image_path FROM series WHERE name = ? LIMIT 1";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("s", $name);
    $stmt->execute();
    $stmt->store_result();

    if ($stmt->num_rows > 0) {
        $stmt->bind_result($id, $sname, $image_path);
        $stmt->fetch();
        
        // الحصول على عدد الحلقات
        $episodes_count = 0;
        $episodes_sql = "SELECT COUNT(*) FROM episodes WHERE series_id = ?";
        $episodes_stmt = $conn->prepare($episodes_sql);
        $episodes_stmt->bind_param("i", $id);
        $episodes_stmt->execute();
        $episodes_stmt->bind_result($episodes_count);
        $episodes_stmt->fetch();
        $episodes_stmt->close();
        
        echo json_encode([
            'status' => 'exists', 
            'series' => [
                'id' => $id, 
                'name' => $sname, 
                'image_path' => $image_path,
                'episodes_count' => $episodes_count
            ]
        ]);
    } else {
        echo json_encode(['status' => 'not_found', 'message' => 'Series not found']);
    }
}

 



function getSeries($conn) {
    $result = $conn->query("SELECT id, name, image_path FROM series ORDER BY id DESC");
    $data = [];
    while ($row = $result->fetch_assoc()) $data[] = $row;
    echo json_encode(['status' => 'success', 'series' => $data]);
}





// ====================== DASHBOARD MANAGEMENT FUNCTIONS ======================

// إعدادات AdMob
function manageAdmobSettings($conn) {
    $input = json_decode(file_get_contents('php://input'), true);
    $action = $input['action'] ?? '';
    $app = $input['app'] ?? 'main';
    
    if ($action === 'get') {
        // قائمة الحقول المدعومة - نفس الأسماء الموجودة في قاعدة البيانات
        $supportedFields = [
            'app_id', 'banner', 'interstitial',
            'rewarded1', 'rewarded2', 'rewarded3', 
            'rewarded4', 'rewarded5', 'rewarded6'
        ];
        
        // إذا تم تمرير قائمة بالحقول المطلوبة، استخدمها
        $requestedFields = $input['fields'] ?? $supportedFields;
        $fields = array_intersect($requestedFields, $supportedFields);
        
        // تحديد اسم الجدول الصحيح بناءً على التطبيق
        $tableName = 'admob_settings'; // التطبيق الأساسي
        if ($app === 'mohamed') {
            $tableName = 'Muhammed8080admob_settings';
        } elseif ($app === 'rivo') {
            $tableName = 'Revo_Shorts_admob';
        }
        
        $result = $conn->query("SELECT * FROM $tableName LIMIT 1");
        $allSettings = $result->fetch_assoc() ?: [];
        
        // فلترة النتائج للحصول على الحقول المطلوبة فقط
        $filteredSettings = [];
        foreach ($fields as $field) {
            $filteredSettings[$field] = $allSettings[$field] ?? '';
        }
        
        echo json_encode(['status' => 'success', 'data' => $filteredSettings]);
        return;
    }
    
    if ($action === 'update') {
        // تحديد اسم الجدول الصحيح بناءً على التطبيق
        $tableName = 'admob_settings'; // التطبيق الأساسي
        if ($app === 'mohamed') {
            $tableName = 'Muhammed8080admob_settings';
        } elseif ($app === 'rivo') {
            $tableName = 'Revo_Shorts_admob';
        }
        
        // نفس أسماء الحقول الموجودة في قاعدة البيانات
        $supportedFields = [
            'app_id', 'banner', 'interstitial',
            'rewarded1', 'rewarded2', 'rewarded3', 
            'rewarded4', 'rewarded5', 'rewarded6'
        ];
        
        $updateFields = [];
        $params = [];
        $types = '';
        
        foreach ($supportedFields as $field) {
            if (isset($input[$field])) {
                $updateFields[] = "$field = ?";
                $params[] = $input[$field];
                $types .= 's';
            }
        }
        
        if (!empty($updateFields)) {
            $sql = "UPDATE $tableName SET " . implode(', ', $updateFields) . " WHERE id = 1";
            $stmt = $conn->prepare($sql);
            if ($types && $params) {
                $stmt->bind_param($types, ...$params);
            }
            
            if ($stmt->execute()) {
                echo json_encode(['status' => 'success', 'message' => "تم تحديث إعدادات AdMob لتطبيق $app"]);
            } else {
                echo json_encode(['status' => 'error', 'message' => 'فشل التحديث']);
            }
            $stmt->close();
        } else {
            echo json_encode(['status' => 'error', 'message' => 'لا توجد حقول للتحديث']);
        }
        return;
    }
}

// إدارة حزم العملات
function manageCoinPackages($conn) {
    $input = json_decode(file_get_contents('php://input'), true);
    $action = $input['action'] ?? '';
    
    if ($action === 'get_all') {
        $result = $conn->query("SELECT * FROM coin_packages ORDER BY coin_amount ASC");
        $packages = [];
        while ($row = $result->fetch_assoc()) {
            $packages[] = $row;
        }
        echo json_encode(['status' => 'success', 'data' => $packages]);
        return;
    }
    
    if ($action === 'create') {
        $required = ['coin_amount', 'price', 'required_ads', 'google_play_product_id'];
        foreach ($required as $field) {
            if (!isset($input[$field])) {
                echo json_encode(['status' => 'error', 'message' => "حقل $field مطلوب"]);
                return;
            }
        }
        
        $stmt = $conn->prepare("INSERT INTO coin_packages (coin_amount, price, required_ads, google_play_product_id, is_popular) VALUES (?, ?, ?, ?, ?)");
        $is_popular = $input['is_popular'] ?? 0;
        $stmt->bind_param("idisi", $input['coin_amount'], $input['price'], $input['required_ads'], $input['google_play_product_id'], $is_popular);
        
        if ($stmt->execute()) {
            echo json_encode(['status' => 'success', 'message' => 'تم إنشاء الحزمة بنجاح', 'id' => $stmt->insert_id]);
        } else {
            echo json_encode(['status' => 'error', 'message' => 'فشل إنشاء الحزمة']);
        }
        $stmt->close();
        return;
    }
    
    if ($action === 'update') {
        if (!isset($input['id'])) {
            echo json_encode(['status' => 'error', 'message' => 'معرف الحزمة مطلوب']);
            return;
        }
        
        $fields = ['coin_amount', 'price', 'required_ads', 'google_play_product_id', 'is_popular'];
        $updateFields = [];
        $params = [];
        $types = '';
        
        foreach ($fields as $field) {
            if (isset($input[$field])) {
                $updateFields[] = "$field = ?";
                $params[] = $input[$field];
                $types .= is_int($input[$field]) ? 'i' : (is_float($input[$field]) ? 'd' : 's');
            }
        }
        
        if (!empty($updateFields)) {
            $params[] = $input['id'];
            $types .= 'i';
            
            $sql = "UPDATE coin_packages SET " . implode(', ', $updateFields) . " WHERE id = ?";
            $stmt = $conn->prepare($sql);
            $stmt->bind_param($types, ...$params);
            
            if ($stmt->execute()) {
                echo json_encode(['status' => 'success', 'message' => 'تم تحديث الحزمة بنجاح']);
            } else {
                echo json_encode(['status' => 'error', 'message' => 'فشل التحديث']);
            }
            $stmt->close();
        }
        return;
    }
    
    if ($action === 'delete') {
        if (!isset($input['id'])) {
            echo json_encode(['status' => 'error', 'message' => 'معرف الحزمة مطلوب']);
            return;
        }
        
        $stmt = $conn->prepare("DELETE FROM coin_packages WHERE id = ?");
        $stmt->bind_param("i", $input['id']);
        
        if ($stmt->execute()) {
            echo json_encode(['status' => 'success', 'message' => 'تم حذف الحزمة بنجاح']);
        } else {
            echo json_encode(['status' => 'error', 'message' => 'فشل الحذف']);
        }
        $stmt->close();
        return;
    }
}

// إدارة الهدايا اليومية
function manageDailyGifts($conn) {
    $input = json_decode(file_get_contents('php://input'), true);
    $action = $input['action'] ?? '';
    
    if ($action === 'get_all') {
        $result = $conn->query("SELECT * FROM Dailygifts ORDER BY id ASC");
        $gifts = [];
        while ($row = $result->fetch_assoc()) {
            $gifts[] = $row;
        }
        echo json_encode(['status' => 'success', 'data' => $gifts]);
        return;
    }
    
    if ($action === 'create') {
        $required = ['coin_amount', 'price', 'required_ads', 'cooldown_hours'];
        foreach ($required as $field) {
            if (!isset($input[$field])) {
                echo json_encode(['status' => 'error', 'message' => "حقل $field مطلوب"]);
                return;
            }
        }
        
        $stmt = $conn->prepare("INSERT INTO Dailygifts (coin_amount, price, required_ads, cooldown_hours, is_popular) VALUES (?, ?, ?, ?, ?)");
        $is_popular = $input['is_popular'] ?? 0;
        $stmt->bind_param("idiii", $input['coin_amount'], $input['price'], $input['required_ads'], $input['cooldown_hours'], $is_popular);
        
        if ($stmt->execute()) {
            echo json_encode(['status' => 'success', 'message' => 'تم إنشاء الهدية بنجاح', 'id' => $stmt->insert_id]);
        } else {
            echo json_encode(['status' => 'error', 'message' => 'فشل إنشاء الهدية']);
        }
        $stmt->close();
        return;
    }
    
    if ($action === 'update') {
        if (!isset($input['id'])) {
            echo json_encode(['status' => 'error', 'message' => 'معرف الهدية مطلوب']);
            return;
        }
        
        $fields = ['coin_amount', 'price', 'required_ads', 'cooldown_hours', 'is_popular'];
        $updateFields = [];
        $params = [];
        $types = '';
        
        foreach ($fields as $field) {
            if (isset($input[$field])) {
                $updateFields[] = "$field = ?";
                $params[] = $input[$field];
                $types .= is_int($input[$field]) ? 'i' : (is_float($input[$field]) ? 'd' : 's');
            }
        }
        
        if (!empty($updateFields)) {
            $params[] = $input['id'];
            $types .= 'i';
            
            $sql = "UPDATE Dailygifts SET " . implode(', ', $updateFields) . " WHERE id = ?";
            $stmt = $conn->prepare($sql);
            $stmt->bind_param($types, ...$params);
            
            if ($stmt->execute()) {
                echo json_encode(['status' => 'success', 'message' => 'تم تحديث الهدية بنجاح']);
            } else {
                echo json_encode(['status' => 'error', 'message' => 'فشل التحديث']);
            }
            $stmt->close();
        }
        return;
    }
    
    if ($action === 'delete') {
        if (!isset($input['id'])) {
            echo json_encode(['status' => 'error', 'message' => 'معرف الهدية مطلوب']);
            return;
        }
        
        $stmt = $conn->prepare("DELETE FROM Dailygifts WHERE id = ?");
        $stmt->bind_param("i", $input['id']);
        
        if ($stmt->execute()) {
            echo json_encode(['status' => 'success', 'message' => 'تم حذف الهدية بنجاح']);
        } else {
            echo json_encode(['status' => 'error', 'message' => 'فشل الحذف']);
        }
        $stmt->close();
        return;
    }
}

// إدارة المستخدمين
function manageUsers($conn) {
    $input = json_decode(file_get_contents('php://input'), true);
    $action = $input['action'] ?? '';
    
    if ($action === 'get_all') {
        $page = $input['page'] ?? 1;
        $limit = $input['limit'] ?? 20;
        $offset = ($page - 1) * $limit;
        
        // جلب المستخدمين مع عدد العملات والمعاملات
        $sql = "SELECT u.*, 
                (SELECT COUNT(*) FROM coin_transactions ct WHERE ct.user_id = u.id) as transactions_count,
                (SELECT COUNT(*) FROM episode_purchases ep WHERE ep.user_id = u.id) as purchases_count
                FROM users u 
                ORDER BY u.created_at DESC 
                LIMIT ? OFFSET ?";
        
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("ii", $limit, $offset);
        $stmt->execute();
        $result = $stmt->get_result();
        
        $users = [];
        while ($row = $result->fetch_assoc()) {
            $users[] = $row;
        }
        
        // جلب العدد الإجمالي
        $totalResult = $conn->query("SELECT COUNT(*) as total FROM users");
        $total = $totalResult->fetch_assoc()['total'];
        
        echo json_encode([
            'status' => 'success', 
            'data' => $users,
            'pagination' => [
                'current_page' => $page,
                'total_pages' => ceil($total / $limit),
                'total_users' => $total
            ]
        ]);
        return;
    }
    
    if ($action === 'update') {
        if (!isset($input['id'])) {
            echo json_encode(['status' => 'error', 'message' => 'معرف المستخدم مطلوب']);
            return;
        }
        
        $allowedFields = ['coins', 'is_vip', 'vip_expiry', 'name', 'email'];
        $updateFields = [];
        $params = [];
        $types = '';
        
        foreach ($allowedFields as $field) {
            if (isset($input[$field])) {
                $updateFields[] = "$field = ?";
                $params[] = $input[$field];
                $types .= is_int($input[$field]) ? 'i' : (is_bool($input[$field]) ? 'i' : 's');
            }
        }
        
        if (!empty($updateFields)) {
            $params[] = $input['id'];
            $types .= 'i';
            
            $sql = "UPDATE users SET " . implode(', ', $updateFields) . " WHERE id = ?";
            $stmt = $conn->prepare($sql);
            $stmt->bind_param($types, ...$params);
            
            if ($stmt->execute()) {
                echo json_encode(['status' => 'success', 'message' => 'تم تحديث المستخدم بنجاح']);
            } else {
                echo json_encode(['status' => 'error', 'message' => 'فشل التحديث']);
            }
            $stmt->close();
        }
        return;
    }
    
    if ($action === 'delete') {
        if (!isset($input['id'])) {
            echo json_encode(['status' => 'error', 'message' => 'معرف المستخدم مطلوب']);
            return;
        }
        
        $conn->autocommit(false);
        try {
            // حذف جميع البيانات المرتبطة بالمستخدم
            $tables = [
                'coin_transactions',
                'episode_purchases',
                'likes',
                'user_ad_watch',
                'user_dailygifts',
                'user_package_progress',
                'user_sessions',
                'user_unlocked_episodes',
                'views'
            ];
            
            foreach ($tables as $table) {
                $conn->query("DELETE FROM $table WHERE user_id = " . $input['id']);
            }
            
            // حذف المستخدم
            $stmt = $conn->prepare("DELETE FROM users WHERE id = ?");
            $stmt->bind_param("i", $input['id']);
            $stmt->execute();
            
            $conn->commit();
            echo json_encode(['status' => 'success', 'message' => 'تم حذف المستخدم بنجاح']);
        } catch (Exception $e) {
            $conn->rollback();
            echo json_encode(['status' => 'error', 'message' => 'فشل الحذف: ' . $e->getMessage()]);
        } finally {
            $conn->autocommit(true);
        }
        return;
    }
}

// إدارة حزم VIP
function manageVipPackages($conn) {
    $input = json_decode(file_get_contents('php://input'), true);
    $action = $input['action'] ?? '';
    
    if ($action === 'get_all') {
        $result = $conn->query("SELECT * FROM vip_packages ORDER BY duration ASC");
        $packages = [];
        while ($row = $result->fetch_assoc()) {
            $packages[] = $row;
        }
        echo json_encode(['status' => 'success', 'data' => $packages]);
        return;
    }
    
    if ($action === 'create') {
        $required = ['name', 'duration', 'price', 'google_play_product_id'];
        foreach ($required as $field) {
            if (!isset($input[$field])) {
                echo json_encode(['status' => 'error', 'message' => "حقل $field مطلوب"]);
                return;
            }
        }
        
        $stmt = $conn->prepare("INSERT INTO vip_packages (name, duration, price, google_play_product_id, description, is_active) VALUES (?, ?, ?, ?, ?, ?)");
        $description = $input['description'] ?? '';
        $is_active = $input['is_active'] ?? 1;
        $stmt->bind_param("sidssi", $input['name'], $input['duration'], $input['price'], $input['google_play_product_id'], $description, $is_active);
        
        if ($stmt->execute()) {
            echo json_encode(['status' => 'success', 'message' => 'تم إنشاء الحزمة بنجاح', 'id' => $stmt->insert_id]);
        } else {
            echo json_encode(['status' => 'error', 'message' => 'فشل إنشاء الحزمة']);
        }
        $stmt->close();
        return;
    }
    
    if ($action === 'update') {
        if (!isset($input['id'])) {
            echo json_encode(['status' => 'error', 'message' => 'معرف الحزمة مطلوب']);
            return;
        }
        
        $fields = ['name', 'duration', 'price', 'google_play_product_id', 'description', 'is_active'];
        $updateFields = [];
        $params = [];
        $types = '';
        
        foreach ($fields as $field) {
            if (isset($input[$field])) {
                $updateFields[] = "$field = ?";
                $params[] = $input[$field];
                $types .= is_int($input[$field]) ? 'i' : (is_float($input[$field]) ? 'd' : (is_bool($input[$field]) ? 'i' : 's'));
            }
        }
        
        if (!empty($updateFields)) {
            $params[] = $input['id'];
            $types .= 'i';
            
            $sql = "UPDATE vip_packages SET " . implode(', ', $updateFields) . " WHERE id = ?";
            $stmt = $conn->prepare($sql);
            $stmt->bind_param($types, ...$params);
            
            if ($stmt->execute()) {
                echo json_encode(['status' => 'success', 'message' => 'تم تحديث الحزمة بنجاح']);
            } else {
                echo json_encode(['status' => 'error', 'message' => 'فشل التحديث']);
            }
            $stmt->close();
        }
        return;
    }
    
    if ($action === 'delete') {
        if (!isset($input['id'])) {
            echo json_encode(['status' => 'error', 'message' => 'معرف الحزمة مطلوب']);
            return;
        }
        
        $stmt = $conn->prepare("DELETE FROM vip_packages WHERE id = ?");
        $stmt->bind_param("i", $input['id']);
        
        if ($stmt->execute()) {
            echo json_encode(['status' => 'success', 'message' => 'تم حذف الحزمة بنجاح']);
        } else {
            echo json_encode(['status' => 'error', 'message' => 'فشل الحذف']);
        }
        $stmt->close();
        return;
    }
}

// إعدادات التطبيق
function manageAppSettings($conn) {
    $input = json_decode(file_get_contents('php://input'), true);
    $action = $input['action'] ?? '';
    $app = $input['app'] ?? 'main';
    
    if ($action === 'get') {
        // تحديد اسم الجدول الصحيح بناءً على التطبيق
        $tableName = 'app_config'; // التطبيق الأساسي
        if ($app === 'mohamed') {
            $tableName = 'Muhammed8080app_config';
        } elseif ($app === 'rivo') {
            $tableName = 'Revo_Shorts';
        }
        
        // جلب جميع الإعدادات من الجدول المناسب
        $result = $conn->query("SELECT * FROM $tableName");
        $settings = [];
        
        while ($row = $result->fetch_assoc()) {
            if (isset($row['config_key']) && isset($row['value'])) {
                $settings[$row['config_key']] = $row['value'];
            }
        }
        
        echo json_encode(['status' => 'success', 'data' => $settings, 'app' => $app]);
        return;
    }
    
    if ($action === 'update') {
        // تحديد اسم الجدول الصحيح بناءً على التطبيق
        $tableName = 'app_config'; // التطبيق الأساسي
        if ($app === 'mohamed') {
            $tableName = 'Muhammed8080app_config';
        } elseif ($app === 'rivo') {
            $tableName = 'Revo_Shorts';
        }
        
        $conn->autocommit(false);
        try {
            foreach ($input as $key => $value) {
                if ($key === 'action' || $key === 'app') continue; // تجاهل هذه المفاتيح
                
                // التحقق من وجود الإعداد وتحديثه أو إنشاؤه
                $checkStmt = $conn->prepare("SELECT COUNT(*) as count FROM $tableName WHERE config_key = ?");
                $checkStmt->bind_param("s", $key);
                $checkStmt->execute();
                $result = $checkStmt->get_result();
                $exists = $result->fetch_assoc()['count'] > 0;
                $checkStmt->close();
                
                if ($exists) {
                    // تحديث الإعداد الموجود
                    $stmt = $conn->prepare("UPDATE $tableName SET value = ? WHERE config_key = ?");
                    $stmt->bind_param("ss", $value, $key);
                } else {
                    // إنشاء إعداد جديد
                    $stmt = $conn->prepare("INSERT INTO $tableName (config_key, value) VALUES (?, ?)");
                    $stmt->bind_param("ss", $key, $value);
                }
                
                $stmt->execute();
                $stmt->close();
            }
            
            $conn->commit();
            echo json_encode(['status' => 'success', 'message' => "تم تحديث إعدادات التطبيق $app بنجاح"]);
        } catch (Exception $e) {
            $conn->rollback();
            echo json_encode(['status' => 'error', 'message' => 'فشل التحديث: ' . $e->getMessage()]);
        } finally {
            $conn->autocommit(true);
        }
        return;
    }
    
    if ($action === 'get_all') {
        // إرجاع إعدادات جميع التطبيقات
        $allSettings = [];
        
        $apps = [
            'main' => 'app_config',
            'mohamed' => 'Muhammed8080app_config', 
            'rivo' => 'Revo_Shorts'
        ];
        
        foreach ($apps as $appKey => $table) {
            $result = $conn->query("SELECT * FROM $table");
            $settings = [];
            
            while ($row = $result->fetch_assoc()) {
                if (isset($row['config_key']) && isset($row['value'])) {
                    $settings[$row['config_key']] = $row['value'];
                }
            }
            
            $allSettings[$appKey] = $settings;
        }
        
        echo json_encode(['status' => 'success', 'data' => $allSettings]);
        return;
    }
}

// إحصائيات Dashboard
function getDashboardStats($conn) {
    $stats = [];
    
    // عدد المسلسلات
    $result = $conn->query("SELECT COUNT(*) as count FROM series");
    $stats['total_series'] = $result->fetch_assoc()['count'];
    
    // عدد الحلقات
    $result = $conn->query("SELECT COUNT(*) as count FROM episodes");
    $stats['total_episodes'] = $result->fetch_assoc()['count'];
    
    // عدد المستخدمين
    $result = $conn->query("SELECT COUNT(*) as count FROM users");
    $stats['total_users'] = $result->fetch_assoc()['count'];
    
    // إجمالي العملات
    $result = $conn->query("SELECT SUM(coins) as total FROM users");
    $stats['total_coins'] = $result->fetch_assoc()['total'] ?? 0;
    
    // عدد المعاملات اليوم
    $today = date('Y-m-d');
    $result = $conn->query("SELECT COUNT(*) as count FROM coin_transactions WHERE DATE(created_at) = '$today'");
    $stats['today_transactions'] = $result->fetch_assoc()['count'];
    
    // عدد المشاهدات اليوم
    $result = $conn->query("SELECT COUNT(*) as count FROM views WHERE DATE(created_at) = '$today'");
    $stats['today_views'] = $result->fetch_assoc()['count'];
    
    echo json_encode(['status' => 'success', 'data' => $stats]);
}

// ====================== MULTI-APP CONFIGURATION FUNCTIONS ======================

// جلب إعدادات التطبيق حسب النوع
function getAppConfig($conn) {
    $input = json_decode(file_get_contents('php://input'), true);
    $app_key = $input['app'] ?? 'main';
    
    try {
        // تحديد الجدول والمعرف حسب نوع التطبيق
        $table_suffix = '';
        switch ($app_key) {
            case 'mohamed':
                $table_suffix = '_mohamed';
                break;
            case 'rivo':
                $table_suffix = '_rivo';
                break;
            case 'main':
            default:
                $table_suffix = '';
                break;
        }
        
        // البحث في جدول الإعدادات المخصص أو الأساسي
        $sql = "SELECT * FROM app_settings" . $table_suffix . " LIMIT 1";
        $result = $conn->query($sql);
        
        if (!$result) {
            // إذا لم يجد الجدول، إنشاء البيانات الافتراضية
            $default_settings = [
                'app_mode' => 1,
                'free_mode_ads' => 1,
                'site_name' => _getDefaultSiteNameForApp($app_key),
                'site_email' => 'admin@dramixshrt.com',
                'site_description' => _getDefaultDescriptionForApp($app_key),
                'items_per_page' => 20,
                'episode_price' => 10
            ];
            echo json_encode(['status' => 'success', 'data' => $default_settings]);
        } else {
            $settings = $result->fetch_assoc();
            if (!$settings) {
                $settings = [
                    'app_mode' => 1,
                    'free_mode_ads' => 1,
                    'site_name' => _getDefaultSiteNameForApp($app_key),
                    'site_email' => 'admin@dramixshrt.com',
                    'site_description' => _getDefaultDescriptionForApp($app_key),
                    'items_per_page' => 20,
                    'episode_price' => 10
                ];
            }
            echo json_encode(['status' => 'success', 'data' => $settings]);
        }
    } catch (Exception $e) {
        logError("getAppConfig Error: " . $e->getMessage());
        echo json_encode(['status' => 'error', 'message' => 'خطأ في جلب إعدادات التطبيق']);
    }
}

// تحديث إعدادات التطبيق حسب النوع
function updateAppConfig($conn) {
    $input = json_decode(file_get_contents('php://input'), true);
    $app_key = $input['app'] ?? 'main';
    
    // إزالة مفتاح app من البيانات
    unset($input['app']);
    
    try {
        $table_suffix = '';
        switch ($app_key) {
            case 'mohamed':
                $table_suffix = '_mohamed';
                break;
            case 'rivo':
                $table_suffix = '_rivo';
                break;
            case 'main':
            default:
                $table_suffix = '';
                break;
        }
        
        $table_name = "app_settings" . $table_suffix;
        
        // التحقق من وجود الجدول وإنشاؤه إذا لم يكن موجوداً
        $create_table_sql = "CREATE TABLE IF NOT EXISTS `" . $table_name . "` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `app_mode` tinyint(1) DEFAULT 1,
            `free_mode_ads` tinyint(1) DEFAULT 1,
            `site_name` varchar(255) DEFAULT '',
            `site_email` varchar(255) DEFAULT 'admin@dramixshrt.com',
            `site_description` text,
            `items_per_page` int(11) DEFAULT 20,
            `episode_price` int(11) DEFAULT 10,
            `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";
        
        $conn->query($create_table_sql);
        
        // التحقق من وجود سجل وإدراجه إذا لم يكن موجوداً
        $check_sql = "SELECT id FROM `" . $table_name . "` LIMIT 1";
        $result = $conn->query($check_sql);
        
        if (!$result || $result->num_rows == 0) {
            $default_name = _getDefaultSiteNameForApp($app_key);
            $default_desc = _getDefaultDescriptionForApp($app_key);
            $insert_sql = "INSERT INTO `" . $table_name . "` 
                          (app_mode, free_mode_ads, site_name, site_email, site_description, items_per_page, episode_price) 
                          VALUES (1, 1, ?, 'admin@dramixshrt.com', ?, 20, 10)";
            $stmt = $conn->prepare($insert_sql);
            $stmt->bind_param("ss", $default_name, $default_desc);
            $stmt->execute();
            $stmt->close();
        }
        
        // تحديث الإعدادات
        $fields = [];
        $params = [];
        $types = '';
        
        $allowed_fields = ['app_mode', 'free_mode_ads', 'site_name', 'site_email', 'site_description', 'items_per_page', 'episode_price'];
        
        foreach ($allowed_fields as $field) {
            if (isset($input[$field])) {
                $fields[] = "`$field` = ?";
                $params[] = $input[$field];
                $types .= is_int($input[$field]) ? 'i' : 's';
            }
        }
        
        if (!empty($fields)) {
            $sql = "UPDATE `" . $table_name . "` SET " . implode(', ', $fields) . " WHERE id = 1";
            $stmt = $conn->prepare($sql);
            $stmt->bind_param($types, ...$params);
            
            if ($stmt->execute()) {
                echo json_encode(['status' => 'success', 'message' => 'تم تحديث إعدادات التطبيق بنجاح']);
            } else {
                echo json_encode(['status' => 'error', 'message' => 'فشل في التحديث']);
            }
            $stmt->close();
        } else {
            echo json_encode(['status' => 'info', 'message' => 'لم يتم تحديد أي حقول للتحديث']);
        }
        
    } catch (Exception $e) {
        logError("updateAppConfig Error: " . $e->getMessage());
        echo json_encode(['status' => 'error', 'message' => 'خطأ في تحديث إعدادات التطبيق']);
    }
}

// جلب إعدادات AdMob حسب التطبيق
function getAdmobConfig($conn) {
    $input = json_decode(file_get_contents('php://input'), true);
    $app_key = $input['app'] ?? 'main';
    
    try {
        $table_suffix = '';
        switch ($app_key) {
            case 'mohamed':
                $table_suffix = '_mohamed';
                break;
            case 'rivo':
                $table_suffix = '_rivo';
                break;
            case 'main':
            default:
                $table_suffix = '';
                break;
        }
        
        $table_name = "admob_settings" . $table_suffix;
        $sql = "SELECT * FROM `" . $table_name . "` LIMIT 1";
        $result = $conn->query($sql);
        
        if (!$result) {
            // إرجاع الإعدادات الافتراضية إذا لم يجد الجدول
            $default_settings = [
                'app_id' => '',
                'banner' => '',
                'interstitial' => '',
                'rewarded1' => '',
                'rewarded2' => '',
                'rewarded3' => '',
                'rewarded4' => '',
                'rewarded5' => '',
                'rewarded6' => ''
            ];
            echo json_encode(['status' => 'success', 'data' => $default_settings]);
        } else {
            $settings = $result->fetch_assoc();
            if (!$settings) {
                $settings = [
                    'app_id' => '',
                    'banner' => '',
                    'interstitial' => '',
                    'rewarded1' => '',
                    'rewarded2' => '',
                    'rewarded3' => '',
                    'rewarded4' => '',
                    'rewarded5' => '',
                    'rewarded6' => ''
                ];
            }
            echo json_encode(['status' => 'success', 'data' => $settings]);
        }
    } catch (Exception $e) {
        logError("getAdmobConfig Error: " . $e->getMessage());
        echo json_encode(['status' => 'error', 'message' => 'خطأ في جلب إعدادات AdMob']);
    }
}

// تحديث إعدادات AdMob حسب التطبيق
function updateAdmobConfig($conn) {
    $input = json_decode(file_get_contents('php://input'), true);
    $app_key = $input['app'] ?? 'main';
    
    // إزالة مفتاح app من البيانات
    unset($input['app']);
    
    try {
        $table_suffix = '';
        switch ($app_key) {
            case 'mohamed':
                $table_suffix = '_mohamed';
                break;
            case 'rivo':
                $table_suffix = '_rivo';
                break;
            case 'main':
            default:
                $table_suffix = '';
                break;
        }
        
        $table_name = "admob_settings" . $table_suffix;
        
        // إنشاء الجدول إذا لم يكن موجوداً
        $create_table_sql = "CREATE TABLE IF NOT EXISTS `" . $table_name . "` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `app_id` varchar(255) DEFAULT '',
            `banner` varchar(255) DEFAULT '',
            `interstitial` varchar(255) DEFAULT '',
            `rewarded1` varchar(255) DEFAULT '',
            `rewarded2` varchar(255) DEFAULT '',
            `rewarded3` varchar(255) DEFAULT '',
            `rewarded4` varchar(255) DEFAULT '',
            `rewarded5` varchar(255) DEFAULT '',
            `rewarded6` varchar(255) DEFAULT '',
            `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";
        
        $conn->query($create_table_sql);
        
        // التحقق من وجود سجل وإدراجه إذا لم يكن موجوداً
        $check_sql = "SELECT id FROM `" . $table_name . "` LIMIT 1";
        $result = $conn->query($check_sql);
        
        if (!$result || $result->num_rows == 0) {
            $insert_sql = "INSERT INTO `" . $table_name . "` 
                          (app_id, banner, interstitial, rewarded1, rewarded2, rewarded3, rewarded4, rewarded5, rewarded6) 
                          VALUES ('', '', '', '', '', '', '', '', '')";
            $conn->query($insert_sql);
        }
        
        // تحديث الإعدادات
        $fields = [];
        $params = [];
        $types = '';
        
        $allowed_fields = ['app_id', 'banner', 'interstitial', 'rewarded1', 'rewarded2', 'rewarded3', 'rewarded4', 'rewarded5', 'rewarded6'];
        
        foreach ($allowed_fields as $field) {
            if (isset($input[$field])) {
                $fields[] = "`$field` = ?";
                $params[] = $input[$field];
                $types .= 's';
            }
        }
        
        if (!empty($fields)) {
            $sql = "UPDATE `" . $table_name . "` SET " . implode(', ', $fields) . " WHERE id = 1";
            $stmt = $conn->prepare($sql);
            $stmt->bind_param($types, ...$params);
            
            if ($stmt->execute()) {
                echo json_encode(['status' => 'success', 'message' => 'تم تحديث إعدادات AdMob بنجاح']);
            } else {
                echo json_encode(['status' => 'error', 'message' => 'فشل في التحديث']);
            }
            $stmt->close();
        } else {
            echo json_encode(['status' => 'info', 'message' => 'لم يتم تحديد أي حقول للتحديث']);
        }
        
    } catch (Exception $e) {
        logError("updateAdmobConfig Error: " . $e->getMessage());
        echo json_encode(['status' => 'error', 'message' => 'خطأ في تحديث إعدادات AdMob']);
    }
}

// وظائف مساعدة للحصول على الأسماء والأوصاف الافتراضية
function _getDefaultSiteNameForApp($app_key) {
    switch ($app_key) {
        case 'mohamed':
            return 'تطبيق محمد';
        case 'rivo':
            return 'ريفو شورت';
        case 'main':
        default:
            return 'DramaXBox';
    }
}

function _getDefaultDescriptionForApp($app_key) {
    switch ($app_key) {
        case 'mohamed':
            return 'تطبيق محمد للمسلسلات والأفلام العربية والأجنبية';
        case 'rivo':
            return 'ريفو شورت - أفضل منصة للفيديوهات القصيرة والمحتوى الترفيهي';
        case 'main':
        default:
            return 'DramaXBox - منصة المسلسلات المتقدمة للمحتوى العربي والعالمي';
    }
}