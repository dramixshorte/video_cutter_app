<?php
// زيادة مهلة التنفيذ والذاكرة - الإصلاح الأول
ini_set('max_execution_time', 0);     // 24 ساعة
ini_set('max_input_time', 0);         
ini_set('upload_max_filesize', '10000M'); 
ini_set('post_max_size', '10000M');       
ini_set('memory_limit', '3048M');        // 2GB كحد معقول

// تمكين تسجيل الأخطاء
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/api_errors.log');

// إضافة هذه الإعدادات الجديدة لمنع انقطاع الاتصال
ignore_user_abort(true);
set_time_limit(0);
ob_start();
session_write_close(); // تحسين الأداء

// CORS Headers - التأكد من أنها في الأعلى
header('Access-Control-Allow-Origin: *');
header('Content-Type: application/json');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Access-Control-Max-Age: 86400');

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit();
}
ini_set('error_log22', __DIR__ . '/api_errors22.log');
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
$password = "123456";
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
        case 'create_series':
            createSeries($conn);
            break;
        case 'upload_episode':
            uploadEpisode($conn);
            break;
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
        default:
            echo json_encode(['status' => 'error', 'message' => 'Invalid action']);
            break;
    }
} catch (Exception $e) {
    logError("API Error: " . $e->getMessage());
    echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
}

$conn->close();


function logError($message) {
    error_log("[" . date('Y-m-d H:i:s') . "] ERROR: $message\n", 3, __DIR__ . '/api_errors.log');
}
function logActivity($message) {
    error_log("[" . date('Y-m-d H:i:s') . "] ACTIVITY: $message\n", 3, __DIR__ . '/api_activity.log');
}

function logActivity22($message) {
    error_log("[" . date('Y-m-d H:i:s') . "] ACTIVITY: $message\n", 3, __DIR__ . '/api_activity22.log');
}


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
    // Declare variables before binding
    $id = $series_id = $title = $episode_number = $video_path = $created_at = null;
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
        $video_path = null;
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
    logActivity("بدء رفع الصورة");
    
    if (!isset($_FILES['image'])) {
        throw new Exception('لم يتم رفع أي صورة');
    }

    $target_dir = "series_images/";
    
    // التأكد من وجود المجلد
    if (!file_exists($target_dir)) {
        if (!mkdir($target_dir, 0755, true)) {
            throw new Exception('فشل إنشاء مجلد الصور');
        }
    }

    $image = $_FILES['image'];
    $image_name = basename($image['name']);
    $image_type = strtolower(pathinfo($image_name, PATHINFO_EXTENSION));
    
    logActivity("رفع ملف: $image_name, الحجم: {$image['size']}, النوع: $image_type");

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

    if (move_uploaded_file($image['tmp_name'], $target_path)) {
        logActivity("تم رفع الصورة بنجاح: $new_filename");
        
        echo json_encode([
            'status' => 'success', 
            'image_path' => $new_filename,
            'image_name' => $new_filename
        ]);
    } else {
        $error = error_get_last();
        throw new Exception('فشل رفع الصورة: ' . ($error['message'] ?? 'Unknown error'));
    }
}



