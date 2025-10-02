<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Facades\Hash;

class User extends Authenticatable
{
    use HasFactory, Notifiable;

    protected $fillable = ['name','email','password','role'];

    protected $hidden = ['password','remember_token'];

    public function setPassword(string $raw): void { $this->password = Hash::make($raw); }

    public function isRole(string|array $roles): bool {
        if(is_array($roles)) return in_array($this->role, $roles, true);
        return $this->role === $roles;
    }
}
