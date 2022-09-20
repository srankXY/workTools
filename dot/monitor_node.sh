#!/bin/sh
. /etc/profile
. ~/.profile

grep_count=`ps -ef|grep -c polkadot`
time=`date +%Y-%m-%d,%H:%M:%S`
echo "grep_count is ${grep_count} "

if [ $grep_count -le 1 ];then
        echo "[$time] need start node, grep_count:$grep_count" >> ~/scripts/monitor.log
        cd ~/polkadot-home/bin/
        nohup ./polkadot --validator --name "QINWEN-168Node" --out-peers 100 --pruning=archive --reserved-nodes "/ip4/127.0.0.1/tcp/20900/p2p/12D3KooWAGZVtmCi3kN7pc3HJxR3m5f4waQXdQ7F7u3Xzyy1aPUd" > ~/polkadot-home/bin/polkadot.log 2>&1 &
        sleep 1
        exit 0
fi

peer_count=`curl -H "Content-Type: application/json" -d '{"id":1, "jsonrpc":"2.0", "method": "system_health"}' http://localhost:9933/ | jq ".result.peers"`
echo "peer_count is ${peer_count} "

if [ $peer_count -le 0 ];then
        echo "[$time] need restart node, peer_count:$peer_count" >> ~/scripts/monitor.log
        ps -ef | grep polkadot | grep -v grep | awk '{print $2}' | xargs kill
        cd ~/polkadot-home/bin/
        nohup ./polkadot --validator --name "QINWEN-168Node" --out-peers 100 --pruning=archive --reserved-nodes "/ip4/127.0.0.1/tcp/20900/p2p/12D3KooWAGZVtmCi3kN7pc3HJxR3m5f4waQXdQ7F7u3Xzyy1aPUd" > ~/polkadot-home/bin/polkadot.log 2>&1 &
fi

log_err=$(tail -n 5 /home/gch/polkadot-home/bin/polkadot.log | grep -Eic "err=Subsystem")

if [[ $log_err -ne 0 ]];then
  echo "[$time] need restart node, log_err:$log_err" >> ~/scripts/monitor.log
  ps -ef | grep polkadot | grep -v grep | awk '{print $2}' | xargs kill
  cd ~/polkadot-home/bin/
  nohup ./polkadot --validator --name "QINWEN-168Node" --out-peers 100 --pruning=archive --reserved-nodes "/ip4/127.0.0.1/tcp/20900/p2p/12D3KooWAGZVtmCi3kN7pc3HJxR3m5f4waQXdQ7F7u3Xzyy1aPUd" > ~/polkadot-home/bin/polkadot.log 2>&1 &
fi