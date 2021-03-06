#!/bin/bash

# 判断当前脚本所在的路径，支持软连接
SOURCE="$0"
while [ -h "$SOURCE"  ]; do 
    DIR="$( cd -P "$( dirname "$SOURCE"  )" && pwd  )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /*  ]] && SOURCE="$DIR/$SOURCE" 
done
DIR="$( cd -P "$( dirname "$SOURCE"  )" && pwd  )"


# 创建网络方法
function createNetwork(){
	# 如果网络不存在，则创建
	network=$(docker network ls | grep myNet)
	if [ ! -n "$network" ]
	then
		docker network create myNet
	fi
}

# 清除已存在的容器
function resetContainer(){
	if [  -n $1 ]
	then
		container=$(docker ps -a | grep $1)
		if [ -n "$container" ]
		then
			docker stop $1 && docker rm $1
		fi
	fi
}

# 创建应用方法# 
function createApp(){
	
	appName=$1
	
	if [ ! -n "$appName" ]
	then
		echo '请指定应用名称！'
		exit 1
	else
		resetContainer "$appName"
		phpfpmConfigFile="$DIR"/apps/"$appName"/phpfpm.conf
		Image=$(docker images | grep my/app-"$2")
		if [ ! -n "$Image" ]
		then
			docker build -t my/app-"$2" "$DIR"/env/ -f "$DIR"/env/"$2"
		fi
		if [ -f "$ConfigFile" ]
		then
			docker run -d --name "$appName" --net=myNet \
			-v "$DIR"/apps/"$appName"/htdocs:/htdocs \
			-v "$DIR"/apps/"$appName"/logs:/logs \
			-v "$phpfpmConfigFile":/usr/local/etc/php-fpm.d/zz-docker.conf \
			--restart=always my/app-"$2"
		else
			docker run -d --name "$appName" --net=myNet \
			-v "$DIR"/apps/"$appName"/htdocs:/htdocs \
			-v "$DIR"/apps/"$appName"/logs:/logs \
			--restart=always my/app-"$2"
		fi	
	fi
}

# 创建容器方法
function createContainer(){
	for arg in $@; do  
		if [ -f "$DIR"/${arg}/locked ]
		then
			continue
		fi
	case ${arg} in
   		'redis') 
			docker build -t my/redis "$DIR"/redis
			resetContainer redis
			docker run -d --name redis --net=myNet \
			-v "$DIR"/redis/redis.conf:/etc/redis.conf \
			-v "$DIR"/redis/data:/data \
			--restart=always my/redis
      		;;
      	'mysql') 
			docker pull mysql
			resetContainer mysql
			docker run -d --name mysql --net=myNet \
			-v "$DIR"/mysql/data:/var/lib/mysql \
			-e MYSQL_ROOT_PASSWORD=12346 \
			-p 3306:3306 \
			--restart=always mysql
      		;;
      	'nginx') 
			docker build -t my/nginx "$DIR"/nginx
			resetContainer nginx
			docker run -d --name nginx --net=myNet \
			-v "$DIR"/apps:/htdocs \
			-v "$DIR"/nginx/conf/nginx.conf:/etc/nginx/nginx.conf \
			-v "$DIR"/nginx/conf/conf.d/:/etc/nginx/conf.d \
			-v "$DIR"/nginx/logs:/logs \
			-p 80:80 --restart=always my/nginx
      		;;
   		'gogs') 
      		# 安装版本控制服务器
			docker pull gogs/gogs
			resetContainer gogs
			mkdir -p "$DIR"/gogs/data
			# Use `docker run` for the first time.
			docker run  -d --name=gogs --net=myNet -p 10022:22 -p 10080:3000 -v "$DIR"/gogs/data:/data --restart=always gogs/gogs
			# Use `docker start` if you have stopped it.
			#docker start gogs
      		;;
      	'jenkins') 
      		docker build -t my/jenkins "$DIR"/jenkins
      		resetContainer jenkins
			mkdir -p "$DIR"/jenkins/data
			docker run -d --name jenkins --net=myNet -p 8080:8080 -p 50000:50000 -v "$DIR"/jenkins/data:/var/jenkins_home -v "$DIR"/apps:/htdocs --restart=always my/jenkins
      		;;
   		*) 
			appName=$(echo ${arg} | cut -d ':' -f1)
			env=$(echo ${arg} | cut -d ':' -f2)
			if [ ! -n "$env" ]
			then
				echo 请指定应用环境：php5 , php7, golang 之一！
				exit;
		    fi
      		appPath="$DIR"/apps/${appName}
			if [ -d "$appPath" ]
			then
				createApp ${appName} ${env}
				vhostConf="$DIR"/apps/${appName}/vhost.conf
				if [ -f "$vhostConf" ]
				then
					cp -f "$vhostConf" "$DIR"/nginx/conf/conf.d/${appName}.conf
					serverName=$(cat "$vhostConf" | grep server_name |  head -1 | tr -s ' ' | cut -d ' ' -f3 | tr -d ';')

					#添加 serverName 至 host文件
					hostContent=$(cat /etc/hosts |grep "$serverName")
					if [ ! -n "$hostContent" ]
					then
						echo 127.0.0.1 "$serverName" >> /etc/hosts
					fi

					docker restart nginx
				fi
			fi
      		;;
	esac 
	if [ -d "$DIR"/${arg} ]
	then
		touch "$DIR"/${arg}/locked
	fi
	done  
}
createNetwork
createContainer $@
