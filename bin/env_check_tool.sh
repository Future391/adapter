#!/bin/bash
:<<note
该工具适用于CDH,Apache,HDP,FI,TDH集群组件(hadoop,hive,spark)环境检测，支持检测结果highlight显示
查看帮助信息：sh envCheckTool.sh --help
note

#使用说明
function usage(){
   cat <<EOF

Usage: $0 [options]
   
Options:
  -h, --help                   显示帮助信息
  -v, --verbose                打印debug信息
  -c, --component <string>     集群组件，支持多个，用逗号隔开，如：hadoop,hive
                               目前支持的组件包括hadoop,hive,spark
  -t, --cluster-type <string>  集群类型，如: cdh,apache

Example:
  sh envCheckTool.sh -v -c hadoop
EOF
}

#echo $BASH_SOURCE
CUR_DIR=$(cd `dirname $0`;pwd)
LOG_LEVEL=DEBUG
#Command路径
declare -A cmdPathMap
#Command Source路径
declare -A cmdSrcPathMap
components=()

func_file=${CUR_DIR}/function.sh
test ! -f ${func_file} && echo -e "\033[31m函数模块依赖缺失，请检查文件[${func_file}]是否存在!\033[0m" && exit 1
#加载通用函数依赖模块
. ${func_file}

#定义参数格式
getOptMsg=$(getopt -n "$0" -o hvc:t: -l help,verbose,components:,cluster-type: -- "$@")
[[ $? -ne 0 ]] && usage && exit 1

eval set -- $getOptMsg
#解析参数
while [ -n "$1" ]
do
    case "$1" in
        -h|--help)
            usage
            shift;exit;;
        -v|--verbose)
            verbose=1
            shift;;
        -c|--components)
            i=0
            for component in `echo $2 | tr "," "\n" | sort | uniq | xargs`
            do
                [[ ! $component =~ ^(hadoop|hive|spark)$ ]] && printFailed "不支持组件[$component]" && exit 1
                components[$i]=$component
                let i++
            done
            unset i
            shift 2;;
        -t|--cluster-type)
            #暂时不用
            clusterType=$2
            shift 2;;
        --)
            shift;break;;
        *)
            echo -e "unknown parameters [$1]"
            usage;exit 1;;
    esac
done

[[ -n "$@" ]] && debug "ignore components [$@]"

[[ ${#components[@]} -eq 0 ]] && {
    echo "输入组件为空，默认检测组件[hadoop hive spark]"
    components[0]=hadoop
    components[1]=hive
    components[2]=spark
} || {
    echo "输入组件：${components[@]}"
}

checkResult="\n\n######################## Env Check Report #######################\n"

debugAndRecord "Current User: `who am i | awk '{print $1}'`"

debug "检测命令路径..."
recordMsg "\n######## Command Path ##########"
debugAndRecord "Expected: path exists"
debugAndRecord "Actual:"
index=0
for component in ${components[@]}
do
    let index++
    case $component in
        spark)
            cmdArr=(spark-submit spark-shell);;
        hadoop)
            cmdArr=(hadoop hdfs);;
        hive)
            cmdArr=(hive);;
        *)
            cmdArr=($component);;
    esac
    for cmd in ${cmdArr[@]}
    do
        cmdPathMap["$cmd"]=`which $cmd 2>/dev/null`
        [[ -n ${cmdPathMap[$cmd]} && -h ${cmdPathMap[$cmd]} ]] && cmdSrcPathMap["$cmd"]=`getSourcePath ${cmdPathMap[$cmd]}`
        debugAndRecord "$(cat<<-EOF
$index.$cmd
Path[`checkEnvWithColor ${cmdPathMap[$cmd]} `]`[[ -n ${cmdSrcPathMap[$cmd]} ]] && echo ", Physical Path[${cmdSrcPathMap[$cmd]}]"`
EOF
)"
    done
done

debug "检测集群环境"
for component in ${components[*]} 
do

