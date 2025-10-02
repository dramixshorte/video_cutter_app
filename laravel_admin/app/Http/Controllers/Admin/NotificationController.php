<?php
namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Notification;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class NotificationController extends Controller
{
    public function index() {
        $notifications = Notification::query()->orderByDesc('id')->paginate(30);
        return view('admin.notifications.index', compact('notifications'));
    }

    public function create() { return view('admin.notifications.create'); }

    public function store(Request $request) {
        $data = $request->validate([
            'title' => 'required|string|max:255',
            'body' => 'nullable|string',
            'target_topic' => 'nullable|string'
        ]);
        $notification = Notification::create([
            ...$data,
            'app_id' => $request->get('app_id','main'),
            'payload' => null,
            'sent_at' => now()
        ]);
        // TODO: dispatch to Firebase (service stub to be added)
        Log::info('Notification stored (dispatch pending)', ['id' => $notification->id]);
        return redirect()->route('admin.notifications.index')->with('status','Notification queued');
    }
}