function uploadEpisode($conn) {
    // بداية تسجيل تفاصيل الرفع
    logActivity22("====== بدء رفع حلقة جديدة ======");
    
    // التحقق من وجود البيانات الأساسية
    if (!isset($_POST['series_id']) || !isset($_POST['episode_number'])) {
        // logActivity22("ERROR: Missing series_id or episode_number");
        throw new Exception('Missing required fields');
    }

    $series_id = intval($_POST['series_id']);
    $episode_number = intval($_POST['episode_number']);
    $title = $conn->real_escape_string($_POST['title'] ?? '');
    
    // logActivity22("المعطيات المستلمة:");
    // logActivity22("series_id: $series_id");
    // logActivity22("episode_number: $episode_number");
    // logActivity22("title: $title");

    if (!isset($_FILES['video'])) {
        logActivity22("ERROR: No video file uploaded");
        throw new Exception('No video uploaded');
    }
    
    $video = $_FILES['video'];
    // logActivity22("معلومات ملف الفيديو:");
    // logActivity22("Name: " . $video['name']);
    // logActivity22("Size: " . $video['size']);
    // logActivity22("Temp: " . $video['tmp_name']);
    
    // بدء المعاملة
    $conn->autocommit(false);
    
    try {
        // التحقق من صحة الفيديو
        $video_type = strtolower(pathinfo($video['name'], PATHINFO_EXTENSION));
        $allowed = ['mp4', 'avi', 'mov', 'mkv', 'webm'];
        
        if (!in_array($video_type, $allowed)) {
            throw new Exception('نوع الفيديو غير مدعوم: ' . $video_type);
        }
        
        if ($video['size'] > 500 * 1024 * 1024) {
            throw new Exception('حجم الفيديو يتجاوز 500MB');
        }

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
        // Declare variables before binding
        $series_name = $series_image = null;
        $stmt->bind_result($series_name, $series_image);
        
        if (!$stmt->fetch()) {
            throw new Exception('المسلسل غير موجود');
        }
        $stmt->close();

        // التحقق من وجود الحلقة وحذفها إذا كانت موجودة
        $chk = $conn->prepare("SELECT id, video_path FROM episodes WHERE series_id = ? AND episode_number = ?");
        $chk->bind_param("ii", $series_id, $episode_number);
        $chk->execute();
        $chk->store_result();
        
        $old_video_path = '';
        $old_id = null;
        $old_path = null;
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

        // ✅ الإصلاح المهم: استخدام move_uploaded_file بشكل صحيح
        if (move_uploaded_file($video['tmp_name'], $target_path)) {
            logActivity22("تم نقل الملف بنجاح إلى: $target_path");
            
            // حذف الفيديو القديم إذا كان موجودًا
            if (!empty($old_video_path) && file_exists($target_dir . $old_video_path)) {
                @unlink($target_dir . $old_video_path);
                logActivity22("تم حذف الفيديو القديم: $old_video_path");
            }
            
            // إدراج الحلقة الجديدة
            $insert = $conn->prepare("INSERT INTO episodes (series_id, title, episode_number, video_path) VALUES (?, ?, ?, ?)");
            $insert->bind_param("isis", $series_id, $title, $episode_number, $filename);

            if ($insert->execute()) {
                logActivity22("تم إدخال الحلقة في قاعدة البيانات");
                
                $conn->commit();
                logActivity22("تم تأكيد المعاملة بنجاح");
                
                echo json_encode([
                    'status' => 'success',
                    'message' => 'تم رفع الحلقة بنجاح',
                    'file_name' => $filename
                ]);
            } else {
                throw new Exception('فشل إدخال البيانات في قاعدة البيانات: ' . $conn->error);
            }
        } else {
            // ✅ إصلاح مهم: الحصول على خطأ move_uploaded_file
            $error = error_get_last();
            throw new Exception('فشل نقل الملف: ' . ($error['message'] ?? 'Unknown error'));
        }
    } catch (Exception $e) {
        $conn->rollback();
        logError("Error in uploadEpisode: " . $e->getMessage());
        
        // حذف الملف الذي تم رفعه في حالة الفشل
        if (!empty($target_path) && file_exists($target_path)) {
            @unlink($target_path);
        }
        
        throw new Exception('فشل رفع الحلقة: ' . $e->getMessage());
    } finally {
        $conn->autocommit(true);
    }
}



function createSeries($conn) {
    $data = json_decode(file_get_contents('php://input'), true);
    global $messaging;
    
    $name = $conn->real_escape_string($data['name'] ?? '');
    $original_image_path = $data['image_path'] ?? '';
    $replace_existing = isset($data['replace_existing']) ? (bool)$data['replace_existing'] : false;
    
    if (empty($name)) throw new Exception('Series name is required');
    if (empty($original_image_path)) throw new Exception('Image path is required');

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
        $insert_sql = "INSERT INTO series (name, image_path) VALUES (?, ?)";
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
            
            // ✅ إرسال الإشعار بشكل صحيح
            try {
                $base_url = "https://dramaxbox.bbs.tr/App";
                $full_image_url = $base_url . "/series_images/" . $new_image_name;

                // إنشاء الإشعار
                $notification = Notification::create(
                    '🎬 ' . $name,
                    'مسلسل جديد متاح الآن!'
                );

                // إنشاء الرسالة
                $message = CloudMessage::withTarget('topic', 'all')
                    ->withNotification($notification)
                    ->withData([
                        'type' => 'new_series',
                        'series_id' => (string)$series_id,
                        'series_title' => $name,
                        'series_description' => 'مسلسل جديد متاح الآن!',
                        'image_url' => $full_image_url,
                        'click_action' => 'FLUTTER_NOTIFICATION_CLICK'
                    ])
                    ->withAndroidConfig([
                        'priority' => 'high',
                        'notification' => [
                            'channel_id' => 'professional_series_channel',
                            'color' => '#FF0000',
                            'image' => $full_image_url,
                            'sound' => 'notification_sound',
                            'visibility' => 'public',
                            'icon' => 'ic_notification'
                        ]
                    ])
                    ->withApnsConfig([
                        'payload' => [
                            'aps' => [
                                'alert' => [
                                    'title' => '🎬 ' . $name,
                                    'body' => 'مسلسل جديد متاح الآن!'
                                ],
                                'sound' => 'default',
                                'mutable-content' => 1,
                                'badge' => 1,
                                'category' => 'series_notifications'
                            ],
                            'fcm_options' => [
                                'image' => $full_image_url
                            ]
                        ]
                    ]);

                // إرسال الرسالة
                $messaging->send($message);
                logActivity("تم إرسال إشعار مسلسل جديد: " . $name);
                
            } catch (Exception $e) {
                logError("فشل إرسال الإشعار: " . $e->getMessage());
                // لا توقف العملية إذا فشل الإشعار
            }
            
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
                'replaced_old' => $replace_existing
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
        // Declare variables before binding
        $id = $sname = $image_path = null;
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