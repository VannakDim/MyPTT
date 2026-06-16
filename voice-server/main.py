from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Query
from services.channel_manager import ChannelManager
from services.auth_service import verify_jwt_token
import json

app = FastAPI()
manager = ChannelManager()

@app.websocket("/ws/{channel}")
async def websocket_endpoint(websocket: WebSocket, channel: str, token: str = Query(None)):
    # បង្កើនទំហំផ្ទុកទិន្នន័យ (25MB) ការពារការដាច់ពេលផ្ញើ File រូបភាព
    websocket._max_size = 25 * 1024 * 1024 

    user_info = verify_jwt_token(token)
    if not user_info:
        await websocket.accept()
        await websocket.close(code=4008)
        return

    await websocket.accept()
    username = user_info.get("name", "User")
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
                    if await manager.request_ptt(channel, websocket):
                        await websocket.send_text(json.dumps({"type": "ptt_status", "status": "talking_granted"}))
                        await manager.broadcast_text(channel, {"type": "system", "message": f"🎙️ {username} កំពុងនិយាយ..."})
                    else:
                        await websocket.send_text(json.dumps({"type": "ptt_status", "status": "line_busy"}))
                        
                elif action == "ptt_stop":
                    if await manager.release_ptt(channel, websocket):
                        await websocket.send_text(json.dumps({"type": "ptt_status", "status": "idle"}))
                        await manager.broadcast_text(channel, {"type": "system", "message": f"✅ ខ្សែទំនេរ"})
                
                # --- ប្រព័ន្ធ Chat ធម្មតា ---
                elif action == "chat_message":
                    await manager.broadcast_text(channel, {
                        "type": "chat",
                        "sender": username,
                        "text": data.get("text")
                    })

                # --- មុខងារផ្ញើ File ---
                elif action == "file_share":
                    await manager.broadcast_text(channel, {
                        "type": "file",
                        "sender": username,
                        "file_name": data.get("file_name"),
                        "file_type": data.get("file_type"),
                        "file_data": data.get("file_data")
                    })

                # --- ប្រព័ន្ធ Call (WebRTC Signaling) ---
                elif action in ["call_user", "call_accepted", "call_rejected", "call_hungup"]:
                    target = data.get("target")
                    await manager.send_to_user(channel, target, {
                        "type": "call_signal",
                        "status": action,
                        "sender": username
                    })

    except WebSocketDisconnect:
        await manager.disconnect(channel, websocket)
        await manager.broadcast_text(channel, {"type": "system", "message": f"🚶 {username} បានចាកចេញ"})