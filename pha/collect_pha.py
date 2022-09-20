import time

from srkSUB.base import SUB
from substrateinterface import Keypair
import json

fkList = [
    # 助记词列表
]

def main():

    s = SUB()
    while True:
        try:
            kha = s.connect("khala", "")
            break
        except Exception as e:
            print(e)
            time.sleep(5)


    for fk in  fkList:
        from_k = Keypair.create_from_mnemonic(mnemonic=fk, ss58_format=s.khala['ss58_format'])
        print(kha.query("System", "Account", [from_k.ss58_address])["data"]["free"])
        call = kha.compose_call(
            call_module='Balances',
            call_function='transfer',
            call_params={
                'dest': "44qbB4rXDVhqxqMAbVfG7FfxSjgVaNMPafS3BVaDnGB4DWGc",
                'value': 0.49 * 10 ** kha.token_decimals
            }
        )
        extrinsic = kha.create_signed_extrinsic(call=call, keypair=from_k)
        try:
            receipt = kha.submit_extrinsic(extrinsic, wait_for_inclusion=True)
            txid = receipt.extrinsic_hash
            # print("Txid:'{}'".format(receipt.extrinsic_hash))

        except:
            txid = None

        print(txid)

if __name__ == '__main__':
    main()