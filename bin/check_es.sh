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
es_url_tmp=${sink_es_url}
array=(${es_url_tmp//,/ })
es_url=${array[0]}
es_vertex_index=${sink_vertex_es_index}
es_vertex_type=${sink_vertex_es_type}
es_edge_index=${sink_edge_es_index}
es_edge_type=${sink_edge_es_type}
es_error="error"

printInfo "-----------------------------------------es check : $es_vertex_index/$es_vertex_type,$es_edge_index/$es_edge_type strat ---------------------------------------"

response=$(curl -X GET $es_url/$es_vertex_index/$es_vertex_type/_search?size=2)
if [[ $response == *$es_error* ]]
then
    printFailed " es查询异常，验证结果: $response "
    exit 1
else
    printSuccess " es查询正常，验证结果: $response "
fi

response=$(curl -X GET $es_url/$es_edge_index/$es_edge_type/_search?size=2)
if [[ $response == *$es_error* ]]
then
    printFailed " es查询异常，验证结果: $response "
    exit 1
else
    printSuccess " es查询正常，验证结果: $response "
fi

printInfo "-----------------------------------------es check : $es_vertex_index/$es_vertex_type,$es_edge_index/$es_edge_type end   ---------------------------------------"

exit 0
