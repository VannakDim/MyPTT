from fastapi import WebSocket
import json

class ChannelManager:
    def __init__(self):
        # ទម្រង់ទិន្នន័យ៖ { "បន្ទប់": {"users": {websocket_obj: username}, "speaker": None} }
        self.channels = {}

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
        if channel not in self.channels:
            self.channels[channel] = {"users": {}, "speaker": None}
        self.channels[channel]["users"][websocket] = username
        await self.update_user_count(channel)

    async def disconnect(self, channel: str, websocket: WebSocket):
        """ 🟢 មុខងារកែសម្រួលថ្មី៖ ដោះស្រាយបញ្ហា Logout ហើយចំនួនសមាជិកមិនព្រមថយចុះ """
        if channel in self.channels:
            # ១. លុប WebSocket client ដែលដាច់ការភ្ជាប់ចេញពីបន្ទប់
            if websocket in self.channels[channel]["users"]:
                del self.channels[channel]["users"][websocket]

            # ២. បើគាត់ជាអ្នកកំពុងនិយាយ PTT ត្រូវលែងសោរ PTT វិញ
            if self.channels[channel]["speaker"] == websocket:
                self.channels[channel]["speaker"] = None

            # ៣. បើគ្មានមនុស្សសល់ក្នុងបន្ទប់ទាល់តែសោះ លុបបន្ទប់នោះចោល
            if len(self.channels[channel]["users"]) == 0:
                del self.channels[channel]
            else:
                # ផ្ញើចំនួន និងបញ្ជីឈ្មោះថ្មីទៅកាន់អ្នកដែលនៅសល់ភ្លាមៗ
                await self.update_user_count(channel)

    async def request_ptt(self, channel: str, websocket: WebSocket) -> bool:
        if channel in self.channels and self.channels[channel]["speaker"] is None:
            self.channels[channel]["speaker"] = websocket
            return True
        return False

    async def release_ptt(self, channel: str, websocket: WebSocket) -> bool:
        if channel in self.channels and self.channels[channel]["speaker"] == websocket:
            self.channels[channel]["speaker"] = None
            return True
        return False

    async def broadcast_audio(self, channel: str, sender_ws: WebSocket, audio_bytes: bytes):
        if channel in self.channels:
            is_ptt_speaker = self.channels[channel]["speaker"] == sender_ws
            is_line_free = self.channels[channel]["speaker"] is None
            
            if is_ptt_speaker or is_line_free:
                for user_ws in self.channels[channel]["users"].keys():
                    if user_ws != sender_ws:
                        try:
                            await user_ws.send_bytes(audio_bytes)
                        except Exception:
                            pass

    async def broadcast_text(self, channel: str, data_dict: dict):
        if channel in self.channels:
            for user_ws in self.channels[channel]["users"].keys():
                try:
                    await user_ws.send_text(json.dumps(data_dict))
                except Exception:
                    pass

    async def send_to_user(self, channel: str, target_username: str, data_dict: dict):
        """ ផ្ញើសារចំគោលដៅទៅកាន់ User ម្នាក់ជាក់លាក់ (មិនខ្វល់រឿងអក្សរធំ-តូច) """
        if channel in self.channels:
            for user_ws, name in self.channels[channel]["users"].items():
                if str(name).lower() == str(target_username).lower():
                    try:
                        await user_ws.send_text(json.dumps(data_dict))
                    except Exception:
                        pass