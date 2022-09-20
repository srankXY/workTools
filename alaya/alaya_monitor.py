#!/usr/bin/python3
# https://api.alayascan.com/file/docs/#/home
import requests, json
import subprocess, sys

BaseUrl = 'https://api.alayascan.com'
headers = {"Content-Type": "application/json"}

def Get_BlkNum():
    ''' Get BlkNum of official rpc '''
    try:
        BlockNumReq = requests.post(url=BaseUrl+'/alaya-api/home/chainStatistic')
        CurrentBlk = BlockNumReq.json()['data']['currentNumber']
    except Exception:
        CurrentBlk = 0

    ''' Get BlkNum of local rpc '''
    data = {"jsonrpc":"2.0", "method":"platon_blockNumber","params":[],"id":67}
    local_req = requests.post(url='http://127.0.0.1:6789', data=json.dumps(data), headers=headers)
    local_blkNum = int(local_req.json()['result'].split('x')[1], 16)
    if int(CurrentBlk) - int(local_blkNum) > 1000:
        return 'faild, latest blkNum is: %s' % CurrentBlk
    return local_blkNum

def Get_Validator():
    data = {'nodeId': '0x95c3fbd07041e78483ccc11a598ceb6b7e9bde2dcae68b5a7c4ea6876a423801d1fadb0de79bdcf52376236bd4ce2c1131a1e2640bd26856c967e17415184924'}
    ValidatorReq =  requests.post(url=BaseUrl+'/alaya-api/staking/stakingDetails', data=json.dumps(data), headers=headers)
    ValidatorStatus = ValidatorReq.json()['data']['status']
    ValidatorName = ValidatorReq.json()['data']['nodeName']

    if ValidatorName != '168Node' or ValidatorStatus not in [1, 2, 3, 6]:
        return 'faild, 168node not is validator now (%s, %s)' % (ValidatorName, ValidatorStatus)
    return ValidatorName, ValidatorStatus

def Get_Process():
    count = subprocess.Popen("ps -ef| grep -Ev 'grep|python|zabbix' | grep -c alaya", shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT).stdout.read().decode('utf8').strip('\r\n')
    return count

def Get_Version():
    tags_req = requests.get(url='https://api.github.com/repos/AlayaNetwork/Alaya-Go/releases/latest')
    latest_version = tags_req.json()["tag_name"].strip('v')

    current_version = subprocess.Popen("alaya version | grep ^Version | awk -F '[ -]' '{print $2}'", shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT).stdout.read().decode('utf8').strip('\r\n')

    if latest_version != current_version:
        return 'faild, latest version is: %s' % latest_version
    return current_version

if __name__ == '__main__':
    workdir = '/home/aly/platon-node/'

    if sys.argv[1] == 'check_version':
        '''版本不一致返回faild'''
        print(Get_Version())
    elif sys.argv[1] == 'check_process':
        '''进程存在返回1'''
        print(Get_Process())
    elif sys.argv[1] == 'check_blkNum':
        '''高度相差大于1000，返回faild'''
        print(Get_BlkNum())
    elif sys.argv[1] == 'check_validator':
        '''掉出验证人返回faild'''
        print(Get_Validator())
