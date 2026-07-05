"""
通用 CLI 客户端 — 与 CliBridge 框架配对的 Python SDK
===================================================

不绑定任何具体命令，仅提供 TCP JSON-line 通信能力。

用法::

    from cli_client import CliClient

    cli = CliClient(port=9999)

    # 看接口文档
    help_docs = cli.call('help')
    for cmd, info in help_docs.items():
        print(f"{cmd}: {info['params']}")

    # 发命令
    result = cli.call('add_bookmark', url='https://example.com', tags=['dev'])
    assert result['id'] is not None

    cli.shutdown()
"""

import json
import socket
from typing import Any

DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 9999
RECV_BUF = 65536


class CliError(Exception):
    """CLI 命令执行错误"""

    def __init__(self, message: str, data: Any = None):
        super().__init__(message)
        self.data = data


class CliClient:
    """通用 CLI TCP 客户端。"""

    def __init__(
        self,
        host: str = DEFAULT_HOST,
        port: int = DEFAULT_PORT,
        timeout: float = 10.0,
    ):
        self.host = host
        self.port = port
        self.timeout = timeout

    def _send(self, payload: dict) -> dict:
        """发送一条 JSON-line 命令并等待响应。"""
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(self.timeout)
            s.connect((self.host, self.port))
            s.sendall((json.dumps(payload, ensure_ascii=False) + "\n").encode())

            data = b""
            while b"\n" not in data:
                chunk = s.recv(RECV_BUF)
                if not chunk:
                    break
                data += chunk

        resp = json.loads(data.decode().strip())
        return resp

    def call(self, cmd: str, **params) -> dict:
        """
        发送命令并返回 data 字段。

        参数:
            cmd: 命令名字符串
            **params: 命令参数（键值对）

        返回:
            data 字段的内容（dict / list / None）

        异常:
            CliError: 当 status != "ok"
        """
        payload = {"cmd": cmd, **params}
        resp = self._send(payload)

        if resp.get("status") != "ok":
            raise CliError(
                resp.get("message", "unknown error"),
                data=resp.get("data"),
            )

        return resp.get("data")

    def help(self) -> dict:
        """获取所有已注册命令的接口文档。"""
        return self.call("help")

    def ping(self) -> dict:
        """健康检查（需要后端注册了 ping 命令）。"""
        return self.call("ping")

    def shutdown(self) -> dict:
        """发送关闭命令（需要后端注册了 shutdown 命令）。"""
        try:
            return self.call("shutdown")
        except (CliError, ConnectionError, OSError):
            return {}
