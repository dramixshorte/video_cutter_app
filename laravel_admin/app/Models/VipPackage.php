<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\RecordsActivity;

class VipPackage extends Model
{
    use HasFactory, RecordsActivity;

    protected $fillable = [ 'name','days','price','is_active','app_id' ];

    protected $casts = [ 'is_active' => 'boolean' ];
}
<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class VipPackage extends Model
{
    use HasFactory;

    protected $fillable = [ 'name','days','price','is_active','app_id' ];

    protected $casts = [ 'is_active' => 'boolean' ];
}