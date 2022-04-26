println(" load start ")

val database: String = "${source.hive.database}"
val vertexTableName: String = "${source.vertex.hive.table}"
val edgeTableName: String = "${source.edge.hive.table}"
val vertexPath: String = "${source.data.vertex.path}"
val edgePath: String = "${source.data.edge.path}"

import java.io.File
val file = new File(s"${new File(vertexPath).getParent}/.loadSuccess")
if (file.exists()) {file.delete(); println("预删除.loadSuccess文件")}

sql(" SHOW DATABASES ").show
println(" hive connection success ")

sql(s" CREATE DATABASE IF NOT EXISTS $database ")
println(" hive create database success ")

sql(" USE TEST_ETL ")
sql(s" DROP TABLE IF EXISTS $database.$vertexTableName ")
sql(s" DROP TABLE IF EXISTS $database.$edgeTableName ")
println(" hive delete old table success ")

sql(
  s"""CREATE  TABLE $database.$vertexTableName(
     |        `object_key` string,
     |        `clt_ctf_nbr` string,
     |        `clt_nbr` string,
     |        `amount` double,
     |        `amount_usage_rate` double,
     |        `cir_act_cnt` bigint,
     |        `clt_blk_cod` string,
     |        `clt_bth_dte` string,
     |        `clt_cir_flg` string,
     |        `clt_cop_nam` string,
     |        `clt_edu` string,
     |        `clt_eml_adr1` string COMMENT 'E-MAIL1',
     |        `clt_eml_adr2` string COMMENT 'E-MAIL2',
     |        `clt_mob_tel1` string COMMENT '1',
     |        `clt_mob_tel2` string COMMENT '2',
     |        `clt_nam_tel1` string COMMENT '1',
     |        `clt_nam_tel2` string COMMENT '2',
     |        `clt_ser_cod1` bigint,
     |        `clt_sex` string,
     |        `clt_sht_nam` string,
     |        `clt_str_dte` string,
     |        `cmb_flg` string,
     |        `communities` array<map<string,string>>,
     |        `community_clustering_coefficient_community_level_1` double,
     |        `community_id` string COMMENT 'id',
     |        `cust_uid` string,
     |        `degree1_amount_degree1_avg` double,
     |        `degree1_clt_sex_degree1_ratio_1` double,
     |        `degree1_is_overdue_degree1_ratio_1` double,
     |        `degree1_is_stop_card_degree1_ratio_1` double,
     |        `degree2_batch_amount_degree2_avg` double,
     |        `degree2_batch_clt_sex_degree2_ratio_1` double,
     |        `degree2_batch_is_overdue_degree2_ratio_1` double,
     |        `degree2_batch_is_stop_card_degree2_ratio_1` double,
     |        `degree3_batch_amount_degree3_avg` double,
     |        `degree3_batch_clt_sex_degree3_ratio_1` double,
     |        `degree3_batch_is_overdue_degree3_ratio_1` double,
     |        `degree3_batch_is_stop_card_degree3_ratio_1` double,
     |        `fw_score_d1_avg_1_clt_age` double,
     |        `fw_score_d1_count_1_id` double,
     |        `fw_score_d2_avg_2_clt_age` double,
     |        `fw_score_d2_count_2_id` double,
     |        `fw_score_d3_avg_3_amount` double,
     |        `fw_score_d3_avg_3_clt_age` double,
     |        `fw_score_d3_count_3_id` double,
     |        `fw_score_d3_ratio_3_clt_sex_1` double,
     |        `fw_score_d3_ratio_3_is_overdue_1` double,
     |        `fw_score_d3_ratio_3_is_stop_card_1` double,
     |        `fw_score_level1_community_id_avg_amount` double,
     |        `fw_score_level1_community_id_avg_clt_age` double,
     |        `fw_score_level1_community_id_count` double,
     |        `fw_score_level1_community_id_ratio_clt_sex_1` double,
     |        `fw_score_level1_community_id_ratio_is_overdue_1` double,
     |        `fw_score_level1_community_id_ratio_is_stop_card_1` double,
     |        `in_degree` bigint,
     |        `is_overdue` string,
     |        `is_stop_card` string,
     |        `max_delay` bigint,
     |        `max_lst_blk_cod_dte` string,
     |        `opn_id` string,
     |        `out_degree` bigint,
     |        `page_rank` double COMMENT 'page_rank',
     |        `sen_cod` string,
     |        `tx_flag` string,
     |        `update_date` string,
     |        `usr_id` string COMMENT 'id')
     |COMMENT 'null'
     |ROW FORMAT SERDE
     |  'org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe'
     |WITH SERDEPROPERTIES (
     |  'field.delim'='\t',
     |  'serialization.format'='\t')
     |STORED AS INPUTFORMAT
     |  'org.apache.hadoop.mapred.TextInputFormat'
     |OUTPUTFORMAT
     |  'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'""".stripMargin)
println(" hive create vertex table success ")

sql(
  s"""CREATE  TABLE $database.$edgeTableName(
     |  `object_key` string ,
     |  `from_key` string ,
     |  `to_key` string ,
     |  `bnd_crd` string ,
     |  `label` string ,
     |  `mgm_chn` string ,
     |  `reg_sts` string ,
     |  `reg_tim` string ,
     |  `update_date` string )
     |ROW FORMAT SERDE
     |  'org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe'
     |STORED AS INPUTFORMAT
     |  'org.apache.hadoop.mapred.TextInputFormat'
     |OUTPUTFORMAT
     |  'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'""".stripMargin)
println(" hive create edge table success ")

println(s" vertex path : $vertexPath")
sql(s"load data local inpath '$vertexPath' into table $database.$vertexTableName")
println(" hive load vertex data success ")

println(s" edge path : $edgePath")
sql(s"load data local inpath '$edgePath' into table $database.$edgeTableName")
println(" hive load vertex data success ")

sql(s"select * from $database.$vertexTableName limit 2").show
println(s" show vertex $database.$vertexTableName println limit 2 ")

sql(s"select * from $database.$edgeTableName limit 2").show
println(s" show edge $database.$edgeTableName println limit 2 ")

val vertexFlag = sql("select * from test_etl.t_vertex limit 2").take(2).isEmpty
val edgeFlag = sql("select * from test_etl.t_edge limit 2").take(2).isEmpty
if(!vertexFlag && !edgeFlag) {file.createNewFile(); println("导数成功，已创建.loadSuccess")}

println(" load end ")
