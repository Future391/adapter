#!/bin/bash
cur_dir=$(cd `dirname $0`;pwd)
base_home=$(cd ${cur_dir}/..;pwd)
#函数依赖脚本
func_file=${base_home}/bin/function.sh
test ! -f ${func_file} && echo -e "\033[31m函数模块依赖缺失，请检查文件[${func_file}]是否存在!\033[0m" && exit 1
#加载通用函数依赖模块
. ${func_file}

#参数集合
declare -A paramMap
#加载配置文件参数
load_params ${base_home}/conf/config/adapter.properties paramMap

#日志文件
LOG_FILE=${base_home}/logs/etl_flow_check_$(date +"%Y%m%d%H%M%S").log
mkdir -p ${base_home}/logs/

#流程依赖脚本
env_check_script=${base_home}/bin/env_check_tool.sh
init_config_script=${base_home}/bin/init_config.sh
load_data_hive_script=${base_home}/bin/load_data_hive.sh
run_etl_script=${base_home}/bin/run.sh
run_kerberos_etl_script=${base_home}/bin/runAuth.sh
check_es=${base_home}/bin/check_es.sh
check_arango=${base_home}/bin/check_arango.sh
check_hive=${base_home}/bin/check_hive.sh
check_load_path=${base_home}/conf/data/.loadSuccess

:<<note
检查执行结果
args1: 执行结果
args2: 预设成功返回信息
args3: 预设失败返回信息
note
function check_exec_result()
{
	local exec_result=$1
	local success_msg=$2
	local failed_msg=$3
	if [[ ${exec_result} -ne 0 ]]; then
		printFailed "${failed_msg}"
		exit ${exec_result}
	else
		printSuccess "$success_msg"
	fi
}

#检查脚本是否存在
checkFileExists "${env_check_script}" "${init_config_script}" "${load_data_hive_script}" "${run_etl_script}" "${run_kerberos_etl_script}" | tee -a ${LOG_FILE}
test $? -ne 0 && exit 1

#开启debug日志打印
verbose=true

#检测kerberos
kerberos=${paramMap[kerberos_enable]}
printInfo " kerberos = $kerberos"

debug "详细信息科查看日志文件：tail -f ${LOG_FILE}"

#1.环境检测
:<<note
debug "开始环境检测..." | tee -a ${LOG_FILE}
sh ${env_check_script} -v -c hadoop,hive,spark >> ${LOG_FILE} 2>&1
exec_result=$?
check_exec_result ${exec_result} "环境监测正常" "环境监测异常"
note

#2.生成配置文件
debug "开始生成配置文件..." | tee -a ${LOG_FILE}
sh ${init_config_script} >> ${LOG_FILE} 2>&1
exec_result=$?
check_exec_result ${exec_result} "配置文件生成正常" "配置文件生成异常"

#3.初始化Hive表
debug "初始化hive表数据..." | tee -a ${LOG_FILE}
sh ${load_data_hive_script} >> ${LOG_FILE} 2>&1
if [ -f "$check_load_path" ];
then
	exec_result=0
else
	exec_result=1
fi
hive_ini_data_rs=$exec_result
check_exec_result ${exec_result} "hive初始化数据成功" "hive初始化数据失败"

#4.执行ETL导数任务
debug "执行ETL导数任务" | tee -a ${LOG_FILE}
etl_config_files=(${base_home}/conf/instance/vertex/hive2All.json ${base_home}/conf/instance/edge/hive2All.json)
for etl_config_file in ${etl_config_files[@]}
do
	if [[ "$kerberos"x == truex ]]; then
		sh ${run_kerberos_etl_script} ${etl_config_file} >> ${LOG_FILE} 2>&1
	else
		#无kerberosi
	    sh ${run_etl_script} ${etl_config_file} >> ${LOG_FILE} 2>&1
	fi
	exec_result=$?
	etl_load_data_rs=$exec_result
	check_exec_result ${exec_result} "ETL导数正常" "ETL导数异常"
done

#5.检查ETL执行结果
sink_flow_nodes=${paramMap[sink_flow_nodes]}
printInfo "check sinks = $sink_flow_nodes "
arr=(${sink_flow_nodes//,/ })
for i in ${arr[@]}
do
	case $i in
	es)  
        sh $check_es >> ${LOG_FILE} 2>&1
        exec_result=$?
        check_exec_result ${exec_result} "es 查询数据正常" "es 查询数据异常"
        es_rs_check=$exec_result
	;;
	arango)  
        sh $check_arango >> ${LOG_FILE} 2>&1
        exec_result=$?
        check_exec_result ${exec_result} "arango查询数据正常" "arango查询数据异常"
        adb_rs_check=$exec_result
	;;
	hive)  
        sh $check_hive
	;;
	*)  printFailed ' sinks 参数不符合规范, 应该按照es,arango,hive格式'
	;;
	esac
done
