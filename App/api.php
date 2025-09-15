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
            New_Methods_uploadEpisode($conn);
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
    // بداية تسجيل تفاصيل الرفع
    logActivity("====== بدء رفع حلقة جديدة ======");
    
    if (!isset($_POST['series_id']) || !isset($_POST['episode_number'])) {
        logActivity("ERROR: Missing series_id or episode_number");
        throw new Exception('يجب تحديد معرف المسلسل ورقم الحلقة');
    }

    $series_id = intval($_POST['series_id']);
    $episode_number = intval($_POST['episode_number']);
    $title = $conn->real_escape_string($_POST['title'] ?? 'الحلقة ' . $episode_number);
    
    logActivity("المعطيات المستلمة:");
    logActivity("series_id: $series_id");
    logActivity("episode_number: $episode_number");
    logActivity("title: $title");

    if (!isset($_FILES['video'])) {
        logActivity("ERROR: No video file uploaded");
        throw new Exception('لم يتم رفع ملف الفيديو');
    }
    
    $video = $_FILES['video'];
    logActivity("معلومات ملف الفيديو:");
    logActivity("Name: " . $video['name']);
    logActivity("Size: " . $video['size']);
    logActivity("Temp: " . $video['tmp_name']);
    
    // بدء المعاملة
    $conn->autocommit(false);
    
    try {
        // التحقق من صحة الفيديو فقط
        $video_type = strtolower(pathinfo($video['name'], PATHINFO_EXTENSION));
        $allowed = ['mp4', 'avi', 'mov', 'mkv', 'webm'];
        
        if (!in_array($video_type, $allowed)) {
            throw new Exception('نوع الفيديو غير مدعوم: ' . $video_type);
        }
        
        // زيادة الحد الأقصى للحجم إلى 2GB
        if ($video['size'] > 2 * 1024 * 1024 * 1024) {
            throw new Exception('حجم الفيديو يتجاوز 2GB');
        }

        $target_dir = "series_episodes/";
        if (!file_exists($target_dir)) {
            if (!mkdir($target_dir, 0755, true)) {
                throw new Exception('فشل إنشاء مجلد الحلقات');
            }
        }

        // ✅ إزالة التحقق من وجود المسلسل - نرفع مباشرة
        
        // التحقق من وجود الحلقة وحذفها إذا كانت موجودة
        $chk = $conn->prepare("SELECT id, video_path FROM episodes WHERE series_id = ? AND episode_number = ?");
        if (!$chk) {
            throw new Exception('خطأ في الاستعداد للاستعلام: ' . $conn->error);
        }
        $chk->bind_param("ii", $series_id, $episode_number);
        $chk->execute();
        $chk->store_result();
        
        $old_video_path = '';
        $old_id = null;
        if ($chk->num_rows > 0) {
            $chk->bind_result($old_id, $old_path);
            $chk->fetch();
            $old_video_path = $old_path;
            
            // حذف الحلقة القديمة من قاعدة البيانات
            $delete = $conn->prepare("DELETE FROM episodes WHERE id = ?");
            if (!$delete) {
                throw new Exception('خطأ في الاستعداد للاستعلام: ' . $conn->error);
            }
            $delete->bind_param("i", $old_id);
            $delete->execute();
            $delete->close();
            
            logActivity("تم حذف الحلقة القديمة: $old_id");
        }
        $chk->close();

        // رفع الفيديو الجديد
        $filename = "ep_{$series_id}_{$episode_number}_" . time() . '.' . $video_type;
        $target_path = $target_dir . $filename;

        logActivity("محاولة نقل الملف إلى: $target_path");
        
        // ✅ رفع الملف مع الحفاظ على الاتصال
        $upload_success = false;
        
        // للملفات الكبيرة نستخدم الرفع على أجزاء
        if ($video['size'] > 50 * 1024 * 1024) {
            $chunk_size = 2 * 1024 * 1024; // 2MB chunks
            $src_handle = fopen($video['tmp_name'], 'rb');
            $dest_handle = fopen($target_path, 'wb');
            
            if ($src_handle && $dest_handle) {
                while (!feof($src_handle)) {
                    $chunk = fread($src_handle, $chunk_size);
                    if (fwrite($dest_handle, $chunk) === false) {
                        break;
                    }
                    // إفراز buffer للحفاظ على الاتصال
                    ob_flush();
                    flush();
                    usleep(10000); // 10ms delay لتقليل الحمل
                }
                fclose($src_handle);
                fclose($dest_handle);
                $upload_success = true;
            }
        } else {
            $upload_success = move_uploaded_file($video['tmp_name'], $target_path);
        }
        
        if ($upload_success) {
            logActivity("تم نقل الملف بنجاح إلى: $target_path");
            logActivity("حجم الملف: " . filesize($target_path) . " bytes");
            
            // حذف الفيديو القديم إذا كان موجودًا
            if (!empty($old_video_path) && file_exists($target_dir . $old_video_path)) {
                if (unlink($target_dir . $old_video_path)) {
                    logActivity("تم حذف الفيديو القديم: $old_video_path");
                }
            }
            
            // إدراج الحلقة الجديدة
            $insert = $conn->prepare("INSERT INTO episodes (series_id, title, episode_number, video_path) VALUES (?, ?, ?, ?)");
            if (!$insert) {
                throw new Exception('خطأ في الاستعداد للاستعلام: ' . $conn->error);
            }
            $insert->bind_param("isis", $series_id, $title, $episode_number, $filename);

            if ($insert->execute()) {
                logActivity("تم إدخال الحلقة في قاعدة البيانات، ID: " . $insert->insert_id);
                
                $conn->commit();
                logActivity("تم تأكيد المعاملة بنجاح");
                
                echo json_encode([
                    'status' => 'success',
                    'message' => 'تم رفع الحلقة بنجاح',
                    'file_name' => $filename,
                    'episode_id' => $insert->insert_id
                ]);
            } else {
                throw new Exception('فشل إدخال البيانات في قاعدة البيانات: ' . $conn->error);
            }
            
            $insert->close();
        } else {
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




function New_Methods_uploadEpisode($conn) { 
    if (!isset($_POST['series_id']) || !isset($_POST['episode_number'])) {
        throw new Exception('يجب تحديد معرف المسلسل ورقم الحلقة');
    }

    $series_id = intval($_POST['series_id']);
    $episode_number = intval($_POST['episode_number']);
    $title = $conn->real_escape_string($_POST['title'] ?? 'الحلقة ' . $episode_number);

    if (!isset($_FILES['video'])) {
        throw new Exception('لم يتم رفع الفيديو');
    }

    $video = $_FILES['video'];
    $video_type = strtolower(pathinfo($video['name'], PATHINFO_EXTENSION));
    $allowed = ['mp4', 'avi', 'mov', 'mkv', 'webm'];
    if (!in_array($video_type, $allowed)) {
        throw new Exception('نوع الفيديو غير مدعوم: ' . $video_type);
    }

    $target_dir = "series_episodes/";
    if (!file_exists($target_dir)) mkdir($target_dir, 0755, true);

    $filename = "ep_{$series_id}_{$episode_number}_" . time() . '.' . $video_type;
    $target_path = $target_dir . $filename;

    // رفع الملف (يفترض أن الحلقة ≤ 100MB بعد التقطيع)
    if (!move_uploaded_file($video['tmp_name'], $target_path)) {
        throw new Exception("فشل رفع الفيديو");
    }

    // حفظ في قاعدة البيانات
    $insert = $conn->prepare("INSERT INTO episodes (series_id, title, episode_number, video_path) VALUES (?, ?, ?, ?)");
    $insert->bind_param("isis", $series_id, $title, $episode_number, $filename);

    if ($insert->execute()) {
        echo json_encode([
            'status' => 'success',
            'message' => 'تم رفع الحلقة بنجاح',
            'file_name' => $filename,
            'episode_id' => $insert->insert_id
        ]);
    } else {
        throw new Exception('فشل إدخال البيانات: ' . $conn->error);
    }
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
            
            // ========== إرسال الإشعار كما في صفحة HTML ==========
            $base_url = "https://dramabox1.site/App";
            $full_image_url = $base_url . "/series_images/" . $new_image_name;
            
            try {
                // بيانات الإشعار بنفس شكل صفحة HTML
                $notificationData = [
                    'type' => 'new_series',
                    'series_id' => (string)$series_id,
                    'series_title' => $name,
                    'series_description' => $series_description,
                    'image_url' => $full_image_url,
                    'timestamp' => date('Y-m-d H:i:s'),
                    'click_action' => 'FLUTTER_NOTIFICATION_CLICK'
                ];
                
                // إنشاء الإشعار
                $notification = \Kreait\Firebase\Messaging\Notification::create(
                    '🎬 ' . $name,
                    $series_description
                );
                
                // تكوين الرسالة بنفس إعدادات صفحة HTML
                $message = \Kreait\Firebase\Messaging\CloudMessage::withTarget('topic', 'all')
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
                            'tag' => 'series_' . $series_id,
                            'image' => $full_image_url
                        ]
                    ])
                    ->withApnsConfig([
                        'payload' => [
                            'aps' => [
                                'alert' => [
                                    'title' => '🎬 ' . $name,
                                    'body' => $series_description
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
                
                // إرسال الإشعار
                $result = $messaging->send($message);
                
                logActivity("تم إرسال إشعار مسلسل جديد: " . $name . " (ID: " . $series_id . ")");
                
            } catch (Exception $e) {
                logError("فشل إرسال الإشعار: " . $e->getMessage());
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
                'notification_sent' => isset($result) ? true : false,
                'notification_message' => $series_description
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
    
    if ($action === 'get') {
        $result = $conn->query("SELECT * FROM admob_settings LIMIT 1");
        $settings = $result->fetch_assoc();
        echo json_encode(['status' => 'success', 'data' => $settings]);
        return;
    }
    
    if ($action === 'update') {
        $fields = [
            'rewarded1', 'rewarded2', 'rewarded3', 'rewarded4', 
            'rewarded5', 'rewarded6', 'banner', 'interstitial', 'app_id'
        ];
        
        $updateFields = [];
        $params = [];
        $types = '';
        
        foreach ($fields as $field) {
            if (isset($input[$field])) {
                $updateFields[] = "$field = ?";
                $params[] = $input[$field];
                $types .= 's';
            }
        }
        
        if (!empty($updateFields)) {
            $sql = "UPDATE admob_settings SET " . implode(', ', $updateFields) . " WHERE id = 1";
            $stmt = $conn->prepare($sql);
            $stmt->bind_param($types, ...$params);
            
            if ($stmt->execute()) {
                echo json_encode(['status' => 'success', 'message' => 'تم تحديث إعدادات AdMob']);
            } else {
                echo json_encode(['status' => 'error', 'message' => 'فشل التحديث']);
            }
            $stmt->close();
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
    
    if ($action === 'get') {
        $result = $conn->query("SELECT * FROM system_settings LIMIT 1");
        $settings = $result->fetch_assoc();
        
        $appMode = $conn->query("SELECT value FROM app_config WHERE config_key = 'app_mode' LIMIT 1");
        $settings['app_mode'] = $appMode->fetch_assoc()['value'] ?? 1;
        
        echo json_encode(['status' => 'success', 'data' => $settings]);
        return;
    }
    
    if ($action === 'update') {
        $fields = [
            'site_name', 'site_email', 'items_per_page', 'episode_price', 
            'site_description', 'app_mode'
        ];
        
        $conn->autocommit(false);
        try {
            foreach ($fields as $field) {
                if (isset($input[$field])) {
                    if ($field === 'app_mode') {
                        $stmt = $conn->prepare("UPDATE app_config SET value = ? WHERE config_key = 'app_mode'");
                        $stmt->bind_param("i", $input[$field]);
                    } else {
                        $stmt = $conn->prepare("UPDATE system_settings SET $field = ? WHERE id = 1");
                        $stmt->bind_param("s", $input[$field]);
                    }
                    $stmt->execute();
                    $stmt->close();
                }
            }
            
            $conn->commit();
            echo json_encode(['status' => 'success', 'message' => 'تم تحديث الإعدادات بنجاح']);
        } catch (Exception $e) {
            $conn->rollback();
            echo json_encode(['status' => 'error', 'message' => 'فشل التحديث: ' . $e->getMessage()]);
        } finally {
            $conn->autocommit(true);
        }
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