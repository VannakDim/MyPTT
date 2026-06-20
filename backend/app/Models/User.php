<?php

namespace App\Models;

// 1. ប្រាកដថាមានការ Import ថ្នាក់ (Class) នេះនៅខាងលើ
use Laravel\Sanctum\HasApiTokens;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

class User extends Authenticatable
{
    // 2. ថែម HasApiTokens ចូលទៅក្នុងបន្ទាត់ use ខាងក្រោមនេះ
    use HasApiTokens, HasFactory, Notifiable;

    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'name',
        'email',
        'password',
        'role',
        'avatar',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var array<int, string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected $casts = [
        'email_verified_at' => 'datetime',
        'password' => 'hashed', // សម្រាប់ Laravel 10/11/12
    ];

    # បន្ថែមមុខងារនេះទៅក្នុង Model User ដែលមានស្រាប់របស់អ្នក
    public function groups()
    {
        return $this->belongsToMany(Group::class);
    }
}
