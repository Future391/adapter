#!/bin/bash
cur_dir=$(cd `dirname $0`;pwd)
base_home=$(cd ${cur_dir}/..;pwd)
#Load.scala路径
load_path=$base_home/conf/instance/others/Load.scala
#函数依赖脚本
func_file=${base_home}/bin/function.sh
#加载通用函数依赖模块
. ${func_file}
#data数据路径
hive_vertex_path=$base_home/conf/data/table_data_vertex.txt
hive_edge_path=$base_home/conf/data/table_data_edge.txt
#实例路径
hive_instance_path=$base_home/conf/instance/others/Load.scala

#修复导数路径
sed -i 's#${source.data.vertex.path}#'"$hive_vertex_path"'#' $hive_instance_path
sed -i 's#${source.data.edge.path}#'"$hive_edge_path"'#' $hive_instance_path

printInfo "----------------------------------------------- load data vertex,edge start -----------------------------------------------"

#判断文件是否存在
if [ ! -f "$load_path" ]; 
then
	printFailed " 加载数据文件不存在, path = $load_path "
	exit
fi

spark-shell --master local[*] < $load_path

printInfo "----------------------------------------------- load data vertex,edge end  -------::----------------------------------------"
