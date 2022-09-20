#!/usr/bin/python3
import time

from srkSUB.base import SUB
from substrateinterface import Keypair
import json


def main():

    s = SUB()
    while True:
        try:
            kha = s.connect("khala")
            break
        except Exception as e:
            print(e)
            time.sleep(5)

    mnemonic = Keypair.generate_mnemonic()
    print(mnemonic)
    result = Keypair.create_from_mnemonic(mnemonic=mnemonic, ss58_format=s.khala["ss58_format"])
    addr = result.ss58_address
    privk = result.private_key.hex()

    from_key_mnemonic = input("请输入总地址助记词：")
    count = float(input("请输入转入gas数量："))

    if not count:
        count = 10

    from_k = Keypair.create_from_mnemonic(mnemonic=from_key_mnemonic, ss58_format=s.khala['ss58_format'])

    call = kha.compose_call(
        call_module='Balances',
        call_function='transfer',
        call_params={
            'dest': addr,
            'value': count * 10 ** kha.token_decimals
        }
    )
    extrinsic = kha.create_signed_extrinsic(call=call, keypair=from_k)
    try:
        receipt = kha.submit_extrinsic(extrinsic, wait_for_inclusion=True)
        txid = receipt.extrinsic_hash
        # print("Txid:'{}'".format(receipt.extrinsic_hash))

    except:
        txid = None

    matedata = json.dumps({
        'txid': txid,
        'mnemonic': mnemonic,
        'addr': addr,
        'privk': privk
    })

    with open("/var/khala/phala.json", "w") as f:
        f.write(matedata)

    f.close()


if __name__ == '__main__':
    main()
