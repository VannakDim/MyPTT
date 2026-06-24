from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Query
from services.channel_manager import ChannelManager
from services.auth_service import verify_jwt_token 
import json
import os
import time
import base64
import asyncio
import requests

app = FastAPI()

@app.get("/")
async def root():
    return {
        "status": "online",
        "service": "MyPTT Voice Server"
    }

manager = ChannelManager()

# --- WAV Header helper ---
def create_wav_header(pcm_data_len: int, sample_rate: int = 16000, bits_per_sample: int = 16, num_channels: int = 1) -> bytes:
    header = bytearray()
    header.extend(b'RIFF')
    file_size = 36 + pcm_data_len
    header.extend(file_size.to_bytes(4, 'little'))
    header.extend(b'WAVE')
    header.extend(b'fmt ')
    header.extend((16).to_bytes(4, 'little')) # chunk size
    header.extend((1).to_bytes(2, 'little'))  # audio format (1 = PCM)
    header.extend(num_channels.to_bytes(2, 'little'))
    header.extend(sample_rate.to_bytes(4, 'little'))
    byte_rate = sample_rate * num_channels * bits_per_sample // 8
    header.extend(byte_rate.to_bytes(4, 'little'))
    block_align = num_channels * bits_per_sample // 8
    header.extend(block_align.to_bytes(2, 'little'))
    header.extend(bits_per_sample.to_bytes(2, 'little'))
    header.extend(b'data')
    header.extend(pcm_data_len.to_bytes(4, 'little'))
    return bytes(header)

def save_message_to_laravel_sync(payload):
    laravel_url = "http://backend:8000/api/messages"
    headers = {
        "X-Voice-Server-Secret": os.getenv("VOICE_SERVER_SECRET", "myptt_super_secret_key"),
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    try:
        response = requests.post(laravel_url, json=payload, headers=headers, timeout=15)
        print(f"[Laravel Save] Status: {response.status_code}")
    except Exception as e:
        print(f"[Laravel Save Error] Failed: {e}")

def save_message_to_laravel(payload):
    asyncio.create_task(asyncio.to_thread(save_message_to_laravel_sync, payload))

def process_voice_message(channel_name, speaker, audio_bytes):
    if not audio_bytes or len(audio_bytes) < 16000:
        print(f"[Voice Skip] Too short: {len(audio_bytes) if audio_bytes else 0} bytes")
        return
        
    wav_header = create_wav_header(len(audio_bytes), sample_rate=16000, bits_per_sample=16, num_channels=1)
    full_wav = wav_header + audio_bytes
    
    base64_data = "data:audio/wav;base64," + base64.b64encode(full_wav).decode('utf-8')
    
    payload = {
        "channel_name": channel_name,
        "sender_name": speaker,
        "type": "voice",
        "file_name": f"voice_{channel_name}_{int(time.time())}.wav",
        "file_type": "audio/wav",
        "file_data": base64_data
    }
    save_message_to_laravel(payload)


@app.websocket("/ws/{channel}")
async def websocket_endpoint(websocket: WebSocket, channel: str, token: str = Query(None)):
    # បង្កើនទំហំផ្ទុកទិន្នន័យ (25MB) ការពារការដាច់ពេលផ្ញើ File រូបភាព
    websocket._max_size = 25 * 1024 * 1024 

    # --- ផ្នែកពិនិត្យ និងបកប្រែ Token ដើម្បីទាញយកឈ្មោះពិត (name) ពី Database ---
    user_info = verify_jwt_token(token)
    if not user_info:
        await websocket.accept()
        await websocket.close(code=4008)
        return
        
    # ចាប់យកឈ្មោះពិតពី Token (សសរស្ដម្ភ name)
    username = user_info.get("name", "User")

    await websocket.accept()
    await manager.connect(channel, websocket, username)
    await manager.broadcast_text(channel, {"type": "system", "message": f"🔔 {username} បានចូលក្នុងបន្ទប់"})

    try:
        while True:
            packet = await websocket.receive()
            
            # ទទួលកញ្ចប់សំឡេង (Binary)
            if "bytes" in packet:
                await manager.broadcast_audio(channel, websocket, packet["bytes"])
                
            # ទទួលកញ្ចប់បញ្ជា ឬសារ Chat (Text JSON)
            elif "text" in packet:
                data = json.loads(packet["text"])
                action = data.get("action")
                
                # --- ប្រព័ន្ធ PTT Walkie-Talkie ---
                if action == "ptt_start":
                    if await manager.request_ptt(channel, websocket, username):
                        await websocket.send_text(json.dumps({"type": "ptt_status", "status": "talking_granted"}))
                        await manager.broadcast_text(channel, {"type": "system", "message": f"🎙️ {username} កំពុងនិយាយ..."})
                    else:
                        await websocket.send_text(json.dumps({"type": "ptt_status", "status": "line_busy"}))
                        
                elif action == "ptt_stop":
                    ptt_res = await manager.release_ptt(channel, websocket)
                    if ptt_res:
                        await websocket.send_text(json.dumps({"type": "ptt_status", "status": "idle"}))
                        await manager.broadcast_text(channel, {"type": "system", "message": f"✅ ខ្សែទំនេរ"})
                        process_voice_message(channel, ptt_res["speaker"], ptt_res["audio_bytes"])
                
                # --- ប្រព័ន្ធ Chat ធម្មតា ---
                elif action == "chat_message":
                    chat_text = data.get("text")
                    await manager.broadcast_text(channel, {
                        "type": "chat",
                        "sender": username,
                        "text": chat_text
                    })
                    save_message_to_laravel({
                        "channel_name": channel,
                        "sender_name": username,
                        "type": "chat",
                        "text": chat_text
                    })

                # --- មុខងារផ្ញើ File ---
                elif action == "file_share":
                    file_name = data.get("file_name")
                    file_type = data.get("file_type")
                    file_data = data.get("file_data")
                    
                    await manager.broadcast_text(channel, {
                        "type": "file",
                        "sender": username,
                        "file_name": file_name,
                        "file_type": file_type,
                        "file_data": file_data
                    })
                    save_message_to_laravel({
                        "channel_name": channel,
                        "sender_name": username,
                        "type": "file",
                        "file_name": file_name,
                        "file_type": file_type,
                        "file_data": file_data
                    })

                # --- ប្រព័ន្ធ Call (WebRTC Signaling) ---
                elif action in ["call_user", "call_accepted", "call_rejected", "call_hungup"]:
                    target = data.get("target")
                    await manager.send_to_user(channel, target, {
                        "type": "call_signal",
                        "status": action,
                        "sender": username
                    })

                # --- WebRTC Group PTT Signaling Relay ---
                elif action == "webrtc_signal":
                    target = data.get("target")
                    payload = data.get("payload")
                    await manager.send_to_user(channel, target, {
                        "type": "webrtc_signal",
                        "sender": username,
                        "payload": payload
                    })

    except WebSocketDisconnect:
        disconnect_res = await manager.disconnect(channel, websocket)
        if disconnect_res:
            process_voice_message(channel, disconnect_res["speaker"], disconnect_res["audio_bytes"])
        await manager.broadcast_text(channel, {"type": "system", "message": f"🚶 {username} បានចាកចេញ"})
        
    except Exception as e:
        print(f"Error encountered: {e}")
        disconnect_res = await manager.disconnect(channel, websocket)
        if disconnect_res:
            process_voice_message(channel, disconnect_res["speaker"], disconnect_res["audio_bytes"])