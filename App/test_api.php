<?php
// زيادة مهلة التنفيذ والذاكرة
set_time_limit(0);
ini_set('max_execution_time', 300);
ini_set('upload_max_filesize', '500M');
ini_set('post_max_size', '500M');
ini_set('memory_limit', '512M');
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/api_errors.log');

require __DIR__ . '/vendor/autoload.php';
use Kreait\Firebase\Factory;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification;

// إعدادات Firebase
$factory = (new Factory)->withServiceAccount(__DIR__ . '/firebase-service-account.json');
$messaging = $factory->createMessaging();

// CORS Headers
header('Access-Control-Allow-Origin: *');
header('Content-Type: application/json');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// معلومات اتصال قاعدة البيانات
$servername = "localhost";
$username = "xpmoiqwz_allVideos";
$password = "xpmoiqwz_allVideos";
$dbname = "xpmoiqwz_allVideos";

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
        case 'create_series':
            createSeries($conn);
            break;
        case 'upload_episode':
            uploadEpisode($conn);
            break;
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
        case 'get_categories':
            getCategories($conn);
            break;
        case 'create_category':
            createCategory($conn);
            break;
        case 'delete_category':
            deleteCategory($conn);
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

// ====================== CATEGORY FUNCTIONS ======================
function getCategories($conn) {
    $query = "
        SELECT 
            c.id, 
            c.name, 
            COUNT(s.id) as series_count
        FROM 
            categories c
        LEFT JOIN 
            series s ON c.id = s.category_id
        GROUP BY 
            c.id
        ORDER BY 
            c.name ASC
    ";
    
    $result = $conn->query($query);
    
    if (!$result) {
        logError("Query failed: " . $conn->error);
        echo json_encode(['status' => 'error', 'message' => 'Database error']);
        return;
    }
    
    $categories = [];
    while ($row = $result->fetch_assoc()) {
        $categories[] = [
            'id' => (int)$row['id'],
            'name' => $row['name'],
            'series_count' => (int)$row['series_count']
        ];
    }
    
    echo json_encode([
        'status' => 'success',
        'data' => $categories,
        'count' => count($categories)
    ]);
}

function createCategory($conn) {
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!isset($input['name']) || empty($input['name'])) {
        echo json_encode(['status' => 'error', 'message' => 'Category name is required']);
        return;
    }
    
    $name = $conn->real_escape_string($input['name']);
    
    $stmt = $conn->prepare("INSERT INTO categories (name) VALUES (?)");
    $stmt->bind_param("s", $name);
    
    if ($stmt->execute()) {
        logActivity("Created new category: $name");
        echo json_encode([
            'status' => 'success',
            'message' => 'Category created successfully',
            'category_id' => $stmt->insert_id
        ]);
    } else {
        logError("Failed to create category: " . $stmt->error);
        echo json_encode(['status' => 'error', 'message' => 'Failed to create category']);
    }
    
    $stmt->close();
}

function deleteCategory($conn) {
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!isset($input['category_id'])) {
        echo json_encode(['status' => 'error', 'message' => 'Category ID is required']);
        return;
    }
    
    $category_id = (int)$input['category_id'];
    
    // التحقق من عدم وجود مسلسلات مرتبطة بالفئة
    $check_stmt = $conn->prepare("SELECT COUNT(*) FROM series WHERE category_id = ?");
    $check_stmt->bind_param("i", $category_id);
    $check_stmt->execute();
    $check_stmt->bind_result($series_count);
    $check_stmt->fetch();
    $check_stmt->close();
    
    if ($series_count > 0) {
        echo json_encode([
            'status' => 'error',
            'message' => 'Cannot delete category with associated series'
        ]);
        return;
    }
    
    $stmt = $conn->prepare("DELETE FROM categories WHERE id = ?");
    $stmt->bind_param("i", $category_id);
    
    if ($stmt->execute()) {
        logActivity("Deleted category ID: $category_id");
        echo json_encode(['status' => 'success', 'message' => 'Category deleted successfully']);
    } else {
        logError("Failed to delete category: " . $stmt->error);
        echo json_encode(['status' => 'error', 'message' => 'Failed to delete category']);
    }
    
    $stmt->close();
}

