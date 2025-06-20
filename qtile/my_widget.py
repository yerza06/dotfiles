import iwlib
import requests
import socket


from libqtile.log_utils import logger
from libqtile.pangocffi import markup_escape_text
from libqtile.widget import base




class MyCustomWidget:
    def get_wifi_ip():
        try:
            # Создаем UDP-сокет
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            # Подключаемся к несуществующему хосту (нужно для определения IP)
            s.connect(("8.8.8.8", 80))
            # Получаем IP-адрес устройства
            ip_address = s.getsockname()[0]
            return ip_address
        except Exception as e:
            print(f"Ошибка: {e}")
            return None
        finally:
            s.close()


    def get_status(interface_name):
        interface = iwlib.get_iwconfig(interface_name)
        if "stats" not in interface:
            return None, None
        quality = interface["stats"]["quality"]
        essid = bytes(interface["ESSID"]).decode()
        return essid, quality


    def get_external_ip():
        try:
            # Обращение к публичному API для получения внешнего IP
            response = requests.get("https://api.ipify.org?format=json")
            if response.status_code == 200:
                return response.json()["ip"]
            else:
                print(f"Ошибка: статус {response.status_code}")
                return None
        except requests.RequestException as e:
            print(f"Ошибка запроса: {e}")
            return None




