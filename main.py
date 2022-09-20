# This is a sample Python script.

# Press Shift+F10 to execute it or replace it with your code.
# Press Double Shift to search everywhere for classes, files, tool windows, actions, and settings.


from web3 import Web3

w3 = Web3(Web3.WebsocketProvider('ws://192.168.1.132:19944'))
print(w3.isConnected())