:<<note
检查Hadoop环境
指标：version,HADOOP_HOME,kerberos,execution result
note
[[ $component == "hadoop" ]] && {
    debug "开始检测Hadoop环境..."
    recordMsg "\n########## Hadoop Environment ##########"

    [[ -z ${cmdPathMap["hadoop"]} || -z ${cmdPathMap["hdfs"]} ]] && exit 1

    hadoopVersion=`hadoop version | grep -Eo "^Hadoop.*" | head -1`
    hdpClusterType=`getClusterType "$hadoopVersion"`
    #[[ -z $HADOOP_HOME ]] && HADOOP_HOME=`getEnvHome hadoop $hdpClusterType`

    debug "集群类型: $hdpClusterType"
    debugAndRecord "1.Hadoop version\n  Actual: $hadoopVersion"
	debugAndRecord "2.HADOOP_HOME\n  Actual: `checkEnvWithColor "$HADOOP_HOME" "unset"`"

    debug "检查集群文件写入功能"
    #测试文件
    test_file=`mktemp -t tmp_file_XXXXXX`
    test_file_name=`basename ${test_file}`
    echo "hello world" > ${test_file}
    debug "创建临时文件: ${test_file}"
    hdfs dfs -put -f ${test_file} /tmp/
    if [[ $? -eq 0 ]]; then
        write_test_result="Success" 
        debug "Actual: ${write_test_result}"
        rm ${test_file}
        debug "检查集群文件读取功能"
        hdfs dfs -get /tmp/${test_file_name}
        test $? -eq 0 && read_test_result="Success" || read_test_result="Failed" 
        debug "Actual: ${read_test_result}"
        test -f ${test_file_name} && rm ${test_file_name}
    else
        write_test_result="Failed"
    fi
    test -f ${test_file} && rm ${test_file}

    debugAndRecord "3.Hadoop write test result\n   Expected: Success   Actual: `cmpResWithColor ${write_test_result} Success`"
    [[ ${write_test_result} != "Success" ]] && exit 1
    debugAndRecord "4.Hadoop read test result\n   Expected: Success   Actual: `cmpResWithColor ${read_test_result} Success`"
    [[ ${read_test_result} != "Success" ]] && exit 1

}

:<<note
检查Hive环境
指标: version,hive-site.xml,metaStoreUris,kerberos,execution result
note
[[ $component == "hive" ]] && {
    debug "开始检测Hive环境..."
    recordMsg "\n########## Hive Environment ##########"
	ver_info=`hive --version 2>/dev/null`
    hiveVersion=`echo "${ver_info}" | grep -Eo "^Hive.*" | head -1`
    hiveClusterType=`getClusterType "$hiveVersion"`
    #[[ -z $HIVE_HOME ]] && HIVE_HOME=`getEnvHome hive $hiveClusterType`

    debug "集群类型: $hiveClusterType"
    debugAndRecord "1.Hive Version\n  Actual: $hiveVersion"
	debugAndRecord "2.HIVE_HOME\n  Actual: `checkEnvWithColor "$HIVE_HOME" "unset"`"

	hiveSiteFile=$HIVE_HOME/conf/hive-site.xml
	isFi=`echo "$ver_info" | grep "FusionInsight" | wc -l`
    if [[ ! -f $hiveSiteFile ]]; then
        #find / \( -path "/proc" -o -path "/tmp" -o -path "/boot" -o -path "/sys" \) -prune -o -type f -name "hive-site.xml" 2>/dev/null | grep -E "hive-site.xml"
		#HIVE_PATTERN_FI="Subversion .*FusionInsight.*"
		#FI环境

		if [[ $isFi -gt 0 ]]; then
			test -n "${cmdSrcPathMap[hive]}" && CMD_PATH=${cmdSrcPathMap[hive]} || CMD_PATH=${cmdPathMap[hive]} 
			if [[ -n "${CMD_PATH}" ]]; then
				hiveSiteFile=$(cd `dirname ${CMD_PATH}`/../../;pwd)/config/hive-site.xml
				test -f $hiveSiteFile && metaStoreUris=`grep -A 1 "hive.metastore.uris" $hiveSiteFile | grep "value.*" | sed 's/.*<value>//g;s/<\/value>//g' | tail -1`
			fi
		else
			debug "$hiveSiteFile not found"
		fi
    else
        metaStoreUris=`grep -A 1 "hive.metastore.uris" $hiveSiteFile | grep "value.*" | sed 's/.*<value>//g;s/<\/value>//g' | tail -1`
    fi

    debugAndRecord "3.Hive Site File\n  Expected: file exists    Actual: `checkFileWithColor $hiveSiteFile`"
    debugAndRecord "4.MetaStore Uris\n  Actual: $metaStoreUris"

    debug "执行example测试"
    if [[ $isFi -gt 0 ]];then
    hiveExecInfo=`beeline -e "show databases" 2>/dev/null`
    else
    hiveExecInfo=`hive -e "show databases" 2>/dev/null`
    fi
    if [[ $? -eq 0 && -n $hiveExecInfo && `echo "$hiveExecInfo" | wc -l` -gt 0 ]]; then
        hiveExecResult="Success"
    else
        hiveExecResult="Failed"
    fi
    debugAndRecord "5.Hive Execution Result\n  Expected: Success    Actual: `cmpResWithColor $hiveExecResult Success`"
    [[ ${hiveExecResult} != "Success" ]] && exit 1
}

