#!/bin/bash
cur_dir=$(cd `dirname $0`;pwd)
base_home=$(cd ${cur_dir}/..;pwd)
#函数依赖脚本
func_file=${base_home}/bin/function.sh
#加载通用函数依赖模块
. ${func_file}
#配置参数文件路径
config_file=${base_home}/conf/config/adapter.ini
#加载参数文件
source $config_file

#配置参数
taurus_url=${taurus.url}
taurus_port=${taurus.port}
taurus_env_id=-10000

#解析json函数
function parse_json(){
	echo "${1//\"/}" | sed "s/.*$2:\([^,}]*\).*/\1/"
}

#验证登录函数并获取cookie
function authentication(){
	local payload=$(parse_json $1 "payload")
	local data=$(parse_json $payload "data")
	cookie=$(parse_json $data "sessionId")
}

#认证接口函数
function check_interface(){
	echo "------------------------ $1 start ----------------------"
	printInfo " 打印 $1 接口返回结果: $2 "
	local value=$(parse_json $2 "success")
	local flag=true
	if [ "$value"x = "$flag"x ]
	then
	   	printSuccess " 适配 $1 接口成功 "
		#判断是否是登录接口，如果是则获取cookie
        if [ "$3"x = "login"x ]
        then
            authentication $2
			printSuccess " 登录接口 cookie : $cookie "
        fi
	else
      	printFailed " 适配 $1 接口失败"
		#判断是否是登录接口，如果是则退出程序
       	if [ "$3"x = "importantx" ]
       	then
           	printFailed " $1 失败，无法继续运行，程序结束 "
		exit
       	fi
	fi
	echo "------------------------ $1 end   ----------------------"
}

printInfo "--------------------------------------------------- check taurus start ---------------------------------------------------"
#/taurus/api/auth/login登录接口验证
response=$(curl --location --request POST "http://$taurus_url:$taurus_port/taurus/api/auth/login" \
--header 'Content-Type: application/json' \
--data '{
"autoLogin": "N",
"password": "hgr4PVo3NuF6G0GmF3f/hg==",
"userNo": "superadmin"
}')

check_interface "taurus-登录接口"  $response login

#-------------------------------------HDFS Start----------------------------------------

response=$(curl --location --request GET "http://$taurus_url:$taurus_port/taurus/api/hdfs/permission?envId=$taurus_env_id" \
 --header "Cookie: JSESSIONID=$cookie")

check_interface "taurus-hdfs连通性测试接口"  $response important

response=$(curl --location --request GET "http://$taurus_url:$taurus_port/taurus/api/hdfs/exists?envId=$taurus_env_id&path=%2Ftmp" \
 --header "Cookie: JSESSIONID=$cookie")

check_interface "taurus-hdfs-exists接口" $response

#每次执行脚本随机生成的文件名
file_name=file_$RANDOM

response=$(curl --location --request GET "http://$taurus_url:$taurus_port/taurus/api/hdfs/file/create?envId=$taurus_env_id&path=%2Ftmp%2F$file_name" \
 --header "Cookie: JSESSIONID=$cookie")

check_interface "taurus-hdfs-file-create接口" $response

#删除文件
response=$(curl --location --request GET "http://$taurus_url:$taurus_port/taurus/api/hdfs/delete?envId=$taurus_env_id&path=%2Ftmp%2F$file_name&recursive=false" \
 --header "Cookie: JSESSIONID=$cookie")

check_interface "taurus-hdfs-delete接口" $response

#-------------------------------------HDFS end----------------------------------------

#-------------------------------------Hive Start----------------------------------------

#查看所有库
response=$(curl --location --request GET "http://$taurus_url:$taurus_port/taurus/api/hive/queryDatabases" \
 --header "Cookie: JSESSIONID=$cookie")

check_interface "taurus-hive-queryDatabases接口" $response important


#每次执行脚本随机生成的库名
database_name=taurus_check_database_$RANDOM
response=$(curl --location --request GET "http://$taurus_url:$taurus_port/taurus/api/hive/createDatabaseIfNotExists?database=$database_name" \
 --header "Cookie: JSESSIONID=$cookie")

echo " 库名: $database_name"
check_interface "taurus-hive-createDatabaseIfNotExists接口" $response important

#每次执行脚本随机生成的表名
table_name=taurus_check_table_$RANDOM
response=$(curl --location --request POST "http://$taurus_url:$taurus_port/taurus/api/hive/createTable?sql=create%20table%20if%20not%20exists%20$database_name.$table_name(object_key%20string%2C%20name%20string%2C%20age%20int)" \
 --header "Cookie: JSESSIONID=$cookie")

echo " 表名：$table_name"
check_interface "taurus-hive-createTable接口" $response important

#新增表数据
response=$(curl --location --request POST "http://$taurus_url:$taurus_port/taurus/api/hive/execute?sql=insert%20into%20$database_name.$table_name%20values(%27001%27%2C%27a%27%2C10)" \
 --header "Cookie: JSESSIONID=$cookie")

check_interface "taurus-hive-execute:insert into接口" $response

#查看表数据
response=$(curl --location --request POST "http://$taurus_url:$taurus_port/taurus/api/hive/executeQuery?sql=select%20*%20from%20$database_name.$table_name%20limit%205" \
 --header "Cookie: JSESSIONID=$cookie")

check_interface "taurus-hive-executeQuery接口" $response

#删除表
response=$(curl --location --request POST "http://$taurus_url:$taurus_port/taurus/api/hive/execute?sql=drop%20table%20IF%20EXISTS%20$database_name.$table_name" \
 --header "Cookie: JSESSIONID=$cookie")

check_interface "taurus-hive-execute:drop table接口" $response

#删除库
response=$(curl --location --request POST "http://$taurus_url:$taurus_port/taurus/api/hive/execute?sql=drop%20database%20IF%20EXISTS%20$database_name" \
 --header "Cookie: JSESSIONID=$cookie")

check_interface "taurus-hive-execute:drop database接口" $response

printInfo "--------------------------------------------------- check taurus end ---------------------------------------------------"



