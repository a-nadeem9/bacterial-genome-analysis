# This file contains all rules related to assembly polishing and QC

# Helper function to get the correct assembly for Pilon polishing
def get_pilon_input_assembly(wildcards):
    if wildcards.sample in SAMPLES_WITH_LONG_READS:
        # Use the Unicycler assembly directly
        return "results/assembly/{sample}/assembly.fasta".format(sample=wildcards.sample)
    else:
        return "results/assembly/{sample}/scaffolds.fasta".format(sample=wildcards.sample)


rule bwa_map_sort_index:
    input:
        assembly = get_pilon_input_assembly,
        r1 = "results/trimmed/{sample}_1.trimmed.fastq.gz",
        r2 = "results/trimmed/{sample}_2.trimmed.fastq.gz"
    output:
        bam = "results/polishing/{sample}/mapped_reads.bam",
        bai = "results/polishing/{sample}/mapped_reads.bam.bai"
    log:
        "logs/polishing/bwa/{sample}.log"
    threads:
        config["polishing_qc"]["pilon"]["threads"]
    conda:
        "../envs/polishing_qc.yaml"
    shell:
        "(bwa-mem2 index {input.assembly} && "
        "bwa-mem2 mem -t {threads} {input.assembly} {input.r1} {input.r2} | "
        "samtools view -bS - | "
        "samtools sort -o {output.bam}) > {log} 2>&1 && "
        "samtools index {output.bam}"


rule pilon_polish:
    input:
        assembly = get_pilon_input_assembly,
        bam = "results/polishing/{sample}/mapped_reads.bam",
        bai = "results/polishing/{sample}/mapped_reads.bam.bai"
    output:
        fasta = "results/polishing/{sample}/03_pilon.fasta"
    params:
        outdir = lambda wildcards: os.path.dirname(f"results/polishing/{wildcards.sample}/pilon_out/temp.fasta"),
        prefix = lambda wildcards: wildcards.sample,
        extra = config["polishing_qc"]["pilon"]["extra"],
        mem = config["polishing_qc"]["pilon"]["memory"]
    log:
        "logs/polishing/pilon/{sample}.log"
    threads:
        config["polishing_qc"]["pilon"]["threads"]
    conda:
        "../envs/polishing_qc.yaml"
    shell:
        "pilon "
        "--genome {input.assembly} "
        "--frags {input.bam} "
        "--outdir {params.outdir} "
        "--output {params.prefix} "
        "--threads {threads} "
        "--changes "
        "--verbose "
        "{params.extra} "
        "-Xmx{params.mem}g > {log} 2>&1 && "
        "mv {params.outdir}/{params.prefix}.fasta {output}"


rule quast:
    input:
        fasta = "results/polishing/{sample}/03_pilon.fasta"
    output:
        html = "results/qc/quast/{sample}/report.html",
        tsv = "results/qc/quast/{sample}/report.tsv"
    params:
        outdir = lambda wildcards, output: os.path.dirname(output.html)
    log:
        "logs/qc/quast/{sample}.log"
    threads:
        config["polishing_qc"]["quast"]["threads"]
    conda:
        "../envs/polishing_qc.yaml"
    shell:
        "quast.py "
        "--output-dir {params.outdir} "
        "--threads {threads} "
        "{input.fasta} > {log} 2>&1"


rule busco_download_lineage:
    output:
        sentinel = touch("results/qc/busco/.downloaded")
    params:
        lineage = config["polishing_qc"]["busco"]["lineage"],
        db_path = config["database_paths"]["busco_downloads"]
    log:
        "logs/qc/busco/download_lineage.log"
    conda:
        "../envs/polishing_qc.yaml"
    shell:
        "mkdir -p {params.db_path} && "
        "busco "
        "--download_path {params.db_path} "
        "--download {params.lineage} "
        "> {log} 2>&1"


rule busco:
    input:
        fasta = "results/polishing/{sample}/03_pilon.fasta",
        db_sentinel = "results/qc/busco/.downloaded"
    output:
        summary = "results/qc/busco/{sample}/short_summary.specific.{lineage}.{sample}.txt"
    params:
        lineage = config["polishing_qc"]["busco"]["lineage"],
        outpath = "results/qc/busco/",
        db_path = config["database_paths"]["busco_downloads"]
    log:
        "logs/qc/busco/{sample}.{lineage}.log"
    threads:
        config["polishing_qc"]["busco"]["threads"]
    conda:
        "../envs/polishing_qc.yaml"
    shell:
        "busco "
        "-i {input.fasta} "
        "--out_path {params.outpath} "
        "--out {wildcards.sample} "
        "-m genome "
        "-l {params.lineage} "
        "-c {threads} "
        "--download_path {params.db_path} "
        "--offline "
        "--force > {log} 2>&1"