:<<note
检查Spark环境
指标: version,HIVE_HOME,hive-site.xml,metaStoreUris,spark execution result
note
[[ $component == "spark" ]] && {
    debug "开始检测Spark环境..."
    recordMsg "\n########## Spark Environment ##########"

    [[ -z ${cmdPathMap["spark-shell"]} || -z ${cmdPathMap["spark-submit"]} ]] && exit 1

    versionInfo=`spark-submit --version 2>&1`
    sparkVersion=`echo -e "$versionInfo" | grep -E "^ .*version.*" | grep -Eo "version.*" | awk '{print "Spark",$2}'`
    scalaVersion=`echo -e "$versionInfo" | grep -Eo "Scala version .*" | awk -F', ' '{print $1}'`
    sparkClusterType=`getClusterType "$sparkVersion"`

    debug "集群版本: $sparkClusterType"
    debugAndRecord "1.Spark version\n  Actual: $sparkVersion"
	debugAndRecord "2.SPARK_HOME\n  Actual: `checkEnvWithColor "$SPARK_HOME" "unset"`"

    #SPARK_HOME
    test -z "$SPARK_HOME" && SPARK_HOME=`getEnvHome spark-submit $sparkClusterType`

    #兼容自编译的Spark-CDH版本
    SPARK_CATALOG=`basename $SPARK_HOME`

    #hive-site.xml
	sparkHiveSiteFile=${SPARK_HOME}/conf/hive-site.xml
    if [[ $sparkClusterType == "CDH" && ! -f $sparkHiveSiteFile ]]; then
        sparkHiveSiteFile=${SPARK_HOME}/conf/yarn-conf/hive-site.xml
    fi
    if [[ ! -f "$sparkHiveSiteFile" ]]; then
        debug "hive-site.xml不存在,检查spark_env.sh是否配置了HIVE_CONF_DIR"
        sparkEnvFile=/etc/${SPARK_CATALOG}/conf/spark-env.sh
        test ! -f $sparkEnvFile && sparkEnvFile=${SPARK_HOME}/conf/spark-env.sh
        if [[ `grep "HIVE_CONF_DIR" $sparkEnvFile | wc -l` -gt 0 ]]; then
            if [[ -n `grep "HIVE_CONF_DIR=" $sparkEnvFile | tail -1` ]]; then
                debug "解析HIVE_CONF_DIR表达式"
                eval `grep "HIVE_CONF_DIR=" $sparkEnvFile | tail -1`
            fi
            test -n "${HIVE_CONF_DIR}" && sparkHiveSiteFile=${HIVE_CONF_DIR}/hive-site.xml
        fi
    fi
    test -f $sparkHiveSiteFile && sparkHiveMetaStoreUris=`grep -A 1 "hive.metastore.uris" $sparkHiveSiteFile | grep "value.*" | sed 's/.*<value>//g;s/<\/value>//g' | tail -1`
  
    debugAndRecord "3.Hive Site File\n  Expected: file exists    Actual: `checkFileWithColor $sparkHiveSiteFile`"
    debugAndRecord "4.MetaStore Uris\n  Actual: `checkEnvWithColor "$sparkHiveMetaStoreUris" "unset"`"

    SPARK_EXAMPLE_FILE=`find ${SPARK_HOME}/examples/jars -name "spark-example*jar" | tail -1` 
    debug "执行example测试"
    sparkExecInfo=`spark-submit --class org.apache.spark.examples.SparkPi --master yarn --deploy-mode client ${SPARK_EXAMPLE_FILE} 10 2>&1`
    test `echo -e "$sparkExecInfo" | grep -E "Pi is roughly" | wc -l` -gt 0 && sparkExecResult="Success" || sparkExecResult="fail"
    debugAndRecord "5.Spark Execution Result\n  Expected: Success    Actual: `cmpResWithColor $sparkExecResult Success`"
    [[ $sparkExecResult != "Success" ]] && exit 1

    debug "检查spark-hive连通性"
    test_file=${CUR_DIR}/spark-hive-test.tmp
    #创建空文件
    test ! -f ${test_file} && touch ${test_file}
	#先删除derby文件
	test -f ${CUR_DIR}/derby.log && -d ${CUR_DIR}/metastore_db && rm ${CUR_DIR}/derby.log && rm -rf ${CUR_DIR}/metastore_db
    #执行scala代码
    echo "$(cat<<-EOF
    import org.apache.hadoop.hive.conf.HiveConf
    import org.apache.hadoop.hive.metastore.HiveMetaStoreClient
    val client = new HiveMetaStoreClient(new HiveConf())
    val dbSize = client.getAllDatabases.size
    if(dbSize >= 1){
        val file = new java.io.File("${test_file}")
        if(file.exists){file.delete}
    }
EOF
    )" | spark-shell --master local[*] --deploy-mode client 1>/dev/null 2>&1
    spark_hive_test_result="Failed"
    #空文件不存在则表示执行成功
    test ! -f ${test_file} && spark_hive_test_result="Success" || rm ${test_file}
	#如果有derby文件生成，说明spark-hive集成测试失败
	if [[ -f ${CUR_DIR}/derby.log && -d ${CUR_DIR}/metastore_db ]]; then
		rm ${CUR_DIR}/derby.log
		rm -rf ${CUR_DIR}/metastore_db
		spark_hive_test_result="Failed"
	fi
    debugAndRecord "6.Spark Hive Integration Test Result\n Expected: Success   Actual: `cmpResWithColor ${spark_hive_test_result} Success`"
    [[ ${spark_hive_test_result} != "Success" ]] && exit 1
}

done

debug "输出检测结果"
echo -e "$checkResult"
