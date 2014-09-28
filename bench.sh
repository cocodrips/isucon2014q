rm -f /var/log/nginx/*.log
rm -f /var/log/mysql/*.log
sudo service mysqld restart
sudo service nginx restart
sudo service redis restart
sudo service varnish restart
supervisorctl restart isucon_ruby

cd /home/isucon
id=`git log | head -n 1| sed 's/commit //g'`
time=`date '+%H:%M'`
./benchmarker bench --workload 4 --api-key 106-2-ncfwse-f0fa-42e35b240be67daf3bc4ee438116b5f425eaf4a7 |tee /var/log/bench/${time}_${id}.log 

sudo mkdir /var/log/logs/${time}_${id}

sudo mkdir /var/log/logs/${time}_${id}/mysql
sudo mkdir /var/log/logs/${time}_${id}/nginx

sudo mv /var/log/mysql/*.log /var/log/logs/${time}_${id}/mysql/
sudo mv /var/log/nginx/*.log /var/log/logs/${time}_${id}/nginx/

sudo mv /var/log/bench/${time}_${id}.log /var/log/logs/${time}_${id}/bench.log

cd /var/log/logs/${time}_${id}/
sudo chown -R isucon:isucon ./
git add .
git commit -m "${time}"
git push origin master
