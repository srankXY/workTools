
# 企业微信官方机器人 webhook 形式
import requests
import json

url = 'https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=10eb3196-8ac5-4b77-a395-d6dcf33d043e'
headers = {'Content-Type': 'application/json'}

data = {
    "msgtype": "text",
    "text": {
        "content": "0000000000000000000000000000"
    }
}

req=requests.post(url=url, data=json.dumps(data), headers=headers)
print(req)
