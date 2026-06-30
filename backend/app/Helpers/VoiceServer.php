<?php

namespace App\Helpers;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class VoiceServer
{
    /**
     * Broadcast an event payload to the FastAPI voice server.
     *
     * @param array $payload
     * @return void
     */
    public static function broadcast(array $payload)
    {
        $secret = env('VOICE_SERVER_SECRET', 'myptt_super_secret_key');
        
        // We use the docker container name 'voice-server' inside the docker network
        $baseUrl = env('VOICE_SERVER_INTERNAL_URL', 'http://voice-server:9000');
        $url = rtrim($baseUrl, '/') . '/api/broadcast?secret=' . urlencode($secret);

        try {
            $response = Http::timeout(3)->post($url, $payload);
            if (!$response->successful()) {
                Log::warning('[VoiceServer Broadcast] Failed to send notification: Code ' . $response->status());
            }
        } catch (\Exception $e) {
            Log::error('[VoiceServer Broadcast] Error: ' . $e->getMessage());
        }
    }
}
