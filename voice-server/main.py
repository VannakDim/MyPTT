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
    auth_url = os.getenv("LARAVEL_AUTH_URL", "http://localhost:8000/api/user")
    base_url = auth_url.split("/api/user")[0] if "/api/user" in auth_url else "http://localhost:8000"
    laravel_url = f"{base_url}/api/messages"
    headers = {
        "X-Voice-Server-Secret": os.getenv("VOICE_SERVER_SECRET", "myptt_super_secret_key"),
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    try:
        response = requests.post(laravel_url, json=payload, headers=headers, timeout=15)
        print(f"[Laravel Save] Status: {response.status_code}")
        if response.status_code in [200, 201]:
            return response.json()
    except Exception as e:
        print(f"[Laravel Save Error] Failed: {e}")
    return None

def save_message_to_laravel(payload):
    asyncio.create_task(asyncio.to_thread(save_message_to_laravel_sync, payload))

def save_message_seen_to_laravel_sync(payload):
    auth_url = os.getenv("LARAVEL_AUTH_URL", "http://localhost:8000/api/user")
    base_url = auth_url.split("/api/user")[0] if "/api/user" in auth_url else "http://localhost:8000"
    laravel_url = f"{base_url}/api/messages/seen"
    headers = {
        "X-Voice-Server-Secret": os.getenv("VOICE_SERVER_SECRET", "myptt_super_secret_key"),
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    try:
        response = requests.post(laravel_url, json=payload, headers=headers, timeout=10)
        print(f"[Laravel Save Seen] Status: {response.status_code}")
    except Exception as e:
        print(f"[Laravel Save Seen Error] Failed: {e}")

def save_message_seen_to_laravel(payload):
    asyncio.create_task(asyncio.to_thread(save_message_seen_to_laravel_sync, payload))

async def process_voice_message(channel_name, speaker, audio_bytes):
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
    
    # Save to Laravel and wait for the response to get file_path
    saved_msg = await asyncio.to_thread(save_message_to_laravel_sync, payload)
    
    file_path = None
    if saved_msg and isinstance(saved_msg, dict):
        file_path = saved_msg.get("file_path")
        
    # Broadcast the voice message to all WebSocket clients in the channel
    broadcast_data = {
        "type": "voice",
        "id": saved_msg.get("id") if saved_msg else None,
        "sender": speaker,
        "file_path": file_path,
        "file_name": payload["file_name"],
        "file_type": payload["file_type"],
        "file_data": base64_data,
        "created_at": saved_msg.get("created_at") if (saved_msg and saved_msg.get("created_at")) else None
    }
    await manager.broadcast_text(channel_name, broadcast_data)


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
        
    username = user_info.get("name", "User")
    user_id = user_info.get("id")

    await websocket.accept()
    await manager.connect(channel, websocket, username, user_id)
    await manager.broadcast_text(channel, {"type": "system", "message": f"🔔 {username} បានចូលក្នុងបន្ទប់"})

    disconnected = False  # ទង់សញ្ញាដើម្បីការពារ disconnect ពីរដង

    try:
        while True:
            packet = await websocket.receive()

            # ពិនិត្យ disconnect message ភ្លាមដោយផ្ទាល់ (type == "websocket.disconnect")
            if packet.get("type") == "websocket.disconnect":
                break

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
                        await manager.broadcast_text(channel, {
                            "type": "ptt_status",
                            "status": "busy",
                            "speaker": username
                        })
                    else:
                        await websocket.send_text(json.dumps({"type": "ptt_status", "status": "line_busy"}))
                        
                elif action == "ptt_stop":
                    ptt_res = await manager.release_ptt(channel, websocket)
                    if ptt_res:
                        await websocket.send_text(json.dumps({"type": "ptt_status", "status": "idle"}))
                        await manager.broadcast_text(channel, {"type": "system", "message": f"✅ ខ្សែទំនេរ"})
                        await manager.broadcast_text(channel, {
                            "type": "ptt_status",
                            "status": "idle"
                        })
                        await process_voice_message(channel, ptt_res["speaker"], ptt_res["audio_bytes"])
                elif action == "delete_message":
                    msg_id = data.get("id")
                    await manager.broadcast_text(channel, {
                        "type": "delete_message",
                        "id": msg_id
                    })
                
                # --- ប្រព័ន្ធ Chat ធម្មតា ---
                elif action == "chat_message":
                    chat_text = data.get("text")
                    reply_to_id = data.get("reply_to_id")
                    reply_to = data.get("reply_to")  # Full reply object from client

                    # Save to Laravel synchronously to get the message ID
                    save_payload = {
                        "channel_name": channel,
                        "sender_name": username,
                        "type": "chat",
                        "text": chat_text,
                    }
                    if reply_to_id:
                        save_payload["reply_to_id"] = reply_to_id

                    saved_msg = await asyncio.to_thread(save_message_to_laravel_sync, save_payload)

                    broadcast_payload = {
                        "type": "chat",
                        "id": saved_msg.get("id") if saved_msg else None,
                        "sender": username,
                        "text": chat_text,
                        "created_at": saved_msg.get("created_at") if saved_msg else None,
                    }
                    if reply_to_id:
                        broadcast_payload["reply_to_id"] = reply_to_id
                    if reply_to:
                        broadcast_payload["reply_to"] = reply_to

                    await manager.broadcast_text(channel, broadcast_payload)

                elif action == "message_seen":
                    message_ids = data.get("ids", [])
                    if message_ids:
                        save_payload = {
                            "message_ids": message_ids,
                            "user_id": user_id
                        }
                        save_message_seen_to_laravel(save_payload)
                        await manager.broadcast_text(channel, {
                            "type": "message_seen",
                            "message_ids": message_ids,
                            "username": username,
                            "user_id": user_id
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

                elif action == "file_share_completed":
                    msg_id = data.get("id")
                    file_name = data.get("file_name")
                    file_type = data.get("file_type")
                    file_path = data.get("file_path")
                    created_at = data.get("created_at")
                    
                    await manager.broadcast_text(channel, {
                        "type": "file",
                        "id": msg_id,
                        "sender": username,
                        "file_name": file_name,
                        "file_type": file_type,
                        "file_path": file_path,
                        "created_at": created_at
                    })

                # --- ប្រព័ន្ធ Call (WebRTC Signaling) ---
                elif action in ["call_user", "call_accepted", "call_rejected", "call_hungup"]:
                    target = data.get("target")
                    if action == "call_accepted":
                        manager.register_call(username, target)
                    elif action in ["call_rejected", "call_hungup"]:
                        manager.unregister_call(username, target)

                    await manager.send_to_user(channel, target, {
                        "type": "call_signal",
                        "status": action,
                        "sender": username
                    })

                # --- Private Call Audio (ផ្ញើសំឡេងទៅចំគោលដៅ – មិន broadcast ទៅ group) ---
                elif action == "call_audio":
                    target = data.get("target")
                    audio_b64 = data.get("audio")
                    if target and audio_b64:
                        import base64 as _b64
                        try:
                            raw_bytes = _b64.b64decode(audio_b64)
                            await manager.send_audio_to_user(channel, target, raw_bytes)
                        except Exception as e:
                            print(f"[call_audio] decode error: {e}")

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
        pass  # គ្រប់គ្រងក្នុង finally block

    except Exception as e:
        print(f"[WS Error] {username}: {e}")

    finally:
        # Cleanup ត្រូវតែដំណើរការតែម្ដងប៉ុណ្ណោះ (ការពារ double-disconnect)
        if not disconnected:
            disconnected = True
            disconnect_res = await manager.disconnect(channel, websocket)
            if disconnect_res:
                await process_voice_message(channel, disconnect_res["speaker"], disconnect_res["audio_bytes"])
            await manager.broadcast_text(channel, {"type": "system", "message": f"🚶 {username} បានចាកចេញ"})

@app.post("/api/broadcast")
async def broadcast_api(payload: dict, secret: str = Query(None)):
    expected_secret = os.getenv("VOICE_SERVER_SECRET", "myptt_super_secret_key")
    if secret != expected_secret:
        from fastapi import HTTPException
        raise HTTPException(status_code=401, detail="Unauthorized")
    
    await manager.broadcast_global(payload)
    return {"status": "broadcast_queued"}