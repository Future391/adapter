#!/bin/bash
cur_dir=$(cd `dirname $0`;pwd)
base_home=$(cd ${cur_dir}/..;pwd)
#函数依赖脚本
func_file=${base_home}/bin/function.sh
#配置文件目录
config_dir=${base_home}/conf/config

test ! -f ${func_file} && echo -e "\033[31m函数模块依赖缺失，请检查文件[${func_file}]是否存在!\033[0m" && exit 1
#加载通用函数依赖模块
. ${func_file}

#全局配置文件
config_file=${config_dir}/adapter.properties

#校验配置文件参数合法性
validate_file ${config_file}
test $? -ne 0 && exit 1

#参数集合
declare -A paramMap
#加载配置文件参数
load_params ${config_file} paramMap

#提取paramMap中的(key,value), 生成新配置文件
new_config_file=${config_dir}/adapter.ini
test -f ${new_config_file} && rm ${new_config_file}
for key in ${!paramMap[@]}
do
	echo "$key=${paramMap[$key]}" >> ${new_config_file}
done

#sink节点
declare -A sinkFlowNodes
for node in `echo ${paramMap[sink_flow_nodes]} | tr ',' ' '`
do
	sinkFlowNodes["$node"]=$node
done	

#图类型(vertex,edge)
#生成vertex,edge配置文件
for graph_type in `echo ${paramMap[graph_type]} | tr ',' ' '` 
do
    #模板文件目录
    template_dir=${base_home}/conf/template/${graph_type}
    test ! -d "${template_dir}" && printFailed "模板文件目录[$template_dir]不存在!" && exit 1
    #根据模板生成测试案例文件
    find ${template_dir} -type f | while read line
    do
        file_name=`basename $line`
		#sink标识
		sink_flag=`echo ${file_name} | awk -F'.' '{print $1}' | sed 's#.*hive2##g'`
		[[ -z "${sinkFlowNodes[${sink_flag}]}" && ${file_name} != "hive2All.json" ]] && continue
        instance_dir=${base_home}/conf/instance/${graph_type}
        [[ ! -d ${instance_dir} ]] && mkdir -p ${instance_dir}
        dest_file=${instance_dir}/${file_name}
        #生成目标文件
        test -f ${dest_file} && rm ${dest_file}
        cp $line ${dest_file}
		#批量替换模板文件中的变量
        for key in ${!paramMap[*]}
        do
            converted_key=`echo "$key" | tr '_' '.'`
            value=${paramMap[$key]}
            sed -i 's#\${'${converted_key}'}#'$value'#g' ${dest_file}
        done

        if [[ ${dest_file} =~ .*\.json && ${file_name} != "hive2All.json" ]]; then
            #校验JSON文件格式是否合法
            python -m json.tool < ${dest_file} 1>/dev/null
            test $? -ne 0 && printFailed "配置文件[$dest_file]格式错误!" && exit 1
        fi

		#汇总sink
		if [[ ${file_name} == "hive2All.json" ]]; then
			#转换: hive,arango,es -> ${HIVE},${ARANGO},${ES}
			sinks_content=`echo ${paramMap[sink_flow_nodes]} | tr a-z A-Z | tr ',' '\n' | awk '{print "${"$1"}"}' | xargs | tr ' ' ','`
			sed -i "s#SINKS_CONTENT#${sinks_content}#g" ${dest_file}
			#遍历sink节点,依次替换sink内容
			for node in ${!sinkFlowNodes[@]}
			do
				instance_file=${instance_dir}/hive2$node.json
				#提取sinks中的内容
				content=$(echo `cat ${instance_file} | python -m json.tool | sed -n '/"sinks": \[/,/"source": {/p' | sed '1d;$d' | sed '$d'`)
				#生成sink变量
				node_upper="\${"`echo $node | tr a-z A-Z`"}"
				#替换sink内容
				sed -i "s#${node_upper}#$content#g" ${dest_file}
			done
			tmp_file=`mktemp -t test_XXXXXX`
			python -m json.tool < ${dest_file} > ${tmp_file}
			test $? -eq 0 && mv ${tmp_file} ${dest_file}
			test -f ${tmp_file} && rm ${tmp_file}
		fi
    done
done

#其它模板文件目录
template_dir=${base_home}/conf/template/others
test ! -d ${template_dir} && exit
instance_dir=${base_home}/conf/instance/others
[[ ! -d ${instance_dir} ]] && mkdir -p ${instance_dir}
find ${template_dir} -type f | while read line
do
	file_name=`basename $line`
	dest_file=${instance_dir}/${file_name}
	test -f ${dest_file} && rm ${dest_file}
	cp $line ${dest_file}
	#批量替换模板文件中的变量
	for key in ${!paramMap[*]}
	do
		converted_key=`echo "$key" | tr '_' '.'`
		value=${paramMap[$key]}
		sed -i 's#\${'${converted_key}'}#'$value'#g' ${dest_file}
	done
done
