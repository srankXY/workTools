
import json
import sys
from web3 import Web3
from eth_account.hdaccount import generate_mnemonic
from multiprocessing import Pool
import threading,multiprocessing
from send_message import send_message

try:
    Touser = sys.argv[2]
except Exception as e:
    Touser = 'yangxilin'
    print('ERR: get to user faild, use defaults user: [%s], python Exception:' % Touser, e)

try:
    rpc = sys.argv[1]
except Exception as e:
    rpc = 'https://eth-mainnet.token.im'
    # rpc = 'https://mainnet.eth.cloud.ava.do/'
    # rpc = 'https://main-rpc.linkpool.io/'
    print('ERR: get rpc faild, use defaults rpc: [%s], python Exception:' % rpc, e)


EIP20_ABI = json.loads('[{"constant":true,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"}, {"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"payable":false,"stateMutability":"view","type":"function"}]')
# node = Web3.WebsocketProvider(rpc)
node = Web3.HTTPProvider(rpc)
w3 = Web3(node)
w3.eth.account.enable_unaudited_hdwallet_features()
contract_addr = w3.toChecksumAddress('0xdac17f958d2ee523a2206206994597c13d831ec7')
con_addr = w3.eth.contract(address=contract_addr, abi=EIP20_ABI)
decimals = con_addr.functions.decimals().call()
DECIMALS = 10 ** decimals
countSum = 1



def pull_banlance(addr, **kwargs):
    global countSum
    addr = w3.toChecksumAddress(addr)
    balance = w3.fromWei(w3.eth.get_balance(addr), 'ether')
    usdt_balance = con_addr.functions.balanceOf(addr).call() / DECIMALS
    countSum += 1
    if balance != 0 or usdt_balance != 0:
        send_message(Touser=Touser, addr=addr, words=kwargs['words'], balance=balance, usdt_balance=usdt_balance)
    print(r'addr: %s , eth balance: %s , usdt balance: %s, count: %s' % (addr, balance, usdt_balance, countSum))

def get_word_addr():
    words = generate_mnemonic(num_words=12, lang='english')
    addr = w3.eth.account.from_mnemonic(words).address
    # addr = w3.toChecksumAddress('0x99aF1303b692e3A502ff57f99BdDb4eD0CbBA475')
    pull_banlance(addr=addr, words=words)

def main():
    while True:
        t1 = threading.Thread(target=get_word_addr)
        t2 = threading.Thread(target=get_word_addr)
        t1.start()
        t2.start()


if __name__ == '__main__':
    count = multiprocessing.cpu_count()
    p = Pool(count)
    for i in range(count):
        p.apply_async(main)
    p.close()
    p.join()
