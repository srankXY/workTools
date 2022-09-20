#!/usr/bin/python3

import requests
import subprocess
import sys
import json

def check_version():
    req = requests.get('https://api.github.com/repos/paritytech/polkadot/releases/latest')

    latest_version = req.json()["tag_name"].strip('v')

    data = {"jsonrpc": "2.0", "method": "system_version", "id": 1}
    headers = {"Content-Type": "application/json"}
    local_req = requests.post(url='http://127.0.0.1:9933', data=json.dumps(data), headers=headers)
    current_res = local_req.json()['result'].split('-')[0:-4]
    if len(current_res) == 1:
        current_version = current_res[0]
    else:
        current_version = '-'.join(current_res)

    # current_version = subprocess.Popen("%spolkadot --version | awk -F '[ -]' '{printf $2}'" % workdir, shell=True, stdout=subprocess.PIPE,stderr=subprocess.STDOUT).stdout.read().decode('utf8').strip('\r\n')
    if latest_version != current_version:
        return 'faild, latest version is: %s' % latest_version
    return current_version

def check_process():
    count = subprocess.Popen("ps -ef| grep -Ev 'grep|python|zabbix' | grep -c polkadot", shell=True, stdout=subprocess.PIPE,stderr=subprocess.STDOUT).stdout.read().decode('utf8').strip('\r\n')
    return count

def check_blkNum():
    online_req = requests.post(url=url)
    online_blkNum = online_req.json()['data']['blockNum']

    data = {"jsonrpc": "2.0", "method": "chain_getHeader", "id": 1}
    headers = {"Content-Type": "application/json"}
    local_req = requests.post(url='http://127.0.0.1:9933', data=json.dumps(data), headers=headers)
    local_blkNum = int(local_req.json()['result']['number'].split('x')[1], 16)
    if int(online_blkNum) - int(local_blkNum) > 1000:
        return 'faild, latest blkNum is: %s' % online_blkNum
    return local_blkNum


if __name__ == '__main__':
    if sys.argv[2] == 'polkadot':
        workdir = '/home/gch/polkadot-home/bin/'
        url = 'https://polkadot.api.subscan.io/api/scan/metadata'
    elif sys.argv[2] == 'kusama':
        workdir = '/home/ksm/kusama-home/'
        url = 'https://kusama.api.subscan.io/api/scan/metadata'

    if sys.argv[1] == 'check_version':
        '''版本不一致返回faild'''
        print(check_version())
    elif sys.argv[1] == 'check_process':
        '''进程存在返回1'''
        print(check_process())
    elif sys.argv[1] == 'check_blkNum':
        '''高度相差大于1000，返回faild'''
        print(check_blkNum())