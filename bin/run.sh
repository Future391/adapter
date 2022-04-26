#!/bin/bash
DIR=$(cd `dirname $0`; cd ..; pwd)
cd $DIR
input_param=$1
echo "start execute with sparkArgs ${input_param}"

master=yarn

export HADOOP_USER_NAME=$(whoami)
echo " HADOOP_USER_NAME = ${HADOOP_USER_NAME} "
param_path=/user/${HADOOP_USER_NAME}/etl/etl_kgp_loader/args/${input_param##*/}

hdfs dfs -mkdir -p /user/${HADOOP_USER_NAME}/etl/etl_kgp_loader/args/
hdfs dfs -put -f ${input_param} ${param_path}

spark-submit \
  --master ${master} \
  --deploy-mode client \
  --conf "spark.yarn.security.tokens.hive.enabled=false" \
  --driver-memory 1g \
  --driver-cores 1 \
  --executor-memory 2g \
  --executor-cores 1 \
  --num-executors 1 \
  --class com.haizhi.etl.kgp.loader.KgpSparkLoader \
  --jars `find ./lib -type f -name '*.jar' | grep -v "etl-kgp-loader" | xargs | tr ' ' ','` \
  ./lib/etl-kgp-loader-*.jar hdfs://${param_path}

res=$?
hdfs dfs -rm hdfs://${param_path}
if [ $res -ne 0 ]; then
    exit 1
fi
