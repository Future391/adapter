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
arango_url=${sink_arango_url}
arango_username=${sink_arango_user}
arango_password=${sink_arango_password}
arango_database=${sink_arango_database}
arango_vertex_collection=${sink_vertex_arango_collection}
arango_edge_collection=${sink_edge_arango_collection}

#校验参数
success_if=code
success_code=200

#解析json函数
function parse_json(){
	echo "${1//\"/}" | sed "s/.*$2:\([^,}]*\).*/\1/"
}

printInfo "----------------------------------------check arango : $arango_database.$arango_vertex_collection,$arango_database.$arango_edge_collection start ------------------------------------------------"

response=$(curl -u $arango_username:$arango_password -X POST "http://$arango_url/_db/$arango_database/_api/query" -H "accept: application/json" -H "Content-Type: application/json" -d "{ \"query\": \"FOR i IN $arango_vertex_collection LIMIT 2 RETURN i\"}")

if [ $success_code == $(parse_json $response $success_if) ]
then
	printSuccess " arango 顶点 $arango_vertex_collection 查询验证成功,response=$response "
else
   	printFailed " arango 顶点 $arango_vertex_collection 查询验证失败,response=$response "
    exit 1
fi

response=$(curl -u $arango_username:$arango_password -X POST "http://$arango_url/_db/$arango_database/_api/query" -H "accept: application/json" -H "Content-Type: application/json" -d "{ \"query\": \"FOR i IN $arango_edge_collection LIMIT 2 RETURN i\"}")

if [ $success_code == $(parse_json $response $success_if) ]
then
    printSuccess " arango 边 $arango_edge_collection 查询验证成功,response=$response "
else
    printFailed " arango 边 $arango_edge_collection 查询验证失败,response=$response "
    exit 1
fi

printInfo "----------------------------------------check arango : $arango_database.$arango_vertex_collection,$arango_database.$arango_edge_collection end ------------------------------------------------"

exit 0
