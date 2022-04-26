#!/bin/bash
##自定义函数##
# Author: pengxb
# Date : 2021/01

#获取日志时间信息
function printLogTime()
{
    [[ -n $1 ]] && {
        LOG_LEVEL=`echo $1 | tr a-z A-Z`
        [[ $LOG_LEVEL != "DEBUG" && $LOG_LEVEL != "INFO" && $LOG_LEVEL != "WARN" && $LOG_LEVEL != "ERROR" ]] && LOG_LEVEL="DEBUG"
    }
    local MILLIS=`date +%N`
    echo "$(date +"%Y-%m-%d %H:%M:%S"),${MILLIS:0:3} $LOG_LEVEL"
}

#打印DEBUG信息
function debug()
{
    [ -n "$verbose" ] && {
        echo -e "`printLogTime DEBUG` $@"
    }
}

#记录结果信息
function recordMsg()
{
    checkResult="$checkResult\n$@"
}

#记录打印结果信息
function debugAndRecord()
{
    debug "$@"
    checkResult="$checkResult\n$@"
}

#获取文件真实路径
function getSourcePath()
{
    local SOURCE=$1
    local BASE_DIR=`dirname $SOURCE`
    while [[ -h $SOURCE ]]
    do
        SOURCE=$(readlink $SOURCE)
        [[ $SOURCE != /* ]] && SOURCE=${BASE_DIR}/$SOURCE
    done
    echo $SOURCE
}

#输出成功信息(绿色高亮)
function printSuccess()
{
    echo -e "\033[32m$1\033[0m"
}

#输出错误信息(红色高亮)
function printFailed()
{
    echo -e "\033[31m$1\033[0m"
}

#输出日志信息(蓝色高亮)
function printInfo()
{
	echo -e "\033[36m$1\033[0m"
}

#检查文件是否存在
function checkFileExists()
{
	local result=0
	for file in $@
	do
		test ! -f $file && printFailed "file [$file] not found" && result=1 && break
	done
	return $result
}

:<<note
检查环境变量是否存在并高亮展示
  @EVN  变量名
  @DEFAULT_INFO 默认显示信息,可为空
note
function checkEnvWithColor()
{
    local ENV=$1
    local DEFAULT_INFO=$2
    [[ -n $ENV ]] && {
        #green
        echo "\033[32m$ENV\033[0m"
    } || {
        [[ -z $2 ]] && DEFAULT_INFO="command not found"
        #red
        echo "\033[31m${DEFAULT_INFO}\033[0m"
    }
}

#检查文件是否存在并高亮展示
function checkFileWithColor()
{
    [[ -n $1 && -f $1 ]] && echo `checkEnvWithColor $1` || echo `checkEnvWithColor "" "File not found"`
}

function cmpResWithColor()
{
    local THIS=$1
    local OTHER=$2
    local DEFAULT=$3
    [[ $THIS == $OTHER ]] && {
        echo "\033[32m$THIS\033[0m"
    } || {
        [[ -z $DEFAULT ]] && DEFAULT=$THIS
        echo "\033[31m$DEFAULT\033[0m"
    }
}

#获取集群类型
function getClusterType()
{
    local VER_INFO="$1"
    [[ -z ${VER_INFO} ]] && {
        echo "None"
    } || {
        [[ `echo -e "${VER_INFO}" | tr "A-Z" "a-z" | grep -E "cdh|cloudera" | wc -l` -gt 0 ]] && echo "CDH" || echo "Apache"
    }
}

#获取kerberos配置
function getKerberosConfig()
{
	local kerberos_config=""
	if [[ -n ${HADOOP_HOME} ]]; then
		core_site=${HADOOP_HOME}/etc/hadoop/core-site.xml
		[[ -f ${core_site} ]] && kerberos_config=`cat ${core_site} | grep -A 1 "hadoop.security.authentication" | tail -1 | sed 's#.*<value>##g;s#</value>##g'`
	fi
	echo ${kerberos_config}
}

#获取集群组件Home目录
function getEnvHome()
{
    local CMD=$1
    local CLUSTER_TYPE=$2
    local TMP_PATH=${cmdPathMap["$CMD"]}
    local ENV_HOME=""
    [[ -n ${cmdSrcPathMap["$CMD"]} ]] && TMP_PATH=${cmdSrcPathMap["$CMD"]}
    [[ $CMD == *spark* ]] && CMD=spark
    DIR_NAME=`dirname ${TMP_PATH}`
    if [[ ${CLUSTER_TYPE} == "CDH" ]]; then
        local PARENT_DIR=`dirname $DIR_NAME`
        [[ $(basename ${PARENT_DIR}) == *$CMD* ]] && ENV_HOME=$(cd -P ${PARENT_DIR};pwd) || ENV_HOME=$(cd -P ${DIR_NAME}/../lib/$CMD;pwd)
    elif [[ ${CLUSTER_TYPE} == "Apache" ]]; then
        ENV_HOME=$(cd -P ${DIR_NAME}/../;pwd)
    fi
    echo ${ENV_HOME}
}

#获取文件真实目录
function getFilePath()
{
    local TRUE_PATH=$1
    [[ -n $1 ]] && {
        local DIR_NAME=$(cd `dirname $1`;pwd)
        local FILE_NAME=$(basename $1)
        TRUE_PATH=${DIR_NAME}/${FILE_NAME}
    }
    echo ${TRUE_PATH}
}

#执行Hive语句
function init_table()
{
    local cmd=$1
    local executionFile=$2
    #执行命令
    $cmd -f $executionFile
    local resultCode=$?
    if [[ $resultCode -eq 0 ]]; then
        printSuccess "使用命令[$cmd]创建表成功"
    else
        printFailed "使用命令[$cmd]创建表失败"
    fi
    return $resultCode
}

#校验properties文件参数合法性
function validate_file()
{
    local config_file=$1
    test ! -f ${config_file} && printFailed "配置文件[${config_file}]不存在" && return 1
    test `awk '{if($0 !~ /^#.*/ && $0 !~ /^$/ && $0 !~ /^[a-z|A-Z|_].*=.*/) {print $0}}' ${config_file} | wc -l` -gt 0 && {
        printFailed "配置文件[${config_file}]参数格式不正确！"
        #打印错误行信息
        awk '{if($0 !~ /^#.*/ && $0 !~ /^$/ && $0 !~ /^[a-z|A-Z|_].*=.*/) {print "行"NR":\t" $0}}' ${config_file}
        return 1
    }
    return 0
}

:<<note
加载配置文件参数，外部调用者可以通过paramMap获取参数信息
  args1   配置文件路径
  args2   存放配置文件参数map集合名称，默认为paramMap，需要外部先定义，参数可选
note
function load_params()
{
    local config_file=$1
    local mapVar=$2
    test ! -f ${config_file} && printFailed "配置文件[${config_file}]不存在" && return 1
    test -z "$mapVar" && mapVar="paramMap"
    while read line
    do
        #过滤注释和空行
        if [[ ! $line =~ ^#.*|^$ ]]; then
            #bash变量不能包含'.'，需要特殊处理，这里将'.'转化为'_'
    	    local key=`echo "$line" | awk -F'=' '{print $1}' | sed 's/\./_/g'`
            local value=`echo "$line" | awk -F'=' '{for(i=2;i<=NF;i++){str=str""FS""$i} if(str != ""){str=substr(str,2)} print str}'`
            #添加值到集合
            eval $mapVar[$key]="$value"
            #参数赋值
#            read $key <<-EOF
#                $value
#EOF
        fi
    done < ${config_file}
}
