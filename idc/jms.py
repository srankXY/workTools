#!/usr/bin/env python3
# -*- coding:utf-8 -*-

import sys, requests

class HTTP:
    server = None
    token  = None

    @classmethod
    def get_token(cls, username, password):
        data              = {'username': username, 'password': password}
        url               = "/api/v1/authentication/auth/"
        res               = requests.post(cls.server + url, data)
        res_data          = res.json()
        if res.status_code in [200, 201] and res_data:
            token         = res_data.get('token')
            cls.token     = token
        else:
            print("获取 token 错误, 请检查输入项是否正确")
            sys.exit()

    @classmethod
    def get(cls, url, params=None, **kwargs):
        url               = cls.server + url
        headers           = {
            'Authorization': "Bearer {}".format(cls.token),
            'X-JMS-ORG': '00000000-0000-0000-0000-000000000002'
        }
        kwargs['headers'] = headers
        res               = requests.get(url, params, **kwargs)
        return res

    @classmethod
    def post(cls, url, data=None, json=None, **kwargs):
        url               = cls.server + url
        headers           = {
            'Authorization': "Bearer {}".format(cls.token),
            'X-JMS-ORG': '00000000-0000-0000-0000-000000000002'
        }
        kwargs['headers'] = headers
        res               = requests.post(url, data, json, **kwargs)
        return res


class Node(object):

    def __init__(self):
        self.id           = None
        self.name         = asset_node_name

    def exist(self):
        url               = '/api/v1/assets/nodes/'
        params            = {'value': self.name}
        res               = HTTP.get(url, params=params)
        res_data          = res.json()
        if res.status_code in [200, 201] and res_data:
            self.id       = res_data[0].get('id')
        else:
            self.create()

    def create(self):
        print("创建资产节点 {}".format(self.name))
        url               = '/api/v1/assets/nodes/'
        data              = {
            'value': self.name
        }
        res               = HTTP.post(url, json=data)
        self.id           = res.json().get('id')

    def perform(self):
        self.exist()


class Asset(object):

    def __init__(self):
        self.id           = None
        self.name         = asset_name
        self.ip           = asset_ip
        self.platform     = asset_platform
        self.protocols    = asset_protocols
        self.admin_user   = asset_admin_name
        self.public_ip    = asset_public_ip
        self.comment      = asset_comment
        self.node         = Node()

    def getAdminUserId(self):
        url = '/api/v1/assets/admin-user/'
        params = {'username': self.admin_user}
        res = HTTP.get(url, params=params)
        res_data = res.json()
        if res.status_code in [200, 201] and res_data:
            self.admin_user_id = res_data[0].get('id')
        else:
            exit(1)

    def exist(self):
        url               = '/api/v1/assets/assets/'
        params            = {
            'hostname': self.name
        }
        res               = HTTP.get(url, params)
        res_data          = res.json()
        if res.status_code in [200, 201] and res_data:
            self.id       = res_data[0].get('id')
        else:
            self.create()

    def create(self):
        print("创建资产 {}".format(self.ip))
        self.node.perform()
        self.getAdminUserId()
        url               = '/api/v1/assets/assets/'
        data              = {
            'hostname': self.name,
            'ip': self.ip,
            'platform': self.platform,
            'protocols': self.protocols,
            'admin_user': self.admin_user_id,
            'nodes': [self.node.id],
            'is_active': True,
            'public_ip': self.public_ip,
            'comment': self.comment
        }
        res               = HTTP.post(url, json=data)
        self.id           = res.json().get('id')

    def perform(self):
        self.exist()

class main(object):

    def __init__(self):
        self.jms_url      = jms_url
        self.username     = jms_username
        self.password     = jms_password
        self.token        = None
        self.server       = None

    def init_http(self):
        HTTP.server       = self.jms_url
        HTTP.get_token(self.username, self.password)

    def perform(self):
        self.init_http()
        self.addAsset         = Asset()
        self.addAsset.perform()


if __name__ == '__main__':

    # jumpserver url 地址
    jms_url                = 'http://172.31.1.2'

    # 管理员账户
    jms_username           = sys.argv[4]+'Host'
    jms_password           = sys.argv[5]+"^D5FEp3l"

    # 资产节点
    asset_node_name        = '雅安'

    # 资产信息
    '''
    参数1为：服务器名称
    参数2为：服务器内网ip
    参数3为：服务器公网ip
    '''
    asset_name             = sys.argv[1]
    asset_ip               = sys.argv[2]
    asset_platform         = 'Linux'
    asset_protocols        = ['ssh/22']
    asset_comment          = sys.argv[1]
    asset_public_ip       = sys.argv[3]

    # 资产管理用户
    asset_admin_name      = 'root'
    # assets_admin_username  = 'root'

    api = main()
    api.perform()