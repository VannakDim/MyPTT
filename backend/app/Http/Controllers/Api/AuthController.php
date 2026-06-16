<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function login(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
            'password' => 'required',
            'device_name' => 'required', // ឧទាហរណ៍៖ Android, Web
        ]);

        $user = User::where('email', $request->email)->first();

        // ផ្ទៀងផ្ទាត់ Password
        if (! $user || ! Hash::check($request->password, $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['ព័ត៌មានឡុកអ៊ិនមិនត្រឹមត្រូវឡើយ។'],
            ]);
        }

        // បង្កើត Token របស់ Sanctum ផ្ដល់ឱ្យទៅ Client
        $token = $user->createToken($request->device_name)->plainTextToken;

        return response()->json([
            'status' => 'success',
            'user' => $user,
            'token' => $token // នេះគឺជា Token ដែលយើងត្រូវយកទៅប្រើ!
        ]);
    }
}