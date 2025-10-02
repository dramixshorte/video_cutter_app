<?php
namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Setting;
use Illuminate\Http\Request;

class SettingsController extends Controller
{
    public function index() {
        $settings = Setting::query()->where('app_id','main')->orderBy('key')->get();
        return view('admin.settings.index', compact('settings'));
    }

    public function store(Request $request) {
        $data = $request->validate([
            'key' => 'required|string|max:255',
            'value' => 'nullable|string'
        ]);
        Setting::updateOrCreate([
            'app_id' => $request->get('app_id','main'),
            'key' => $data['key']
        ], [ 'value' => $data['value'] ?? null ]);
        return redirect()->route('admin.settings.index')->with('status','Setting saved');
    }

    public function destroy(Setting $setting) {
        $setting->delete();
        return redirect()->route('admin.settings.index')->with('status','Setting removed');
    }
}