// ====================== SERIES FUNCTIONS ======================
function getAllSeries($conn) {
    $query = "
        SELECT 
            s.id, 
            s.name, 
            s.image_path,
            s.category_id,
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
            'category_id' => (int)$row['category_id'],
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

function createSeries($conn) {
    $input = json_decode(file_get_contents('php://input'), true);
    global $messaging;
    
    $name = $conn->real_escape_string($input['name'] ?? '');
    $image_path = $input['image_path'] ?? '';
    $category_id = (int)($input['category_id'] ?? 1);
    
    if (empty($name)) {
        echo json_encode(['status' => 'error', 'message' => 'Series name is required']);
        return;
    }
    
    if (empty($image_path)) {
        echo json_encode(['status' => 'error', 'message' => 'Image path is required']);
        return;
    }
    
    // بدء المعاملة
    $conn->autocommit(false);
    
    try {
        // إدراج المسلسل
        $stmt = $conn->prepare("INSERT INTO series (name, image_path, category_id) VALUES (?, ?, ?)");
        $stmt->bind_param("ssi", $name, $image_path, $category_id);
        
        if (!$stmt->execute()) {
            throw new Exception('Failed to create series: ' . $stmt->error);
        }
        
        $series_id = $stmt->insert_id;
        $stmt->close();
        
        // إرسال إشعار
        $base_url = "https://mingleme.site/App";
        $full_image_url = $base_url . "/series_images/" . $image_path;
        
        $message = [
            'data' => [
                'type' => 'series',
                'series_id' => $series_id,
                'series_title' => $name,
                'image_url' => $full_image_url,
                'click_action' => 'FLUTTER_NOTIFICATION_CLICK'
            ],
            'notification' => [
                'title' => '🎬 ' . $name,
                'body' => $name,
                'image' => $full_image_url
            ],
            'android' => [
                'notification' => [
                    'channel_id' => 'professional_series_channel',
                    'sound' => 'notification_sound',
                    'color' => '#0000FF',
                    'image' => $full_image_url
                ]
            ],
            'apns' => [
                'payload' => [
                    'aps' => [
                        'sound' => 'notification_sound.caf',
                        'mutable-content' => 1
                    ]
                ]
            ],
            'topic' => 'all'
        ];
        
        $messaging->send(CloudMessage::fromArray($message));
        
        $conn->commit();
        
        echo json_encode([
            'status' => 'success',
            'message' => 'Series created successfully',
            'series_id' => $series_id
        ]);
        
        logActivity("Created new series: $name (ID: $series_id)");
    } catch (Exception $e) {
        $conn->rollback();
        logError("createSeries error: " . $e->getMessage());
        echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
    } finally {
        $conn->autocommit(true);
    }
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

// ====================== EPISODE FUNCTIONS ======================
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
    
   $stmt->bind_result($id, $series_id, $title, $episode_number, $video_path, $created_at);
$episodes = [];

while ($stmt->fetch()) {
    $episodes[] = [
        'id' => (int)$id,
        'series_id' => (int)$series_id,
        'title' => $title,
        'episode_number' => (int)$episode_number,
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

function uploadEpisode($conn) {
    if (!isset($_POST['series_id']) || !isset($_POST['episode_number'])) {
        throw new Exception('Missing required fields');
    }
    
    logActivity("====== بدء رفع حلقة جديدة ======");
    
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
    
    $conn->autocommit(false);
    $success = false;
    $target_path = '';
    
    try {
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

// ====================== IMAGE UPLOAD ======================
function handleImageUpload($conn) {
    logActivity("Starting image upload process");

    if (!isset($_FILES['image'])) {
        throw new Exception('No image file uploaded');
    }

    $target_dir = "series_images/";
    
    if (!file_exists($target_dir)) {
        logActivity("Image directory doesn't exist, attempting to create");
        if (!mkdir($target_dir, 0755, true)) {
            throw new Exception('Failed to create image directory');
        }
        logActivity("Image directory created successfully");
    } else {
        logActivity("Image directory exists");
    }

    if (!is_writable($target_dir)) {
        logActivity("Image directory is not writable");
        throw new Exception('Image directory is not writable');
    }

    $image = $_FILES['image'];
    $image_name = basename($image['name']);
    $image_type = strtolower(pathinfo($image_name, PATHINFO_EXTENSION));
    
    logActivity("Uploading file: $image_name, Size: {$image['size']}, Type: $image_type");

    $allowed_types = ['jpg', 'jpeg', 'png', 'gif'];
    if (!in_array($image_type, $allowed_types)) {
        throw new Exception('Only JPG, JPEG, PNG & GIF files are allowed');
    }

    if ($image['size'] > 5 * 1024 * 1024) {
        throw new Exception('Image exceeds maximum size of 5MB');
    }

    $new_filename = 'img_' . uniqid() . '.' . $image_type;
    $target_path = $target_dir . $new_filename;

    logActivity("Attempting to move file to: $target_path");

    if (move_uploaded_file($image['tmp_name'], $target_path)) {
        logActivity("Image uploaded successfully: $new_filename");
        
        echo json_encode([
            'status' => 'success', 
            'image_path' => $new_filename,
            'image_name' => $new_filename
        ]);
    } else {
        $error = error_get_last();
        logActivity("Failed to move uploaded file: " . ($error['message'] ?? 'Unknown error'));
        throw new Exception('Failed to upload image. Error: ' . ($error['message'] ?? 'Unknown error'));
    }
}