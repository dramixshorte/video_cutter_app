<?php
namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureRole
{
    public function handle(Request $request, Closure $next, ...$roles): Response
    {
        $user = $request->user();
        if(!$user || ! in_array($user->role, $roles, true)) {
            abort(403, 'ليس لديك صلاحية');
        }
        return $next($request);
    }
}