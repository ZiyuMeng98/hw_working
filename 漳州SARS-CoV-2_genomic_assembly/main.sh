ls 00.raw_data/ > samples.txt
mkdir logs/
bash ~/script/amplicon_genome_qc/artic_guppyplex.sh 2>&1 | tee logs/artic_guppyplex.log
bash ~/script/amplicon_genome_qc/minimap2_samtools.sh 2>&1 | tee logs/minimap2_samtools.log
for i in $(cat samples.txt); do SAMPLE="$i" bash ivar_trim.sh 2>&1 | tee "logs/ivar_trim_${i}.log"; done
bash ~/script/amplicon_genome_qc/depth_qc.sh 2>&1 | tee logs/depth_qc.log
bash ~/script/amplicon_genome_qc/primer_site_qc.sh 2>&1 | tee logs/primer_site_qc.log
bash ~/script/amplicon_genome_qc/consensus.sh 2>&1 | tee logs/consensus.log
bash ~/script/amplicon_genome_qc/final_qc.sh 2>&1 | tee logs/final_qc.log
bash ~/script/amplicon_genome_qc/low_amplicon_mutation_qc.sh 2>&1 | tee logs/low_amplicon_mutation_qc.log
bash ~/script/amplicon_genome_qc/mutation_read_support.sh 2>&1 | tee logs/mutation_read_support.log


# 输出出现频率最多的前十种reads，并使用kraken2判断reads属于什么物种
bash ~/script/amplicon_genome_qc/wrong_reads_top10.sh
bash ~/script/amplicon_genome_qc/wrong_reads_top10_kraken2.sh
