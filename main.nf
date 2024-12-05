params.output = "./output/"
params.meta_file = "./examples/metadata_proteomics_adjusted.json"
params.condition = "diabetes-grade"
params.count_files = "./examples/transcriptomics/Rat_25_day_0/gene_expression_0.csv,./examples/transcriptomics/Rat_24_day_0/gene_expression_0.csv,./examples/transcriptomics/Rat_23_day_0/gene_expression_0.csv,./examples/transcriptomics/Rat_22_day_0/gene_expression_0.csv,./examples/transcriptomics/Rat_21_day_0/gene_expression_0.csv,./examples/transcriptomics/Rat_20_day_0/gene_expression_0.csv,./examples/transcriptomics/Rat_19_day_0/gene_expression_0.csv,./examples/transcriptomics/Rat_18_day_0/gene_expression_0.csv,./examples/transcriptomics/Rat_17_day_0/gene_expression_0.csv,./examples/transcriptomics/Rat_16_day_0/gene_expression_0.csv,./examples/transcriptomics/Rat_15_day_0/gene_expression_0.csv,./examples/transcriptomics/Rat_14_day_0/gene_expression_0.csv,./examples/transcriptomics/Rat_13_day_0/gene_expression_0.csv,./examples/transcriptomics/Rat_12_day_0/gene_expression_0.csv,./examples/transcriptomics/Rat_11_day_0/gene_expression_0.csv,./examples/transcriptomics/Rat_10_day_0/gene_expression_0.csv,./examples/transcriptomics/Rat_9_day_0/gene_expression_0.csv,./examples/transcriptomics/Rat_8_day_0/gene_expression_0.csv,./examples/transcriptomics/Rat_7_day_0/gene_expression_0.csv,./examples/transcriptomics/Rat_6_day_0/gene_expression_0.csv,./examples/transcriptomics/Rat_5_day_0/gene_expression_0.csv,./examples/transcriptomics/Rat_4_day_0/gene_expression_0.csv,./examples/transcriptomics/Rat_3_day_0/gene_expression_0.csv,./examples/transcriptomics/Rat_2_day_0/gene_expression_0.csv,./examples/transcriptomics/Rat_1_day_0/gene_expression_0.csv"
// params.count_files = "./examples/proteomics/Rat_25_day_0/protein_abundance_0.csv,./examples/proteomics/Rat_24_day_0/protein_abundance_0.csv,./examples/proteomics/Rat_23_day_0/protein_abundance_0.csv,./examples/proteomics/Rat_22_day_0/protein_abundance_0.csv,./examples/proteomics/Rat_21_day_0/protein_abundance_0.csv,./examples/proteomics/Rat_20_day_0/protein_abundance_0.csv,./examples/proteomics/Rat_19_day_0/protein_abundance_0.csv,./examples/proteomics/Rat_18_day_0/protein_abundance_0.csv,./examples/proteomics/Rat_17_day_0/protein_abundance_0.csv,./examples/proteomics/Rat_16_day_0/protein_abundance_0.csv,./examples/proteomics/Rat_15_day_0/protein_abundance_0.csv,./examples/proteomics/Rat_14_day_0/protein_abundance_0.csv,./examples/proteomics/Rat_13_day_0/protein_abundance_0.csv,./examples/proteomics/Rat_12_day_0/protein_abundance_0.csv,./examples/proteomics/Rat_11_day_0/protein_abundance_0.csv,./examples/proteomics/Rat_10_day_0/protein_abundance_0.csv,./examples/proteomics/Rat_9_day_0/protein_abundance_0.csv,./examples/proteomics/Rat_8_day_0/protein_abundance_0.csv,./examples/proteomics/Rat_7_day_0/protein_abundance_0.csv,./examples/proteomics/Rat_6_day_0/protein_abundance_0.csv,./examples/proteomics/Rat_5_day_0/protein_abundance_0.csv,./examples/proteomics/Rat_4_day_0/protein_abundance_0.csv,./examples/proteomics/Rat_3_day_0/protein_abundance_0.csv,./examples/proteomics/Rat_2_day_0/protein_abundance_0.csv,./examples/proteomics/Rat_1_day_0/protein_abundance_0.csv"

metadata = Channel.fromPath(params.meta_file)

// split list of files
file_list = params.count_files.tokenize(",")
file_channels = Channel.fromPath(file_list).collect()

// config files
data_config = Channel.fromPath("${projectDir}/config/data_table_config.json")
meta_data_config = Channel.fromPath("${projectDir}/config/meta_table_config.json")

// script files
join_table = Channel.fromPath("${projectDir}/semares_preprocessing/join_table.py")
metadata2table = Channel.fromPath("${projectDir}/semares_preprocessing/metadata2table.py")
wilcoxon_script = Channel.fromPath("${projectDir}/src/wilcoxon.py")

process file_join {
    container "dockergenevention/pandas"
    publishDir params.output, mode: "copy"

    input:
    path script
    path metadata
    path config
    path file_channels, stageAs: "*/*" // create for each file a subfolder
    val file_path

    output:
    path "transformed_input/data.csv"

    """
    python $script -m $metadata -c $config -f $file_channels -p $file_path
    """
}

process metadata_join {
    container "dockergenevention/pandas"
    publishDir params.output, mode: "copy"

    input:
    path script
    path metadata
    path config
    val file_path

    output:
    path "transformed_input/metadata.csv"

    """
    python $script -m $metadata -c $config -p $file_path
    """
}

process wilcoxon {
    container "dockergenevention/analyses"
    publishDir params.output, mode: "copy"

    input:
    path script
    path metadata
    path count_data
    val condition

    output:
    path "wilcoxon_result/result.csv"
    path "wilcoxon_result/pca.csv"
    path "wilcoxon_result/pca.png"

    """
    python $script -m $metadata -d $count_data -c $condition
    """
}


workflow {
  file_join(join_table, metadata, data_config, file_channels, params.count_files)
  metadata_join(metadata2table, metadata, meta_data_config, params.count_files)
  wilcoxon(wilcoxon_script, metadata_join.out, file_join.out, params.condition)
}
