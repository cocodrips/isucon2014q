cd /home/isucon
id=`git log | head -n 1| sed 's/commit //g'`
time=`date '+%H:%M'`
./benchmarker bench --api-key 106-2-ncfwse-f0fa-42e35b240be67daf3bc4ee438116b5f425eaf4a7 > /var/log/bench/${time}_${id}.log