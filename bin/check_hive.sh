#!/bin/bash
cur_dir=$(cd `dirname $0`;pwd)
base_home=$(cd ${cur_dir}/..;pwd)
#函数依赖脚本
func_file=${base_home}/bin/function.sh
#加载通用函数依赖模块
. ${func_file}
config_file=${base_home}/conf/config/adapter.ini
#加载参数文件
source $config_file

hive_database=${source_hive_database}
hive_vertex_table=${sink_vertex_hive_table}
hive_edge_table=${sink_edge_hive_table}

printInfo "------------------------------------------------ check hive : $hive_database.$hive_vertex_table, $hive_database.$hive_edge_table  start ------------------------------------------------"

echo -e "sql(\"select * from $hive_database.$hive_vertex_table limit 5\").show\nsql(\"select * from $hive_database.$hive_edge_table limit 5\").show" | spark-shell --master local[*]

printInfo "------------------------------------------------ check hive : $hive_database.$hive_vertex_table,$hive_database.$hive_edge_table  end ------------------------------------------------"
