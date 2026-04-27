import logging
from typing import Optional

import aiohttp

from .config import RD_ACCESS_TOKEN, RD_API_BASE

logger = logging.getLogger(__name__)
RD_API_BASE = "https://api.real-debrid.com/rest/1.0"


class RealDebridClient:
    def __init__(self, token: Optional[str] = None):
        self.token = token or RD_ACCESS_TOKEN

    def _headers(self):
        return {"Authorization": f"Bearer {self.token}"}

    async def get(self, path: str, params: Optional[dict] = None):
        url = f"{RD_API_BASE}{path}"
        async with aiohttp.ClientSession() as session:
            async with session.get(url, headers=self._headers(), params=params) as resp:
                return await resp.json()

    async def post(self, path: str, data: Optional[dict] = None):
        url = f"{RD_API_BASE}{path}"
        async with aiohttp.ClientSession() as session:
            async with session.post(url, headers=self._headers(), data=data) as resp:
                return await resp.json()

    async def add_magnet(self, magnet: str):
        return await self.post("/torrents/addMagnet", {"magnet": magnet})

    async def get_torrent_info(self, torrent_id: str):
        return await self.get(f"/torrents/info/{torrent_id}")

    async def select_files(self, torrent_id: str, file_id: str = "all"):
        return await self.post(f"/torrents/selectFiles/{torrent_id}", {"files": file_id})

    async def unrestrict_link(self, link: str):
        return await self.post("/unrestrict/link", {"link": link})
