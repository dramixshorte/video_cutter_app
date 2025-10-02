<?php
namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Episode;
use App\Models\Series;
use Illuminate\Http\Request;

class EpisodeController extends Controller
{
    public function index(Series $series) {
        $episodes = $series->episodes()->paginate(50);
        return view('admin.episodes.index', compact('series','episodes'));
    }

    public function create(Series $series) { return view('admin.episodes.create', compact('series')); }

    public function store(Request $request, Series $series) {
        $data = $request->validate([
            'title' => 'required|string|max:255',
            'description' => 'nullable|string',
            'video_path' => 'required|string',
            'duration' => 'nullable|integer',
            'order_index' => 'nullable|integer',
            'is_active' => 'nullable|boolean'
        ]);
        $data['series_id'] = $series->id;
        $data['app_id'] = $request->get('app_id','main');
        Episode::create($data);
        return redirect()->route('admin.series.episodes.index',$series)->with('status','Episode created');
    }

    public function edit(Series $series, Episode $episode) { return view('admin.episodes.edit', compact('series','episode')); }

    public function update(Request $request, Series $series, Episode $episode) {
        $data = $request->validate([
            'title' => 'required|string|max:255',
            'description' => 'nullable|string',
            'video_path' => 'required|string',
            'duration' => 'nullable|integer',
            'order_index' => 'nullable|integer',
            'is_active' => 'nullable|boolean'
        ]);
        $episode->update($data);
        return redirect()->route('admin.series.episodes.index',$series)->with('status','Episode updated');
    }

    public function destroy(Series $series, Episode $episode) {
        $episode->delete();
        return redirect()->route('admin.series.episodes.index',$series)->with('status','Episode deleted');
    }
}