# Rule to download a specific, versioned Bakta database
rule bakta_download_db:
    output:
        # Use a sentinel file to robustly mark completion after the shell command finishes
        sentinel=touch("databases/bakta_db/.success")
    params:
        db_path=config["database_paths"]["bakta_db"],
        db_type=config["annotation"]["bakta"]["database_type"]
    log:
        "logs/bakta_download.log"
    conda:
        "../envs/annotation.yaml"
    shell:
        # Use the correct bakta_db executable without the --version flag
        "bakta_db download "
        "--output {params.db_path} "
        "--type {params.db_type} "
        "> {log} 2>&1"
# Rule to perform annotation on each sample
rule bakta_annotation:
    input:
        fasta = "results/polishing/{sample}/03_pilon.fasta",
        # This now depends on the sentinel file, ensuring the DB is truly ready
        db_sentinel = "databases/bakta_db/.success"
    output:
        gff3 = "results/annotation/{sample}/{sample}.gff3"
    params:
        outdir = lambda wildcards: f"results/annotation/{wildcards.sample}",
        prefix = lambda wildcards: wildcards.sample,
        db_path = f'{config["database_paths"]["bakta_db"]}/db-light'
    log:
        "logs/annotation/{sample}.log"
    threads:
        config["annotation"]["bakta"]["threads"]
    conda:
        "../envs/annotation.yaml"
    resources:
        bakta = 1
    shell:
        # Use the main bakta executable for annotation
        "bakta "
        "--db {params.db_path} "
        "--output {params.outdir} "
        "--prefix {params.prefix} "
        "--threads {threads} "
        "--force "
        "{input.fasta} > {log} 2>&1"
