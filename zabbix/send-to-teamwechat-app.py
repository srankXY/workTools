#!/usr/bin/env python
# -*- coding: utf-8 -*-
# author: yang
# date: 2018-04-20
# comment: zabbix接入微信报警脚本(自建应用方式)
# 官方api：https://work.weixin.qq.com/api/doc/90000/90135/90248（可发送应用消息，群里消息，webhook等，但只有应用消息能在微信提示）

import requests
import sys
import json
# import os
# import logging

corpid = 'wwce1dba62063e9a03'
appsecret = '4gpdmqY9BI43wDvH1QutH4UfuNkkV4jQKHI2xT6WFx8'
agentid = 1000002

Touser = sys.argv[1]
Subject = sys.argv[2]
Message = sys.argv[3]

# 日志记录
# logging.basicConfig(level=logging.DEBUG,
#                     format='%(asctime)s, %(filename)s, %(levelname)s, %(message)s',
#                     datefmt='%a, %d %b %Y %H:%M:%S',
#                     filename=os.path.join('/etc/zabbix/', 'weixin.log'),
#                     filemode='a')

# 获取accesstoken
token_url = 'https://qyapi.weixin.qq.com/cgi-bin/gettoken?corpid=' + corpid + '&corpsecret=' + appsecret
req = requests.get(token_url)
accesstoken = req.json()['access_token']

# 发送消息
msgsend_url = 'https://qyapi.weixin.qq.com/cgi-bin/message/send?access_token=' + accesstoken

params = {
        "touser": Touser,
        "toparty": "2",    # 企业号中的部门id（第一个部门为1，第二个部门为2，以此类推）
        "msgtype": "markdown",
        "agentid": agentid,
        "markdown": {
                "content": '''实时新增用户反馈<font color=\"warning\">132例</font>，请相关同事注意。\n
                            >类型:<font color=\"comment\">用户反馈</font>
                            >普通用户反馈:<font color=\"comment\">117例</font>
                            >VIP用户反馈:<font color=\"comment\">15例</font>'''
        },
        "safe": 0
}
req = requests.post(msgsend_url, data=json.dumps(params))   # 直接推送消息
print(req.content)


# create_group={
#     "name" : "报警通知群",
#     # "owner" : "userid1",
#     "userlist" : ["YiGeShaZi", "YangXiLin"],
#     "chatid" : "wujidian00113322"
# }

# to_chatid={
#     "chatid": "wujidian00113322",
#     "msgtype":"text",
#     "text":{
#         "content" : "你的快递已到\n请携带工卡前往邮件中心领取"
#     },
#     "safe":0
# }

# req = requests.post('https://qyapi.weixin.qq.com/cgi-bin/appchat/create?access_token=' + accesstoken, data=json.dumps(create_group))
# req = requests.post('https://qyapi.weixin.qq.com/cgi-bin/appchat/send?access_token=' + accesstoken, data=json.dumps(to_chatid))
