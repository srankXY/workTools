#!/usr/bin/python3
# pip install aliyun-python-sdk-dyvmsapi
# api addr: https://help.aliyun.com/document_detail/147109.htm?spm=a2c4g.11186623.2.22.456a6fa1d1ioKH#concept-2362233

import sys
import time
import json

from aliyunsdkcore.client import AcsClient
from aliyunsdkdyvmsapi.request.v20170525.SingleCallByTtsRequest import SingleCallByTtsRequest


def Send_Vioce_To_Tts(tophone, subject, message, ttscode):
    # 模板文件通知
    data = {
        'subject': subject,
        'message': message
    }
    request = SingleCallByTtsRequest()
    request.set_accept_format('json')
    request.set_Speed(-500)
    # request.set_CalledShowNumber("18850505050")
    request.set_CalledNumber(tophone)
    request.set_TtsCode(ttscode)
    request.set_TtsParam(data)
    response = client.do_action_with_exception(request)
    print(response)
    return response

if __name__ == '__main__':

    # 删除电话列表中的引号并转换为list
    Tophones = sys.argv[1].strip("\'\"").split(",")
    Subject = sys.argv[2]

    # 替换ip地址中的.为点
    Message = sys.argv[3].replace(".", "点")
    TtsCode = ''
    accessKeyId = ''
    accessSecret = ''
    client = AcsClient(accessKeyId, accessSecret, 'cn-hangzhou')


    for phone in Tophones:
        reslut = False

        # 发送失败则一直发送
        while reslut != 'OK':
            response = Send_Vioce_To_Tts(phone, Subject, Message, TtsCode)
            reslut = json.loads(response)['Code']
            if reslut != 'OK':
                time.sleep(60)