#!/bin/bash
cur_dir=$(cd `dirname $0`;pwd)
base_home=$(cd ${cur_dir}/..;pwd)
#配置参数文件路径
config_file=${base_home}/conf/config/adapter.ini
#加载参数文件
source $config_file
func_file=${base_home}/bin/function.sh
#加载通用函数依赖模块
. ${func_file}

input_param=$1
echo "start execute with sparkArgs ${input_param}"

master=yarn

#手动修改principal
principal=${kerberos_principal}
keytab=${kerberos_keytab_path}
printInfo " 打印kerberos认证信息： user $principal  keytab: $keytab"
kinit -kt $keytab $principal

export HADOOP_USER_NAME=$(whoami)
echo " HADOOP_USER_NAME = ${HADOOP_USER_NAME} "
param_path=/user/${HADOOP_USER_NAME}/etl/etl_kgp_loader/args/${input_param##*/}

hdfs dfs -mkdir -p /user/${HADOOP_USER_NAME}/etl/etl_kgp_loader/args/
hdfs dfs -put -f ${input_param} ${param_path}

spark-submit \
  --principal $principal \
  --keytab $keytab \
  --master ${master} \
	--deploy-mode cluster \
  --driver-memory 1g \
  --driver-cores 1 \
  --executor-memory 2g \
  --executor-cores 1 \
  --num-executors 1 \
	--conf spark.sql.limitScan.enabled=false \
	--conf spark.yarn.security.credentials.hbase.enabled=true \
  --class com.haizhi.etl.kgp.loader.KgpSparkLoader \
  --jars `find ./lib -type f -name '*.jar' | grep -v "etl-kgp-loader" | xargs | tr ' ' ','` \
  ${base_home}/lib/etl-kgp-loader-*.jar hdfs://${param_path}

res=$?
echo "spark execution result: $res"
hdfs dfs -rm -r -skipTrash hdfs://${param_path}
echo "$?"
echo "spark execution result: $res"
exit $res
