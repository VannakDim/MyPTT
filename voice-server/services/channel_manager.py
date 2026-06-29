from fastapi import WebSocket
import json
import asyncio

def get_device_info(user_agent: str) -> str:
    if not user_agent:
        return "ឧបករណ៍មិនស្គាល់"
    ua = user_agent.lower()
    if "android" in ua:
        return "ទូរស័ព្ទ Android"
    elif "iphone" in ua or "ipad" in ua:
        return "ទូរស័ព្ទ iPhone/iPad"
    elif "macintosh" in ua:
        return "ម៉ាស៊ីន Mac"
    elif "windows" in ua:
        return "កុំព្យូទ័រ Windows"
    elif "linux" in ua:
        return "កុំព្យូទ័រ Linux"
    else:
        return "កម្មវិធីរុករកបណ្ដាញ (Web Browser)"

class ChannelManager:
    def __init__(self):
        # ទម្រង់ទិន្នន័យ៖ { "បន្ទប់": {"users": {websocket_obj: username}, "speaker": None} }
        self.channels = {}
        self.active_calls = set()

    def register_call(self, user1: str, user2: str):
        self.active_calls.add(user1.lower())
        self.active_calls.add(user2.lower())

    def unregister_call(self, user1: str, user2: str):
        self.active_calls.discard(user1.lower())
        self.active_calls.discard(user2.lower())

    def is_user_in_call(self, username: str) -> bool:
        return username.lower() in self.active_calls

    async def update_user_count(self, channel: str):
        """ ផ្ញើចំនួនសមាជិកបច្ចុប្បន្ន និងបញ្ជីឈ្មោះទៅកាន់គ្រប់ Client ទាំងអស់ក្នុងបន្ទប់ """
        if channel in self.channels:
            unique_usernames = list(set(self.channels[channel]["users"].values()))
            payload = {
                "type": "user_count",
                "count": len(unique_usernames),
                "user_list": unique_usernames
            }
            for user_ws in self.channels[channel]["users"].keys():
                try:
                    await user_ws.send_text(json.dumps(payload))
                except Exception:
                    pass

    async def connect(self, channel: str, websocket: WebSocket, username: str):
        # --- ពិនិត្យរកការតភ្ជាប់ចាស់ជាមួយ Username ដូចគ្នា (គ្រប់បន្ទប់ទាំងអស់) ---
        new_ua = websocket.headers.get("user-agent", "")
        new_device = get_device_info(new_ua)
        
        for ch in list(self.channels.keys()):
            users_dict = self.channels[ch]["users"]
            for ws_conn, name in list(users_dict.items()):
                if name.lower() == username.lower() and ws_conn != websocket:
                    # ផ្ញើសារប្រាប់ឧបករណ៍ចាស់
                    try:
                        await ws_conn.send_text(json.dumps({
                            "type": "force_logout",
                            "reason": "logged_in_elsewhere",
                            "new_device": new_device,
                            "message": f"គណនីរបស់អ្នកត្រូវបានចូលប្រើប្រាស់នៅលើឧបករណ៍ផ្សេងទៀត ({new_device})។"
                        }))
                        await ws_conn.close(code=4009)
                    except Exception:
                        pass
                    # លុបចេញពីចង្កោមចាស់ភ្លាម
                    if ws_conn in users_dict:
                        del users_dict[ws_conn]
                    await self.update_user_count(ch)

        if channel not in self.channels:
            self.channels[channel] = {
                "users": {},
                "speaker": None,
                "speaker_username": None,
                "audio_buffer": bytearray()
            }
        self.channels[channel]["users"][websocket] = username
        await self.update_user_count(channel)

    async def disconnect(self, channel: str, websocket: WebSocket) -> dict:
        """ 🟢 មុខងារកែសម្រួលថ្មី៖ ដោះស្រាយបញ្ហា Logout ហើយចំនួនសមាជិកមិនព្រមថយចុះ """
        res = None
        if channel in self.channels:
            username = self.channels[channel]["users"].get(websocket)
            if username:
                self.active_calls.discard(username.lower())

            # ១. លុប WebSocket client ដែលដាច់ការភ្ជាប់ចេញពីបន្ទប់
            if websocket in self.channels[channel]["users"]:
                del self.channels[channel]["users"][websocket]

            # ២. បើគាត់ជាអ្នកកំពុងនិយាយ PTT ត្រូវលែងសោរ PTT វិញ
            if self.channels[channel]["speaker"] == websocket:
                audio_bytes = bytes(self.channels[channel].get("audio_buffer", b""))
                speaker = self.channels[channel].get("speaker_username", "User")
                res = {"audio_bytes": audio_bytes, "speaker": speaker}

                self.channels[channel]["speaker"] = None
                self.channels[channel]["speaker_username"] = None
                self.channels[channel]["audio_buffer"] = bytearray()

            # ៣. បើគ្មានមនុស្សសល់ក្នុងបន្ទប់ទាល់តែសោះ លុបបន្ទប់នោះចោល
            if len(self.channels[channel]["users"]) == 0:
                del self.channels[channel]
            else:
                # ផ្ញើចំនួន និងបញ្ជីឈ្មោះថ្មីទៅកាន់អ្នកដែលនៅសល់ភ្លាមៗ
                await self.update_user_count(channel)
        return res

    async def request_ptt(self, channel: str, websocket: WebSocket, username: str) -> bool:
        if channel in self.channels and self.channels[channel]["speaker"] is None:
            self.channels[channel]["speaker"] = websocket
            self.channels[channel]["speaker_username"] = username
            self.channels[channel]["audio_buffer"] = bytearray()
            return True
        return False

    async def release_ptt(self, channel: str, websocket: WebSocket) -> dict:
        if channel in self.channels and self.channels[channel]["speaker"] == websocket:
            self.channels[channel]["speaker"] = None
            audio_bytes = bytes(self.channels[channel].get("audio_buffer", b""))
            speaker = self.channels[channel].get("speaker_username", "User")
            
            # Reset
            self.channels[channel]["speaker_username"] = None
            self.channels[channel]["audio_buffer"] = bytearray()
            return {"audio_bytes": audio_bytes, "speaker": speaker}
        return None

    async def broadcast_audio(self, channel: str, sender_ws: WebSocket, audio_bytes: bytes):
        if channel in self.channels:
            is_ptt_speaker = self.channels[channel]["speaker"] == sender_ws
            is_line_free = self.channels[channel]["speaker"] is None
            
            if is_ptt_speaker or is_line_free:
                # Accumulate audio bytes if we have a buffer
                if is_ptt_speaker and "audio_buffer" in self.channels[channel]:
                    self.channels[channel]["audio_buffer"].extend(audio_bytes)

                async def safe_send(ws):
                    try:
                        await ws.send_bytes(audio_bytes)
                    except Exception:
                        pass

                for user_ws, name in self.channels[channel]["users"].items():
                    if user_ws != sender_ws and not self.is_user_in_call(name):
                        asyncio.create_task(safe_send(user_ws))

    async def broadcast_text(self, channel: str, data_dict: dict):
        if channel in self.channels:
            async def safe_send(ws):
                try:
                    await ws.send_text(json.dumps(data_dict))
                except Exception:
                    pass

            for user_ws in self.channels[channel]["users"].keys():
                asyncio.create_task(safe_send(user_ws))

    async def send_audio_to_user(self, channel: str, target_username: str, audio_bytes: bytes):
        """ ផ្ញើកញ្ចប់សំឡេងចំគោលដៅទៅកាន់ User ម្នាក់ (private call audio – មិន broadcast) """
        if channel in self.channels:
            async def safe_send(ws):
                try:
                    await ws.send_bytes(audio_bytes)
                except Exception:
                    pass

            for user_ws, name in self.channels[channel]["users"].items():
                if str(name).lower() == str(target_username).lower():
                    asyncio.create_task(safe_send(user_ws))

    async def send_to_user(self, channel: str, target_username: str, data_dict: dict):
        """ ផ្ញើសារចំគោលដៅទៅកាន់ User ម្នាក់ជាក់លាក់ (មិនខ្វល់រឿងអក្សរធំ-តូច) """
        if channel in self.channels:
            async def safe_send(ws):
                try:
                    await ws.send_text(json.dumps(data_dict))
                except Exception:
                    pass

            for user_ws, name in self.channels[channel]["users"].items():
                if str(name).lower() == str(target_username).lower():
                    asyncio.create_task(safe_send(user_ws))