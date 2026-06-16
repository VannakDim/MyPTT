<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        // បង្កើត User គំរូមួយសម្រាប់សាកល្បង Login
        User::create(
        [
            'name' => 'User 02',
            'email' => 'test2@realptt.com',
            'password' => Hash::make('password123'), // Password សម្រាប់ Login
        ]);

        print("\n✅ User តេស្តត្រូវបានបង្កើតជោគជ័យ! (Email: test@realptt.com | Pass: password123)\n");
    }
}
