ls 00.raw_data/ > samples.txt

WORK_DIR="/home/mzy/working/2026.09/20260909_Cov2_assembly_pingxiang"  # 注意不要在这个后面带/，不然有些命令会报错
REF_FA="/home/mzy/reference/MN908947.3/MN908947.3.fa"  # 注意修改
REF_MMI="/home/mzy/reference/MN908947.3/MN908947.3.mmi"  # 注意修改
$LEFT_FASTA="/home/mzy/primer_fa/SARS_Cov2_amplicon_primer/SARS_Cov2_1200bp_left.fa"  # 注意修改
$RIGHT_FASTA="/home/mzy/primer_fa/SARS_Cov2_amplicon_primer/SARS_Cov2_1200bp_right.fa"  # 注意修改

mkdir $WORK_DIR/logs/
bash ~/script/amplicon_assembly/01.artic_guppyplex.sh 2>&1 | tee $WORK_DIR/logs/01.artic_guppyplex.log
bash ~/script/amplicon_assembly/02.minimap2_samtools.sh 2>&1 | tee $WORK_DIR/logs/02.minimap2_samtools.log
bash ~/script/amplicon_assembly/03.cutadapt.sh 2&>1 | tee $WORK_DIR/logs/03.cutadapt.log
bash ~/script/amplicon_assembly/04.align_and_sort.sh 2&>1 | tee $WORK_DIR/logs/04.align_and_sort.log
bash ~/script/amplicon_assembly/05.depth_calculate.sh 2&>1 | $WORK_DIR/tee logs/05.depth_calculate.log
bash ~/script/amplicon_assembly/06.low_cover_bed.sh 2&>1 | tee $WORK_DIR/logs/06.low_cover_bed.log
bash ~/script/amplicon_assembly/07.freebayes.sh 2&>1 | tee $WORK_DIR/logs/07.freebayes.log
bash ~/script/amplicon_assembly/08.vcf_filter.sh 2&>1 | tee $WORK_DIR/logs/08.vcf_filter.log
bash ~/script/amplicon_assembly/09.consensus.sh 2&>1 | tee $WORK_DIR/logs/09.consensus.log
