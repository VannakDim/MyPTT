<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Message;
use App\Models\Group;
use App\Models\User;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class MessageController extends Controller
{
    /**
     * 1. API for creating/saving messages (supporting voice / files / text).
     * Accessible by authenticated users or internal FastAPI voice-server with shared secret.
     */
    public function store(Request $request)
    {
        $isAuth = false;
        $senderUser = null;

        // Verify if authenticated via Sanctum
        if (auth()->guard('sanctum')->check()) {
            $senderUser = auth()->guard('sanctum')->user();
            $isAuth = true;
        } else {
            // Verify if authenticated via Voice Server Secret
            $secret = $request->header('X-Voice-Server-Secret');
            $expectedSecret = env('VOICE_SERVER_SECRET', 'myptt_super_secret_key');
            if ($secret && $secret === $expectedSecret) {
                $isAuth = true;
            }
        }

        if (!$isAuth) {
            return response()->json(['message' => 'Unauthorized'], 401);
        }

        // Validate request
        $request->validate([
            'channel_name' => 'required|string',
            'sender_name' => 'required|string',
            'type' => 'required|string|in:chat,file,voice,system',
            'text' => 'nullable|string',
            'file_name' => 'nullable|string',
            'file_type' => 'nullable|string',
            'file_data' => 'nullable|string', // Base64 data url
        ]);

        // Find the group (channel_name corresponds to group name)
        $group = Group::where('name', $request->channel_name)->first();
        if (!$group) {
            return response()->json(['message' => 'Group not found'], 404);
        }

        // Resolve sender user if we don't have it yet
        if (!$senderUser) {
            $senderUser = User::where('name', $request->sender_name)->first();
        }

        $filePath = null;
        if ($request->filled('file_data')) {
            $base64Data = $request->file_data;

            // Extract the base64 content
            if (preg_match('/^data:([^;]+);base64,(.*)$/', $base64Data, $matches)) {
                $fileType = $matches[1];
                $data = base64_decode($matches[2]);

                $extension = 'bin';
                if ($request->filled('file_name')) {
                    $extension = pathinfo($request->file_name, PATHINFO_EXTENSION);
                } else {
                    $mimeMap = [
                        'image/jpeg' => 'jpg',
                        'image/jpg' => 'jpg',
                        'image/png' => 'png',
                        'image/gif' => 'gif',
                        'image/webp' => 'webp',
                        'audio/wav' => 'wav',
                        'audio/wave' => 'wav',
                        'audio/x-wav' => 'wav',
                        'audio/mpeg' => 'mp3',
                        'application/pdf' => 'pdf',
                    ];
                    $extension = $mimeMap[$fileType] ?? 'bin';
                }

                $safeName = Str::random(40) . '.' . $extension;

                // Save to public storage directory (storage/app/public/uploads/)
                Storage::disk('public')->put('uploads/' . $safeName, $data);

                // Set public URL path
                $filePath = '/storage/uploads/' . $safeName;
            }
        }

        // Save message to database
        $message = Message::create([
            'group_id' => $group->id,
            'sender_id' => $senderUser ? $senderUser->id : null,
            'sender_name' => $request->sender_name,
            'type' => $request->type,
            'text' => $request->text,
            'file_path' => $filePath,
            'file_name' => $request->file_name,
            'file_type' => $request->file_type ?? $request->header('Content-Type'),
        ]);

        return response()->json($message, 201);
    }

    /**
     * 2. API for fetching message history for a group.
     */
    public function index(Request $request, $groupId)
    {
        $group = Group::find($groupId);
        if (!$group) {
            return response()->json(['message' => 'Group not found'], 404);
        }

        $query = Message::where('group_id', $groupId);

        if ($request->has('before_id')) {
            $query->where('id', '<', $request->query('before_id'));
        }

        // Get the latest 15 messages (by descending ID)
        $messages = $query->with(['sender' => function ($query) {
                $query->select('id', 'name', 'avatar');
            }])
            ->orderBy('id', 'desc')
            ->limit(15)
            ->get();

        // Return reversed to order chronologically (oldest to newest)
        return response()->json($messages->reverse()->values());
    }

    /**
     * 3. API for deleting one's own message.
     */
    public function destroy($id)
    {
        $message = Message::findOrFail($id);

        // Ensure the logged in user is the sender of the message
        if (auth()->id() !== $message->sender_id) {
            return response()->json(['message' => 'Unauthorized to delete this message'], 403);
        }

        // If it is a voice/file message and has a filePath, delete it from storage
        if ($message->file_path) {
            // Replace "/storage/" prefix with "" to delete via Storage disk
            $storagePath = str_replace('/storage/', '', $message->file_path);
            if (Storage::disk('public')->exists($storagePath)) {
                Storage::disk('public')->delete($storagePath);
            }
        }

        $message->delete();

        return response()->json(['message' => 'Message deleted successfully']);
    }
}

