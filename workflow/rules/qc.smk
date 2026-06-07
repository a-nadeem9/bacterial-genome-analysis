# This file contains all rules related to Read Quality Control

rule fastp_trim:
    input:
        r1 = lambda wildcards: SAMPLES.loc[wildcards.sample, "illumina_r1"],
        r2 = lambda wildcards: SAMPLES.loc[wildcards.sample, "illumina_r2"]
    output:
        r1 = "results/trimmed/{sample}_1.trimmed.fastq.gz",
        r2 = "results/trimmed/{sample}_2.trimmed.fastq.gz",
        html = "results/fastp/{sample}.html",
        json = "results/fastp/{sample}.json"
    params:
        quality = config["params"]["fastp"]["qualified_quality_phred"],
        length = config["params"]["fastp"]["length_required"],
        n_base = config["params"]["fastp"]["n_base_limit"],
        avg_qual = config["params"]["fastp"]["average_qual"],
        adapter_flag = get_adapter_flag(),
        extra = config["params"]["fastp"]["extra"]
    log:
        "logs/fastp/{sample}.log"
    threads:
        config["params"]["fastp"]["threads"]
    conda:
        "../envs/qc.yaml"
    shell:
        "fastp "
        "--in1 {input.r1} --in2 {input.r2} "
        "--out1 {output.r1} --out2 {output.r2} "
        "--html {output.html} --json {output.json} "
        "--qualified_quality_phred {params.quality} "
        "--length_required {params.length} "
        "--n_base_limit {params.n_base} "
        "--average_qual {params.avg_qual} "
        "{params.adapter_flag} "
        "{params.extra} "
        "--thread {threads} "
        "> {log} 2>&1"

rule nanofilt_trim:
    input:
        long_reads = lambda wildcards: SAMPLES.loc[wildcards.sample, "long_reads"]
    output:
        long_reads = "results/trimmed/{sample}.long.trimmed.fastq.gz"
    params:
        min_length = config["params"]["nanofilt"]["min_length"],
        max_length = config["params"]["nanofilt"]["max_length"],
        min_q = config["params"]["nanofilt"]["min_q"]
    log:
        "logs/nanofilt/{sample}.log"
    conda:
        "../envs/qc.yaml"
    shell:
        "(gunzip -c {input.long_reads} | "
        "NanoFilt -q {params.min_q} -l {params.min_length} --maxlength {params.max_length} | "
        "gzip > {output.long_reads}) "
        "> {log} 2>&1"

rule nanoplot_long_reads:
    input:
        long_reads = "results/trimmed/{sample}.long.trimmed.fastq.gz"
    output:
        html = "results/qc/long_reads/{sample}/NanoPlot-report.html",
        stats = "results/qc/long_reads/{sample}/NanoStats.txt"
    params:
        outdir = "results/qc/long_reads/{sample}"
    log:
        "logs/nanoplot/{sample}.log"
    conda:
        "../envs/qc.yaml"
    shell:
        "NanoPlot "
        "--fastq {input.long_reads} "
        "--outdir {params.outdir} "
        "--prefix {wildcards.sample}_ "
        "--plots dot "
        "> {log} 2>&1 && "
        "mv {params.outdir}/{wildcards.sample}_NanoPlot-report.html {output.html} && "
        "mv {params.outdir}/{wildcards.sample}_NanoStats.txt {output.stats}"

rule multiqc:
    input:
        fastp = expand("results/fastp/{sample}.json", sample=ALL_SAMPLES),
        nanoplot = expand("results/qc/long_reads/{sample}/NanoStats.txt", sample=SAMPLES_WITH_LONG_READS),
        quast = expand("results/qc/quast/{sample}/report.tsv", sample=ALL_SAMPLES),
        busco = expand("results/qc/busco/{sample}/short_summary.specific.{lineage}.{sample}.txt",
                       sample=ALL_SAMPLES,
                       lineage=config["polishing_qc"]["busco"]["lineage"])
    output:
        "results/multiqc/multiqc_report.html"
    log:
        "logs/multiqc.log"
    conda:
        "../envs/qc.yaml"
    shell:
        "multiqc "
        "results/fastp "
        "results/qc/long_reads "
        "results/qc/quast "
        "results/qc/busco "
        "-o results/multiqc -f > {log} 2>&1"
